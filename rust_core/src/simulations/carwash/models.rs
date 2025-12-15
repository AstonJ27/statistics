use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct StageConfig {
    pub name: String,
    pub dist_type: String,
    pub p1: f64,
    pub p2: f64,
}

#[derive(Deserialize)]
pub struct SimConfig {
    pub hours: i32,
    pub lambda_arrival: f64,
    pub stages: Vec<StageConfig>,
    pub tolerance: f64,
    pub abandon_prob: f64,
}

#[derive(Serialize, Clone)]
pub struct CarResult {
    pub car_id: i32,
    pub arrival_time_abs: f64,
    pub arrival_minute: f64,
    pub start_time: f64,
    pub end_time: f64,
    pub total_duration: f64,
    pub wait_time: f64,
    pub idle_time: f64,
    pub stage_durations: Vec<f64>,
    pub stage_start_times: Vec<f64>,
    pub stage_end_times: Vec<f64>,
    pub left: bool,
    pub pending: bool,
    pub satisfied: bool,
    pub hour_arrived: i32,
}

#[derive(Serialize)]
pub struct HourMetrics {
    pub hour_index: i32,
    pub estimated_arrivals: u64,
    pub served_count: i32,
    pub pending_count: i32,
    pub left_count: i32,
    pub cars: Vec<CarResult>,
}

#[derive(Serialize)]
pub struct SimulationResponse {
    pub hours: Vec<HourMetrics>,
    pub total_cars: i32,
    pub avg_wait_time: f64,
    pub max_wait_time: f64,
}