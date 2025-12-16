// src/lib.rs
mod ffi;
mod json_helpers;
mod utils;
mod errors;

mod analysis;

pub mod sampling;
pub mod aggregation;
pub mod stats;
pub mod probabilities;

pub use crate::json_helpers::free_c_string;
use std::ffi::{c_char};

// nueva version ahora con simulacion
pub mod simulations {
    pub mod carwash;
    pub mod montecarlo;
}

// 1. ANALYZE (Función Principal Unificada)
#[no_mangle]
pub extern "C" fn analyze_distribution_json(
    ptr: *const f64, 
    len: usize, 
    h_round: i32, 
    forced_k: usize, 
    forced_min: f64, // <-- Nuevo
    forced_max: f64  // <-- Nuevo
) -> *mut c_char {
    let hr = h_round != 0;
    // Pasa los nuevos parámetros al módulo analysis
    match analysis::analyze_distribution_json(ptr, len, hr, forced_k, forced_min, forced_max) {
        Ok(p) => p as *mut c_char,
        Err(_) => std::ptr::null_mut(),
    }
}

// ---------- Wrappers FFI simples (exponer lo necesario) ----------

// Buffer-fillers (generación)

// generate_uniform(ptr, len, seed)
#[no_mangle]
pub extern "C" fn generate_uniform(ptr: *mut f64, len: usize, seed: u64) {
    sampling::generator::generate_uniform(ptr, len, seed);
}

// generate_normal(ptr, len, mean, std, seed)
#[no_mangle]
pub extern "C" fn generate_normal(ptr: *mut f64, len: usize, mean: f64, std: f64, seed: u64) {
    sampling::generator::generate_normal(ptr, len, mean, std, seed);
}

// generate_exponential_inverse(ptr, len, beta, seed)
// Note: Frontend passes beta (scale), generator converts to lambda internally.
#[no_mangle]
pub extern "C" fn generate_exponential_inverse(ptr: *mut f64, len: usize, beta: f64, seed: u64) {
    sampling::generator::generate_exponential_inverse(ptr, len, beta, seed);
}

// generate_poisson(ptr, len, lambda, seed)
#[no_mangle]
pub extern "C" fn generate_poisson(ptr: *mut f64, len: usize, lambda: f64, seed: u64) {
    sampling::generator::generate_poisson(ptr, len, lambda, seed);
}

// generate_binomial(ptr, len, n, p, seed)
#[no_mangle]
pub extern "C" fn generate_binomial(ptr: *mut f64, len: usize, n: u64, p: f64, seed: u64) {
    sampling::generator::generate_binomial(ptr, len, n, p, seed);
}

// sturges bins helper
#[no_mangle]
pub extern "C" fn sturges_bins(n: usize) -> usize {
    utils::sturges_bins(n)
}

// histogram -> JSON (returns *mut c_char, free with free_c_string)
#[no_mangle]
pub extern "C" fn histogram_json(ptr: *const f64, len: usize, nbins: usize) -> *mut c_char {
    match aggregation::histogram::histogram_json(ptr, len, nbins) {
        Ok(c) => c,
        Err(_) => std::ptr::null_mut(),
    }
}

// frequency table
#[no_mangle]
pub extern "C" fn frequency_table_json(ptr: *const f64, len: usize, nbins: usize) -> *mut c_char {
    match aggregation::freq_table::frequency_table_json(ptr, len, nbins) {
        Ok(c) => c,
        Err(_) => std::ptr::null_mut(),
    }
}

// stem-leaf json
#[no_mangle]
pub extern "C" fn stem_leaf_json(ptr: *const f64, len: usize, scale: f64) -> *mut c_char {
    match aggregation::stem_leaf::stem_leaf_json(ptr, len, scale) {
        Ok(c) => c,
        Err(_) => std::ptr::null_mut(),
    }
}

// boxplot stats
#[no_mangle]
pub extern "C" fn boxplot_json(ptr: *const f64, len: usize) -> *mut c_char {
    match aggregation::boxplot::boxplot_json(ptr, len) {
        Ok(c) => c,
        Err(_) => std::ptr::null_mut(),
    }
}

// summary stats
#[no_mangle]
pub extern "C" fn summary_stats_json(ptr: *const f64, len: usize) -> *mut c_char {
    match stats::summary::summary_stats_json(ptr, len) {
        Ok(c) => c,
        Err(_) => std::ptr::null_mut(),
    }
}


// expose a version
#[no_mangle]
pub extern "C" fn rust_core_version() -> u32 {
    1u32
}

// ---------- NUEVA SECCIÓN DE SIMULACIÓN ----------
#[no_mangle]
pub extern "C" fn simulate_carwash_dynamic(json_config: *const c_char) -> *mut c_char {
    // Llamamos a la función del módulo carwash
    match simulations::carwash::run_simulation_dynamic(json_config) {
        Ok(ptr) => ptr,
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn simulation_montecarlo(json_config: *const libc::c_char) -> *mut libc::c_char {
    // Delegamos al módulo. El módulo ya retorna *mut c_char seguro usando to_cstring.
    simulations::montecarlo::run_montecarlo(json_config)
}

// ---------- CALCULADORA INVERSA (CDF) ----------
#[no_mangle]
pub extern "C" fn calculate_inverse_cdf(json_request: *const libc::c_char) -> *mut libc::c_char {
    use std::ffi::CStr;
    use probabilities::cdf_pdf::{InverseCdfRequest, calculate_inverse};
    use crate::json_helpers::to_cstring;

    if json_request.is_null() { 
        return to_cstring(&serde_json::json!({"error": "Null pointer input"})); 
    }

    // Parsear input
    let req_result: Result<InverseCdfRequest, _> = unsafe {
        let c_str = CStr::from_ptr(json_request);
        let str_slice = c_str.to_str().unwrap_or("{}");
        serde_json::from_str(str_slice)
    };

    match req_result {
        Ok(req) => {
            // Ejecutar lógica
            match calculate_inverse(req) {
                Ok(res) => to_cstring(&res),
                Err(e) => to_cstring(&serde_json::json!({"error": e}))
            }
        },
        Err(e) => to_cstring(&serde_json::json!({"error": format!("JSON Parse Error: {}", e)}))
    }
}