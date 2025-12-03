// src/simulations/carwash.rs
use serde::{Deserialize, Serialize};
use rand::prelude::*;
use rand_distr::{Exp, Normal, Poisson, Uniform, Distribution};
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::ffi::{c_char, CStr};

// --- MODELOS DE ENTRADA (Lo que viene de Dart) ---

#[derive(Deserialize)]
struct StageConfig {
    name: String,
    dist_type: String, // "normal", "exponential", "uniform"
    p1: f64, // Mean, Beta (convertir a lambda), min
    p2: f64, // Variance (convertir a std), max
}

#[derive(Deserialize)]
struct SimConfig {
    hours: i32,
    lambda_arrival: f64,
    stages: Vec<StageConfig>,
}

// --- MODELOS DE SALIDA (Lo que va a Dart) ---
#[derive(Serialize)]
struct CarResult {
    car_id: i32,
    arrival_time_abs: f64, // Minutos desde el inicio del día (ej. 8:58 = 58.0)
    start_time: f64,       // Cuando realmente empezó a lavarse
    end_time: f64,         // Cuando salió de todo el sistema
    total_duration: f64,   // end - start
    wait_time: f64,        // start - arrival (tiempo en cola antes de entrar)
}

#[derive(Serialize)]
struct HourMetrics {
    hour_index: i32,
    estimated_arrivals: u64, // Poisson
    served_count: i32,       // Terminaron su proceso TOTAL dentro de esta hora
    pending_count: i32,      // Llegaron pero siguen lavandose al acabar la hora
    cars: Vec<CarResult>,    // Detalle de carros que LLEGARON en esta hora
}

#[derive(Serialize)]
struct SimulationResponse {
    hours: Vec<HourMetrics>,
    total_cars: i32,
    avg_wait_time: f64,
}

// Función auxiliar para parsear string C a struct
unsafe fn parse_config(json_ptr: *const c_char) -> Result<SimConfig, Error> {
    if json_ptr.is_null() { return Err(Error::NullOrEmptyInput); }
    let c_str = CStr::from_ptr(json_ptr);
    let s = c_str.to_str().map_err(|_| Error::Other("Invalid UTF-8".into()))?;
    serde_json::from_str(s).map_err(|e| Error::SerdeError(e.to_string()))
}

pub fn run_simulation_dynamic(json_config: *const c_char) -> Result<*mut c_char, Error> {
    let config = unsafe { parse_config(json_config)? };
    
    if config.hours <= 0 { return Err(Error::NullOrEmptyInput); }

    let mut rng = thread_rng();

    // 1. Configurar Distribuciones para cada etapa
    // Guardamos cierres o enums, pero para simplicidad usaremos un match dentro del loop
    // Validamos parámetros antes de empezar
    for s in &config.stages {
        if s.dist_type == "normal" && s.p2 < 0.0 { return Err(Error::Other(format!("Varianza negativa en {}", s.name))); }
        if s.dist_type == "exponential" && s.p1 <= 0.0 { return Err(Error::Other(format!("Beta negativo/cero en {}", s.name))); }
    }
    
    let poisson_arrival = Poisson::new(config.lambda_arrival).map_err(|e| Error::Other(e.to_string()))?;

    // ESTADO DEL SISTEMA (PIPELINE)
    // free_times[i] indica en qué minuto absoluto se desocupa la máquina i
    let mut stage_free_times = vec![0.0f64; config.stages.len()];
    
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;
    
    // Para estadísticas globales
    let mut total_wait_time = 0.0;
    let mut total_finished_cars = 0;

    // Reloj global simulado (en minutos)
    // Hora 1: 0-60, Hora 2: 60-120...
    
    for h in 0..config.hours {
        let hour_start = (h as f64) * 60.0;
        let hour_end = hour_start + 60.0;

        // A. Determinar cuántos llegan (Poisson)
        let num_arrivals: u64 = poisson_arrival.sample(&mut rng) as u64;
        
        // B. Determinar MOMENTOS de llegada dentro de la hora
        // Asumimos distribución uniforme de llegadas dentro de los 60 mins
        let mut arrival_offsets: Vec<f64> = (0..num_arrivals)
            .map(|_| rng.gen_range(0.0..60.0))
            .collect();
        arrival_offsets.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let mut cars_in_this_arrival_batch = Vec::new();
        let mut served_in_this_hour = 0;

        for offset in arrival_offsets {
            global_car_counter += 1;
            let arrival_abs = hour_start + offset;
            
            // C. Simulación de PASO POR EL PIPELINE
            let mut current_time_in_sys = arrival_abs;
            let mut first_stage_start = 0.0;

            for (idx, stage) in config.stages.iter().enumerate() {
                // 1. Generar duración de esta etapa
                let duration = match stage.dist_type.as_str() {
                    "normal" => {
                        // OJO: p2 es VARIANZA, Normal::new pide STD_DEV
                        let std_dev = stage.p2.sqrt(); 
                        let d = Normal::new(stage.p1, std_dev).unwrap();
                        d.sample(&mut rng).max(0.0) // Evitar tiempos negativos
                    },
                    "exponential" => {
                        // OJO: p1 es BETA, Rust pide LAMBDA (1/Beta)
                        let lambda = 1.0 / stage.p1;
                        let d = Exp::new(lambda).unwrap();
                        d.sample(&mut rng)
                    },
                    "uniform" => {
                        let d = Uniform::new_inclusive(stage.p1, stage.p2);
                        d.sample(&mut rng)
                    },
                    _ => 0.0
                };

                // 2. Lógica de Bloqueo / Disponibilidad
                // El carro puede entrar cuando él llega (current_time_in_sys) Y la máquina está libre
                let start_stage = current_time_in_sys.max(stage_free_times[idx]);
                let end_stage = start_stage + duration;

                // Guardamos cuando empezó realmente la primera etapa
                if idx == 0 { first_stage_start = start_stage; }

                // Actualizamos estado del sistema
                stage_free_times[idx] = end_stage; // Máquina ocupada hasta end_stage
                current_time_in_sys = end_stage;   // El carro termina esta etapa aquí
            }

            let finish_abs = current_time_in_sys;
            let wait_time = first_stage_start - arrival_abs;
            let total_process_time = finish_abs - first_stage_start; // Tiempo real siendo lavado

            total_wait_time += wait_time;
            total_finished_cars += 1; // Contamos como procesado (eventualmente)

            // D. Clasificación por Hora
            // ¿Terminó DENTRO de esta hora o se pasó a la siguiente?
            if finish_abs <= hour_end {
                served_in_this_hour += 1;
            }

            cars_in_this_arrival_batch.push(CarResult {
                car_id: global_car_counter,
                arrival_time_abs: arrival_abs,
                start_time: first_stage_start,
                end_time: finish_abs,
                total_duration: total_process_time,
                wait_time,
            });
        }

        // Calculamos pendientes: Los que llegaron (num_arrivals) - los que salieron AHORA
        // Nota: Esto es aproximado, porque un carro de la hora anterior podría haber salido en esta.
        // Pero para la métrica solicitada "clientes satisfechos e insatisfechos DE ESTA HORA":
        let pending = (num_arrivals as i32) - served_in_this_hour;

        sim_hours.push(HourMetrics {
            hour_index: h + 1,
            estimated_arrivals: num_arrivals,
            served_count: served_in_this_hour,
            pending_count: if pending < 0 { 0 } else { pending },
            cars: cars_in_this_arrival_batch,
        });
    }

    let avg_wait = if total_finished_cars > 0 { total_wait_time / total_finished_cars as f64 } else { 0.0 };

    let response = SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_wait_time: avg_wait,
    };

    Ok(to_cstring(&response))
}