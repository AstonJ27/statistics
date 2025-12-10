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
    start_time: f64,
    end_time: f64,
    total_duration: f64,
    wait_time: f64,
    stage_durations: Vec<f64>,
    stage_start_times: Vec<f64>,
    stage_end_times: Vec<f64>,
    left: bool,
    pending: bool,
    satisfied: bool,
    hour_arrived: i32,
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

// --- OPTIMIZACIÓN: Distribuciones Pre-calculadas ---
// Esto evita el costo de 'match string' y 'new distribution' en cada iteración
enum PreparedDist {
    Normal(Normal<f64>),
    Exponential(Exp<f64>),
    Uniform(Uniform<f64>),
    None,
}

impl PreparedDist {
    #[inline(always)]
    fn sample<R: Rng + ?Sized>(&self, rng: &mut R) -> f64 {
        match self {
            PreparedDist::Normal(d) => d.sample(rng).max(0.0), // Evitar tiempos negativos
            PreparedDist::Exponential(d) => d.sample(rng),
            PreparedDist::Uniform(d) => d.sample(rng),
            PreparedDist::None => 0.0,
        }
    }
}

pub fn run_simulation_dynamic(json_config: *const c_char) -> Result<*mut c_char, Error> {
    if json_config.is_null() { return Err(Error::NullOrEmptyInput); }
    
    // 1. Parsear Config
    let config: SimConfig = unsafe {
        let c_str = CStr::from_ptr(json_config);
        let s = c_str.to_str().map_err(|_| Error::Other("Invalid UTF-8".into()))?;
        serde_json::from_str(s)?
    };
    
    if config.hours <= 0 { 
        return Err(Error::NullOrEmptyInput); 
    }

    // 2. PREPARACIÓN DE DISTRIBUCIONES (Fuera del bucle)
    // Esto valida parámetros y crea los objetos una sola vez.
    let mut prepared_stages = Vec::with_capacity(config.stages.len());
    for s in &config.stages {
        let dist = match s.dist_type.as_str() {
            "normal" => {
                if s.p2 < 0.0 { return Err(Error::Other(format!("Varianza negativa en {}", s.name))); }
                let std = s.p2.sqrt();
                PreparedDist::Normal(Normal::new(s.p1, std).unwrap())
            },
            "exponential" => {
                if s.p1 <= 0.0 { return Err(Error::Other(format!("Beta <= 0 en {}", s.name))); }
                let lambda = 1.0 / s.p1;
                PreparedDist::Exponential(Exp::new(lambda).unwrap())
            },
            "uniform" => {
                if s.p1 >= s.p2 { return Err(Error::Other(format!("Min >= Max en {}", s.name))); }
                PreparedDist::Uniform(Uniform::new_inclusive(s.p1, s.p2))
            },
            _ => PreparedDist::None,
        };
        prepared_stages.push(dist);
    }

    // 3. Ejecución de Simulación
    let mut rng = thread_rng();
    let mut stage_free_times = vec![0.0f64; config.stages.len()];
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;
    let mut total_wait_time = 0.0;
    let mut total_cars_processed = 0;
    
    let min_interarrival = 5.0;
    let max_interarrival = 15.0;
    
    for hour_idx in 0..config.hours {
        let hour_start = (hour_idx as f64) * 60.0;
        let hour_end = hour_start + 60.0;
        
        let poisson = Poisson::new(config.lambda_arrival).unwrap();
        let estimated_arrivals = poisson.sample(&mut rng) as u64;
        
        let mut cars_in_hour = Vec::new();
        let mut served_in_hour = 0;
        let mut left_in_hour = 0;
        
        let mut arrival_time = hour_start;
        let mut arrivals_generated = 0;
        
        while arrival_time < hour_end && arrivals_generated < estimated_arrivals {
            global_car_counter += 1;
            total_cars_processed += 1;
            
            let arrival_minute = arrival_time - hour_start;
            let mut left = false;
            let mut pending = false;
            let mut satisfied = false;
            
            let candidate_start_time = arrival_time.max(stage_free_times[0]);
            
            // Abandono si no puede empezar antes de fin de hora
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
                    stage_durations: vec![],
                    stage_start_times: vec![],
                    stage_end_times: vec![],
                    left, pending, satisfied,
                    hour_arrived: hour_idx + 1,
                });
                
                // Next arrival
                arrival_time += rng.gen_range(min_interarrival..=max_interarrival);
                arrivals_generated += 1;
                continue;
            }
            
            // Proceso de Estaciones
            let mut current_time = candidate_start_time;
            let mut total_wait = candidate_start_time - arrival_time;
            let mut stage_durations = Vec::with_capacity(prepared_stages.len());
            let mut stage_start_times = Vec::with_capacity(prepared_stages.len());
            let mut stage_end_times = Vec::with_capacity(prepared_stages.len());
            
            let mut finishes_in_same_hour = true;
            
            for (stage_idx, dist) in prepared_stages.iter().enumerate() {
                let stage_start = current_time.max(stage_free_times[stage_idx]);
                
                if stage_start > current_time {
                    total_wait += stage_start - current_time;
                }
                
                // Muestreo optimizado
                let duration = dist.sample(&mut rng);
                
                let stage_end = stage_start + duration;
                
                if stage_end > hour_end {
                    finishes_in_same_hour = false;
                }
                
                stage_durations.push(duration);
                stage_start_times.push(stage_start);
                stage_end_times.push(stage_end);
                
                stage_free_times[stage_idx] = stage_end;
                current_time = stage_end;
            }
            
            let end_time = current_time;
            let total_duration = end_time - arrival_time;
            
            if finishes_in_same_hour {
                satisfied = true;
                served_in_hour += 1;
            } else {
                pending = true;
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
                left, pending, satisfied,
                hour_arrived: hour_idx + 1,
            });
            
            arrival_time += rng.gen_range(min_interarrival..=max_interarrival);
            arrivals_generated += 1;
        }
        
        let pending_in_hour = cars_in_hour.iter().filter(|c| c.pending).count() as i32;
        
        sim_hours.push(HourMetrics {
            hour_index: hour_idx + 1,
            estimated_arrivals,
            served_count: served_in_hour,
            pending_count: pending_in_hour,
            left_count: left_in_hour,
            cars: cars_in_hour,
        });
    }
    
    let avg_wait_time = if total_cars_processed > 0 {
        total_wait_time / total_cars_processed as f64
    } else { 0.0 };
    
    let response = SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_wait_time,
    };
    
    Ok(to_cstring(&response))
}