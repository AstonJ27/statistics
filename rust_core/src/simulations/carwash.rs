// src/simulations/carwash.rs
use serde::Serialize;
use rand::prelude::*;
use rand_distr::{Exp, Normal, Poisson, Uniform, Distribution};
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use std::ffi::c_char;

// Estructuras de Salida (Output Models)
#[derive(Serialize)]
struct CarResult {
    car_id: i32,
    clean_time: f64, // Normal
    wash_time: f64,  // Exponencial
    dry_time: f64,   // Uniforme
    total_time: f64,
}

#[derive(Serialize)]
struct HourResult {
    hour_index: i32,
    cars_arrived: u64,
    cars: Vec<CarResult>,
}

#[derive(Serialize)]
struct SimulationResponse {
    hours: Vec<HourResult>,
    total_cars: i32,
    avg_total_time: f64,
    std_total_time: f64,
}

pub fn run_carwash_simulation(hours_to_simulate: i32, lambda_arrival: f64) -> Result<*mut c_char, Error> {
    // Validación básica de entrada
    if hours_to_simulate <= 0 {
        return Err(Error::NullOrEmptyInput);
    }
    if lambda_arrival < 0.0 {
        // Usamos Error::Other porque no es NullOrEmptyInput, es un valor inválido lógico
        return Err(Error::Other("Lambda cannot be negative".to_string()));
    }

    let mut rng = thread_rng();

    // 1. Definición de Distribuciones
    
    // Poisson: Llegadas por hora
    // Si falla (ej. lambda negativo o infinito), capturamos el error en Error::Other
    let poisson_dist = Poisson::new(lambda_arrival)
        .map_err(|e| Error::Other(format!("Poisson Error: {}", e)))?;
    
    // Normal(10, 2): Media 10, Varianza 2 -> Desviación Estándar = sqrt(2)
    // Normal::new(mean, std_dev)
    let normal_dist = Normal::new(10.0, 2.0f64.sqrt())
        .map_err(|e| Error::Other(format!("Normal Dist Error: {}", e)))?;
    
    // Exponencial(beta=12): En Rust Exp toma lambda (1/beta).
    // lambda = 1 / 12
    let exp_dist = Exp::new(1.0 / 12.0)
        .map_err(|e| Error::Other(format!("Exponential Dist Error: {}", e)))?;
    
    // Uniforme(8, 12) - Uniform::new_inclusive rara vez falla con constantes hardcodeadas, 
    // pero es buena práctica no asumir.
    let uniform_dist = Uniform::new_inclusive(8.0, 12.0);

    // 2. Simulación
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;
    let mut all_total_times = Vec::new();

    for h in 1..=hours_to_simulate {
        // A. Determinar cuántos llegan (Poisson)
        let num_cars_in_hour: u64 = poisson_dist.sample(&mut rng) as u64; //revisar aqui el tipado
        
        let mut cars_in_hour_list = Vec::new();

        for _ in 0..num_cars_in_hour {
            global_car_counter += 1;

            // B. Generar tiempos de servicio
            let t_clean = normal_dist.sample(&mut rng);
            let t_wash = exp_dist.sample(&mut rng);
            let t_dry = uniform_dist.sample(&mut rng);
            
            let total = t_clean + t_wash + t_dry;
            all_total_times.push(total);

            cars_in_hour_list.push(CarResult {
                car_id: global_car_counter,
                clean_time: t_clean,
                wash_time: t_wash,
                dry_time: t_dry,
                total_time: total,
            });
        }

        sim_hours.push(HourResult {
            hour_index: h,
            cars_arrived: num_cars_in_hour,
            cars: cars_in_hour_list,
        });
    }

    // 3. Cálculos Estadísticos Globales (Media y Desviación Estándar)
    let n = all_total_times.len() as f64;
    let (mean, std_dev) = if n > 0.0 {
        let sum: f64 = all_total_times.iter().sum();
        let avg = sum / n;
        
        let variance = if n > 1.0 {
            all_total_times.iter().map(|x| (x - avg).powi(2)).sum::<f64>() / (n - 1.0)
        } else {
            0.0
        };
        (avg, variance.sqrt())
    } else {
        (0.0, 0.0)
    };

    let response = SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_total_time: mean,
        std_total_time: std_dev,
    };

    // 4. Retornar JSON String
    // to_cstring ya maneja la serialización. Si falla algo interno de serde, to_cstring suele manejarlo,
    // pero aquí devolvemos el puntero directamente.
    Ok(to_cstring(&response))
}