// src/sampling/generator.rs
use rand::{Rng, rngs};
use rand_chacha::ChaCha20Rng;
use rand::SeedableRng;
use std::slice;
use crate::sampling::distributions;
use crate::json_helpers::to_cstring;
use crate::errors::Error;

/// Fill a buffer with uniform(0,1)
pub fn generate_uniform(ptr: *mut f64, len: usize, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        for v in buf.iter_mut() {
            // Usa la función definida en distributions.rs
            *v = distributions::uniform_sample(&mut rng);
        }
    }
}

/// Fill a buffer with Exponential samples
/// Note: The frontend sends 'beta' (scale/mean). 
/// distributions.rs uses Exp::new(lambda), so we convert: lambda = 1.0 / beta
pub fn generate_exponential_inverse(ptr: *mut f64, len: usize, beta: f64, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        
        let lambda = if beta.abs() < 1e-9 { 1.0 } else { 1.0 / beta };
        
        for v in buf.iter_mut() {
            *v = distributions::exponential_inverse_sample(&mut rng, lambda);
        }
    }
}


/// Fill a buffer with samples from Normal(mean, std)
pub fn generate_normal(ptr: *mut f64, len: usize, mean: f64, std: f64, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        for v in buf.iter_mut() {
            // Llama a la función de muestreo Normal de distributions.rs
            *v = distributions::normal_sample(&mut rng, mean, std);
        }
    }
}

pub fn generate_poisson(ptr: *mut f64, len: usize, lambda: f64, seed: u64 ) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        for v in buf.iter_mut() {
            *v = distributions::poisson_sample(&mut rng, lambda) as f64;
        }
    }
}

pub fn generate_binomial(ptr: *mut f64, len: usize, n: u64, p: f64, seed: u64 ) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        for v in buf.iter_mut() {
            *v = distributions::binomial_sample(&mut rng, n, p) as f64;
        }
    }
}


/// Simple Monte Carlo: for each trial generate n_samples from dist_id and compute mean.
/// dist_id: 0=Uniform,1=Normal,2=Exponential
/// Returns JSON array of means as *mut c_char
pub fn montecarlo_stats_json(
    dist_id: i32,
    n_samples: usize,
    n_trials: usize,
    param1: f64,
    param2: f64,
    seed: u64,
) -> Result<*mut libc::c_char, Error> {
    if n_samples == 0 || n_trials == 0 { return Err(Error::NullOrEmptyInput); }
    let mut rng = ChaCha20Rng::seed_from_u64(seed);
    let mut results = Vec::with_capacity(n_trials);
    for _ in 0..n_trials {
        let mut sum = 0.0f64;
        for _ in 0..n_samples {
            let x = match dist_id {
                0 => distributions::uniform_sample(&mut rng),
                1 => distributions::normal_sample(&mut rng, param1, param2),
                2 => distributions::exponential_inverse_sample(&mut rng, param1),
                _ => distributions::uniform_sample(&mut rng),
            };
            sum += x;
        }
        results.push(sum / (n_samples as f64));
    }
    Ok(to_cstring(&results))
}
