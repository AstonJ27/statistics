pub mod models;
pub mod engine;

use std::ffi::{c_char, CStr};
use serde::Serialize;
use crate::json_helpers::to_cstring; // Usamos el helper existente
//use crate::errors::Error;
use models::MonteCarloConfig;

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

pub fn run_montecarlo(json_config: *const c_char) -> *mut c_char {
    if json_config.is_null() {
        return to_cstring(&ErrorResponse { error: "Null input pointer".to_string() });
    }
    
    // 1. Parseo seguro
    let config_result: Result<MonteCarloConfig, _> = unsafe {
        let c_str = CStr::from_ptr(json_config);
        let s = c_str.to_str().unwrap_or("");
        serde_json::from_str(s)
    };

    let config = match config_result {
        Ok(c) => c,
        Err(e) => return to_cstring(&ErrorResponse { error: format!("JSON Error: {}", e) }),
    };

    // 2. Ejecución
    match engine::execute(config) {
        Ok(response) => to_cstring(&response),
        Err(e) => to_cstring(&ErrorResponse { error: format!("Simulation Error: {}", e) }),
    }
}