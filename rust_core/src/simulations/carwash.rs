// src/simulations/carwash.rs
use serde::{Deserialize, Serialize};
use rand::prelude::*;
use rand_distr::{Exp, Normal, Uniform, Distribution, Poisson};
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::ffi::{c_char, CStr};

// --- Modelos ---
#[derive(Deserialize)]
struct StageConfig {
    name: String,
    dist_type: String,
    p1: f64,
    p2: f64,
}

#[derive(Deserialize)]
struct SimConfig {
    hours: i32,
    lambda_arrival: f64,
    stages: Vec<StageConfig>,
}

#[derive(Serialize, Clone)]
struct CarResult {
    car_id: i32,
    arrival_time_abs: f64,
    arrival_minute: f64,
    start_time: f64,      // cuando empieza el primer módulo
    end_time: f64,        // cuando termina el último módulo
    total_duration: f64,  // tiempo total en el sistema (end_time - arrival_time)
    wait_time: f64,       // tiempo total de espera (incluyendo entre módulos)
    stage_durations: Vec<f64>,
    stage_start_times: Vec<f64>,
    stage_end_times: Vec<f64>,
    left: bool,           // true si nunca entró a ningún módulo (abandonó)
    pending: bool,        // true si empezó pero no terminó dentro de su hora
    satisfied: bool,      // true si terminó dentro de su hora
    hour_arrived: i32,    // hora en que llegó (1-indexed)
}

#[derive(Serialize)]
struct HourMetrics {
    hour_index: i32,
    estimated_arrivals: u64,
    served_count: i32,
    pending_count: i32,
    left_count: i32,
    cars: Vec<CarResult>,
}

#[derive(Serialize)]
struct SimulationResponse {
    hours: Vec<HourMetrics>,
    total_cars: i32,
    avg_wait_time: f64,
}

unsafe fn parse_config(json_ptr: *const c_char) -> Result<SimConfig, Error> {
    if json_ptr.is_null() { return Err(Error::NullOrEmptyInput); }
    let c_str = CStr::from_ptr(json_ptr);
    let s = c_str.to_str().map_err(|_| Error::Other("Invalid UTF-8".into()))?;
    serde_json::from_str(s).map_err(|e| Error::SerdeError(e.to_string()))
}

pub fn run_simulation_dynamic(json_config: *const c_char) -> Result<*mut c_char, Error> {
    let config = unsafe { parse_config(json_config)? };
    
    if config.hours <= 0 { 
        return Err(Error::NullOrEmptyInput); 
    }

    // Usar generador aleatorio sin semilla fija
    let mut rng = thread_rng();
    
    // Validaciones
    for s in &config.stages {
        if s.dist_type == "normal" && s.p2 < 0.0 { 
            return Err(Error::Other(format!("Varianza negativa en {}", s.name))); 
        }
        if s.dist_type == "exponential" && s.p1 <= 0.0 { 
            return Err(Error::Other(format!("Beta negativo/cero en {}", s.name))); 
        }
        if s.dist_type == "uniform" && s.p1 >= s.p2 {
            return Err(Error::Other(format!("Mínimo mayor o igual que máximo en {}", s.name)));
        }
    }
    
    // Estado del sistema
    let mut stage_free_times = vec![0.0f64; config.stages.len()];
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;
    let mut total_wait_time = 0.0;
    let mut total_cars_processed = 0;
    
    // Parámetros de llegada: tiempo entre llegadas aleatorio (minutos)
    let min_interarrival = 5.0;
    let max_interarrival = 15.0;
    
    for hour_idx in 0..config.hours {
        let hour_start = (hour_idx as f64) * 60.0;
        let hour_end = hour_start + 60.0;
        
        // Generar número de llegadas estimadas (Poisson) para mostrar en UI
        let poisson = Poisson::new(config.lambda_arrival).unwrap();
        let estimated_arrivals = poisson.sample(&mut rng) as u64;
        
        let mut cars_in_hour = Vec::new();
        let mut served_in_hour = 0;
        let mut left_in_hour = 0;
        
        // Generar llegadas reales para esta hora
        let mut arrival_time = hour_start;
        let mut arrivals_generated = 0;
        
        while arrival_time < hour_end && arrivals_generated < estimated_arrivals {
            global_car_counter += 1;
            total_cars_processed += 1;
            
            let arrival_minute = arrival_time - hour_start;
            
            // Clasificación inicial
            let mut left = false;
            let mut pending = false;
            let mut satisfied = false;
            
            // 1. Verificar si puede empezar en el primer módulo
            let candidate_start_time = arrival_time.max(stage_free_times[0]);
            
            // Si no puede empezar antes del final de la hora, se va (insatisfecho)
            if candidate_start_time >= hour_end {
                left = true;
                left_in_hour += 1;
                let wait_time = (hour_end - arrival_time).max(0.0);
                total_wait_time += wait_time;
                
                cars_in_hour.push(CarResult {
                    car_id: global_car_counter,
                    arrival_time_abs: arrival_time,
                    arrival_minute,
                    start_time: arrival_time,
                    end_time: arrival_time,
                    total_duration: 0.0,
                    wait_time,
                    stage_durations: Vec::new(),
                    stage_start_times: Vec::new(),
                    stage_end_times: Vec::new(),
                    left,
                    pending,
                    satisfied,
                    hour_arrived: hour_idx + 1,
                });
                
                // Generar siguiente llegada
                let interarrival = rng.gen_range(min_interarrival..=max_interarrival);
                arrival_time += interarrival;
                arrivals_generated += 1;
                continue;
            }
            
            // 2. El carro puede empezar a procesarse
            let mut current_time = candidate_start_time;
            let mut total_wait = candidate_start_time - arrival_time; // Espera hasta primer módulo
            let mut stage_durations = Vec::new();
            let mut stage_start_times = Vec::new();
            let mut stage_end_times = Vec::new();
            
            let mut finishes_in_same_hour = true;
            
            for (stage_idx, stage) in config.stages.iter().enumerate() {
                // Determinar cuándo puede empezar esta etapa
                // IMPORTANTE: Debe esperar si la máquina está ocupada
                let stage_start = current_time.max(stage_free_times[stage_idx]);
                
                // Si tuvo que esperar por esta máquina, sumar a tiempo de espera
                if stage_start > current_time {
                    total_wait += stage_start - current_time;
                }
                
                // Generar duración de la etapa
                let duration = match stage.dist_type.as_str() {
                    "normal" => {
                        let std_dev = stage.p2.sqrt();
                        let normal = Normal::new(stage.p1, std_dev).unwrap();
                        normal.sample(&mut rng).max(0.0)
                    }
                    "exponential" => {
                        let lambda = 1.0 / stage.p1;
                        let exp = Exp::new(lambda).unwrap();
                        exp.sample(&mut rng)
                    }
                    "uniform" => {
                        let uniform = Uniform::new_inclusive(stage.p1, stage.p2);
                        uniform.sample(&mut rng)
                    }
                    _ => 0.0,
                };
                
                let stage_end = stage_start + duration;
                
                // Verificar si termina después del final de la hora original
                if stage_end > hour_end && finishes_in_same_hour {
                    finishes_in_same_hour = false;
                }
                
                // Guardar tiempos
                stage_durations.push(duration);
                stage_start_times.push(stage_start);
                stage_end_times.push(stage_end);
                
                // Actualizar tiempo de liberación de la máquina
                stage_free_times[stage_idx] = stage_end;
                
                // El carro avanza al final de esta etapa
                current_time = stage_end;
            }
            
            let end_time = current_time;
            let total_duration = end_time - arrival_time;
            
            // Determinar clasificación final
            if finishes_in_same_hour {
                satisfied = true;
                served_in_hour += 1;
            } else {
                pending = true;
                // Los pendientes se cuentan en su hora de llegada
                // PERO siguen ocupando máquinas en horas siguientes
            }
            
            total_wait_time += total_wait;
            
            cars_in_hour.push(CarResult {
                car_id: global_car_counter,
                arrival_time_abs: arrival_time,
                arrival_minute,
                start_time: candidate_start_time,
                end_time,
                total_duration,
                wait_time: total_wait,
                stage_durations,
                stage_start_times,
                stage_end_times,
                left,
                pending,
                satisfied,
                hour_arrived: hour_idx + 1,
            });
            
            // Generar siguiente llegada
            let interarrival = rng.gen_range(min_interarrival..=max_interarrival);
            arrival_time += interarrival;
            arrivals_generated += 1;
        }
        
        // Calcular pendientes: carros que llegaron en esta hora pero no terminaron
        let pending_in_hour = cars_in_hour.iter()
            .filter(|car| !car.left && !car.satisfied)
            .count() as i32;
        
        sim_hours.push(HourMetrics {
            hour_index: hour_idx + 1,
            estimated_arrivals,
            served_count: served_in_hour,
            pending_count: pending_in_hour,
            left_count: left_in_hour,
            cars: cars_in_hour,
        });
    }
    
    // Calcular tiempo de espera promedio sobre TODOS los carros
    let avg_wait_time = if total_cars_processed > 0 {
        total_wait_time / total_cars_processed as f64
    } else {
        0.0
    };
    
    let response = SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_wait_time,
    };
    
    Ok(to_cstring(&response))
}