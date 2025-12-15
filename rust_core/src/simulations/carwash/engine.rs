use rand::prelude::*;
use rand_distr::{Exp, Normal, Uniform, Distribution};
use crate::errors::Error;
use super::models::*;

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
            PreparedDist::Normal(d) => d.sample(rng).max(0.0),
            PreparedDist::Exponential(d) => d.sample(rng),
            PreparedDist::Uniform(d) => d.sample(rng),
            PreparedDist::None => 0.0,
        }
    }
}

pub fn execute_simulation(config: SimConfig) -> Result<SimulationResponse, Error> {
    if config.hours <= 0 { return Err(Error::NullOrEmptyInput); }

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

    let mut rng = thread_rng();
    let mut stage_free_times = vec![0.0f64; config.stages.len()];
    let mut sim_hours = Vec::new();
    let mut global_car_counter = 0;
    
    let mut total_wait_time = 0.0;
    let mut max_wait_time = 0.0f64;
    let mut total_cars_processed = 0;

    let lambda_per_minute = config.lambda_arrival / 60.0;
    if lambda_per_minute <= 0.0 { return Err(Error::Other("Lambda debe ser > 0".into())); }
    let arrival_dist = Exp::new(lambda_per_minute).unwrap();

    let mut current_sim_time = 0.0;
    current_sim_time += arrival_dist.sample(&mut rng);

    for hour_idx in 0..config.hours {
        let hour_start = (hour_idx as f64) * 60.0;
        let hour_end = hour_start + 60.0;
        
        let mut cars_in_hour = Vec::new();
        let mut served_in_hour = 0;
        let mut left_in_hour = 0;
        let mut arrivals_in_hour_count = 0;

        while current_sim_time < hour_end {
            global_car_counter += 1;
            arrivals_in_hour_count += 1;
            total_cars_processed += 1;
            
            let arrival_time = current_sim_time;
            let arrival_minute = arrival_time - hour_start;
            let mut left = false;
            let mut pending = false;
            let mut satisfied = false;
            
            let candidate_start_time = arrival_time.max(stage_free_times[0]);
            let expected_wait = candidate_start_time - arrival_time;
            
            if expected_wait > config.tolerance && rng.gen_bool(config.abandon_prob) {
                left = true;
                left_in_hour += 1;
                total_wait_time += expected_wait;
                if expected_wait > max_wait_time { max_wait_time = expected_wait; }

                cars_in_hour.push(CarResult {
                    car_id: global_car_counter,
                    arrival_time_abs: arrival_time,
                    arrival_minute,
                    start_time: arrival_time,
                    end_time: arrival_time,
                    total_duration: 0.0,
                    wait_time: expected_wait,
                    idle_time: 0.0,
                    stage_durations: vec![],
                    stage_start_times: vec![],
                    stage_end_times: vec![],
                    left, pending, satisfied,
                    hour_arrived: hour_idx + 1,
                });
            } else {
                let mut current_stage_time = candidate_start_time;
                let mut total_wait = candidate_start_time - arrival_time;
                let mut total_idle_for_this_car = 0.0;

                let mut stage_durations = Vec::with_capacity(prepared_stages.len());
                let mut stage_start_times = Vec::with_capacity(prepared_stages.len());
                let mut stage_end_times = Vec::with_capacity(prepared_stages.len());
                
                let mut finishes_in_same_hour = true;
                
                for (stage_idx, dist) in prepared_stages.iter().enumerate() {
                    let server_free_at = stage_free_times[stage_idx];
                    let stage_start = current_stage_time.max(server_free_at);
                    
                    if stage_start > server_free_at {
                        total_idle_for_this_car += stage_start - server_free_at;
                    }

                    if stage_start > current_stage_time {
                        total_wait += stage_start - current_stage_time;
                    }
                    
                    let duration = dist.sample(&mut rng);
                    let stage_end = stage_start + duration;
                    
                    if stage_end > hour_end { finishes_in_same_hour = false; }
                    
                    stage_durations.push(duration);
                    stage_start_times.push(stage_start);
                    stage_end_times.push(stage_end);
                    
                    stage_free_times[stage_idx] = stage_end;
                    current_stage_time = stage_end;
                }
                
                let end_time = current_stage_time;
                let total_duration = end_time - arrival_time;
                
                if finishes_in_same_hour { satisfied = true; served_in_hour += 1; } 
                else { pending = true; }
                
                total_wait_time += total_wait;
                if total_wait > max_wait_time { max_wait_time = total_wait; }
                
                cars_in_hour.push(CarResult {
                    car_id: global_car_counter,
                    arrival_time_abs: arrival_time,
                    arrival_minute,
                    start_time: candidate_start_time,
                    end_time,
                    total_duration,
                    wait_time: total_wait,
                    idle_time: total_idle_for_this_car,
                    stage_durations,
                    stage_start_times,
                    stage_end_times,
                    left, pending, satisfied,
                    hour_arrived: hour_idx + 1,
                });
            }
            current_sim_time += arrival_dist.sample(&mut rng);
        }
        
        let pending_in_hour = cars_in_hour.iter().filter(|c| c.pending).count() as i32;
        sim_hours.push(HourMetrics {
            hour_index: hour_idx + 1,
            estimated_arrivals: arrivals_in_hour_count,
            served_count: served_in_hour,
            pending_count: pending_in_hour,
            left_count: left_in_hour,
            cars: cars_in_hour,
        });
    }
    
    let avg_wait_time = if total_cars_processed > 0 { total_wait_time / total_cars_processed as f64 } else { 0.0 };
    
    Ok(SimulationResponse {
        hours: sim_hours,
        total_cars: global_car_counter,
        avg_wait_time,
        max_wait_time,
    })
}