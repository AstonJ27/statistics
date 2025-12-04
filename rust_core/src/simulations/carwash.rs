// src/simulations/carwash.rs
// --- Añade/asegúrate de tener estas importaciones al inicio del archivo ---
use serde::{Deserialize, Serialize};
use rand::prelude::*;
use rand_distr::{Exp, Normal, Poisson, Uniform, Distribution};
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::ffi::{c_char, CStr};

// --- Modelos (actualizados) ---
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

#[derive(Serialize)]
struct CarResult {
    car_id: i32,
    arrival_time_abs: f64,
    arrival_minute: f64,   // offset dentro de la hora (0..60)
    start_time: f64,
    end_time: f64,
    total_duration: f64,
    wait_time: f64,
    stage_durations: Vec<f64>,
    stage_start_times: Vec<f64>, // momentos absolutos cuando comenzó cada etapa
    stage_end_times: Vec<f64>,   // momentos absolutos cuando terminó cada etapa
    left: bool // true si no llegó / abandonó antes de iniciar
}

#[derive(Serialize)]
struct HourMetrics {
    hour_index: i32,
    estimated_arrivals: u64,
    served_count: i32,   // terminaron dentro de la hora
    pending_count: i32,  // empezaron pero NO terminaron dentro de la hora
    cars: Vec<CarResult>,
}

#[derive(Serialize)]
struct SimulationResponse {
    hours: Vec<HourMetrics>,
    total_cars: i32,
    avg_wait_time: f64,
}

// parse helper (igual que antes)
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

    // Validaciones
    for s in &config.stages {
        if s.dist_type == "normal" && s.p2 < 0.0 { return Err(Error::Other(format!("Varianza negativa en {}", s.name))); }
        if s.dist_type == "exponential" && s.p1 <= 0.0 { return Err(Error::Other(format!("Beta negativo/cero en {}", s.name))); }
    }
    
    let poisson_arrival = Poisson::new(config.lambda_arrival).map_err(|e| Error::Other(e.to_string()))?;

    // IMPORTANT: Ajusta aquí los parámetros de inter-arrival (min, max en minutos)
    // Por defecto los dejo en 5.0 .. 10.0 minutos. Cámbialos según tu requerimiento.
    // Ejemplo comentado: // IMPORTANT: cambiar MIN_INTERARRIVAL / MAX_INTERARRIVAL según política de llegadas.
    let min_interarrival = 3.0_f64;   // minutos (configurable)
    let max_interarrival = 7.0_f64;  // minutos (configurable)

    // Estado del sistema: momento absoluto en el que cada máquina queda libre
    let mut stage_free_times = vec![0.0f64; config.stages.len()];
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;

    // Estadísticas globales
    let mut total_wait_time = 0.0;
    let mut total_arrivals_count: u64 = 0; // contamos todos los que llegaron (incluyendo abandonos)
    
    for h in 0..config.hours {
        let hour_start = (h as f64) * 60.0;
        let hour_end = hour_start + 60.0;

        // A. Determinar cuántos llegan (Poisson) — esto define la "estimación" de llegadas para la hora.
        let num_arrivals: u64 = poisson_arrival.sample(&mut rng) as u64;

        // B. Generar llegadas secuenciales: el primer carro llega en hour_start,
        // luego cada siguiente a prev + U(min_interarrival, max_interarrival).
        let mut arrival_offsets: Vec<f64> = Vec::with_capacity(num_arrivals as usize);
        let mut next_offset = 0.0_f64; // primer arrival en 0 (inicio de la hora)
        for i in 0..num_arrivals {
            if i == 0 {
                next_offset = 0.0;
            } else {
                let gap = rng.gen_range(min_interarrival..=max_interarrival);
                next_offset += gap;
            }
            arrival_offsets.push(next_offset);
        }

        // Nota: si alguna arrival_offsets[i] >= 60.0 => ese carro (y los posteriores) no llegaron dentro de la hora
        // y se marcarán como 'left' (insatisfechos), tal como pediste.

        let mut cars_in_this_arrival_batch = Vec::new();
        let mut served_in_this_hour = 0;

        for offset in arrival_offsets {
            global_car_counter += 1;
            let arrival_abs = hour_start + offset;
            let arrival_minute = offset; // para UI

            // Si la llegada ocurre fuera de la hora -> no llegó (insatisfecho)
            if arrival_abs >= hour_end {
                // marcaremos como 'left' (no llegó). No sumamos duraciones, solo el conteo.
                total_arrivals_count += 1;
                cars_in_this_arrival_batch.push(CarResult {
                    car_id: global_car_counter,
                    arrival_time_abs: arrival_abs,
                    arrival_minute,
                    start_time: arrival_abs,
                    end_time: arrival_abs,
                    total_duration: 0.0,
                    wait_time: 0.0,
                    stage_durations: Vec::new(),
                    stage_start_times: Vec::new(),
                    stage_end_times: Vec::new(),
                    left: true,
                });
                // continue con los siguientes (también probablemente fuera de hora)
                continue;
            }

            // candidate start for first stage (machine availability vs arrival)
            let candidate_first_start = arrival_abs.max(stage_free_times[0]);

            // Si no puede iniciar antes del fin de la hora => abandona esperando
            if candidate_first_start >= hour_end {
                let wait_before_leaving = (hour_end - arrival_abs).max(0.0);
                total_wait_time += wait_before_leaving;
                total_arrivals_count += 1;

                cars_in_this_arrival_batch.push(CarResult {
                    car_id: global_car_counter,
                    arrival_time_abs: arrival_abs,
                    arrival_minute,
                    start_time: arrival_abs,
                    end_time: arrival_abs,
                    total_duration: 0.0,
                    wait_time: wait_before_leaving,
                    stage_durations: Vec::new(),
                    stage_start_times: Vec::new(),
                    stage_end_times: Vec::new(),
                    left: true,
                });
                continue;
            }

            // entra en servicio: simulamos todas las etapas, guardando start/end por etapa
            let mut current_time_in_sys = arrival_abs;
            let mut first_stage_start = 0.0;
            let mut durations_per_stage: Vec<f64> = Vec::with_capacity(config.stages.len());
            let mut starts_per_stage: Vec<f64> = Vec::with_capacity(config.stages.len());
            let mut ends_per_stage: Vec<f64> = Vec::with_capacity(config.stages.len());

            for (idx, stage) in config.stages.iter().enumerate() {
                // Generar duración
                let duration = match stage.dist_type.as_str() {
                    "normal" => {
                        let std_dev = stage.p2.sqrt(); 
                        let d = Normal::new(stage.p1, std_dev).unwrap();
                        d.sample(&mut rng).max(0.0)
                    },
                    "exponential" => {
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

                durations_per_stage.push(duration);

                // start for this stage: cannot start before car arrives here (current_time_in_sys)
                // and cannot start before the machine is free (stage_free_times[idx])
                let start_stage = current_time_in_sys.max(stage_free_times[idx]);
                let end_stage = start_stage + duration;

                // record start/end times for audit
                starts_per_stage.push(start_stage);
                ends_per_stage.push(end_stage);

                if idx == 0 { first_stage_start = start_stage; }

                // reserve the machine: it will be busy until end_stage
                stage_free_times[idx] = end_stage;
                // advance the car's internal clock to when it leaves this stage
                current_time_in_sys = end_stage;
            }

            let finish_abs = current_time_in_sys;
            let wait_time = (first_stage_start - arrival_abs).max(0.0);
            let total_process_time = finish_abs - first_stage_start;

            // Guardamos stats globales
            total_wait_time += wait_time;
            total_arrivals_count += 1;

            if finish_abs <= hour_end {
                served_in_this_hour += 1;
            }

            // Sanity: total duration
            let sum_durs: f64 = durations_per_stage.iter().sum();
            let total_duration = if (sum_durs - total_process_time).abs() > 1e-8 {
                total_process_time
            } else {
                total_process_time
            };

            cars_in_this_arrival_batch.push(CarResult {
                car_id: global_car_counter,
                arrival_time_abs: arrival_abs,
                arrival_minute,
                start_time: first_stage_start,
                end_time: finish_abs,
                total_duration,
                wait_time,
                stage_durations: durations_per_stage,
                stage_start_times: starts_per_stage,
                stage_end_times: ends_per_stage,
                left: false,
            });
        }

        // Pendientes: los que empezaron pero no terminaron dentro de la hora
        let mut pending_in_hour = 0;
        for car in &cars_in_this_arrival_batch {
            if !car.left && car.end_time > hour_end {
                pending_in_hour += 1;
            }
        }

        sim_hours.push(HourMetrics {
            hour_index: h + 1,
            estimated_arrivals: num_arrivals,
            served_count: served_in_this_hour,
            pending_count: pending_in_hour,
            cars: cars_in_this_arrival_batch,
        });
    }

    let avg_wait = if total_arrivals_count > 0 { total_wait_time / total_arrivals_count as f64 } else { 0.0 };

    let response = SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_wait_time: avg_wait,
    };

    Ok(to_cstring(&response))
}

