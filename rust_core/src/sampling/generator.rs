// src/sampling/generator.rs
use rand::{Rng, SeedableRng}; // Corregido import
use rand_chacha::ChaCha20Rng;
use rand_distr::{Distribution, Normal, Exp, Uniform}; // Importar traits necesarios
use std::slice;
use crate::sampling::distributions; // Helper antiguo
use crate::json_helpers::to_cstring;
use crate::errors::Error;

/// Fill a buffer with uniform(0,1)
pub fn generate_uniform(ptr: *mut f64, len: usize, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        // Usamos la implementación optimizada de rand_distr
        let dist = Uniform::new(0.0, 1.0);
        for v in buf.iter_mut() {
            *v = dist.sample(&mut rng);
        }
    }
}

pub fn generate_exponential_inverse(ptr: *mut f64, len: usize, beta: f64, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let lambda = if beta.abs() < 1e-9 { 1.0 } else { 1.0 / beta };
        
        // Optimización: Crear distribución fuera del loop
        let dist = Exp::new(lambda).unwrap();
        for v in buf.iter_mut() {
            *v = dist.sample(&mut rng);
        }
    }
}

pub fn generate_normal(ptr: *mut f64, len: usize, mean: f64, std: f64, seed: u64) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        
        // Optimización: Crear distribución fuera del loop
        let dist = Normal::new(mean, std).unwrap();
        for v in buf.iter_mut() {
            *v = dist.sample(&mut rng);
        }
    }
}

pub fn generate_poisson(ptr: *mut f64, len: usize, lambda: f64, seed: u64 ) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        
        let dist = rand_distr::Poisson::new(lambda).unwrap();
        for v in buf.iter_mut() {
            *v = dist.sample(&mut rng) as f64;
        }
    }
}

pub fn generate_binomial(ptr: *mut f64, len: usize, n: u64, p: f64, seed: u64 ) {
    unsafe {
        if ptr.is_null() || len == 0 { return; }
        let buf = slice::from_raw_parts_mut(ptr, len);
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        
        let dist = rand_distr::Binomial::new(n, p).unwrap();
        for v in buf.iter_mut() {
            *v = dist.sample(&mut rng) as f64;
        }
    }
}

// --- MONTECARLO OPTIMIZADO ---

// Enum interno para evitar comparaciones de strings/ids en el bucle caliente
enum PreparedDist {
    Uniform(Uniform<f64>),
    Normal(Normal<f64>),
    Exponential(Exp<f64>),
    // Aquí puedes agregar Gamma, Beta, etc. en el futuro
}

impl PreparedDist {
    #[inline(always)]
    fn sample<R: Rng + ?Sized>(&self, rng: &mut R) -> f64 {
        match self {
            PreparedDist::Uniform(d) => d.sample(rng),
            PreparedDist::Normal(d) => d.sample(rng),
            PreparedDist::Exponential(d) => d.sample(rng),
        }
    }
}

pub fn montecarlo_stats_json(
    dist_id: i32,
    n_samples: usize,
    n_trials: usize,
    param1: f64,
    param2: f64,
    seed: u64,
) -> Result<*mut libc::c_char, Error> {
    if n_samples == 0 || n_trials == 0 { return Err(Error::NullOrEmptyInput); }
    
    // 1. Preparar la distribución UNA SOLA VEZ
    let dist = match dist_id {
        0 => PreparedDist::Uniform(Uniform::new(0.0, 1.0)), 
        // Nota: Uniforme estándar es 0-1, si necesitas parámetros, ajusta aquí.
        // Si param1/param2 se usan para min/max en uniforme, cámbialo a Uniform::new(param1, param2)
        
        1 => PreparedDist::Normal(Normal::new(param1, param2).unwrap()), // param1=mean, param2=std
        
        2 => {
            // param1 = beta (scale). lambda = 1/beta
            let lambda = if param1.abs() < 1e-9 { 1.0 } else { 1.0 / param1 };
            PreparedDist::Exponential(Exp::new(lambda).unwrap())
        },
        
        // Default fallback
        _ => PreparedDist::Uniform(Uniform::new(0.0, 1.0)),
    };

    let mut rng = ChaCha20Rng::seed_from_u64(seed);
    let mut results = Vec::with_capacity(n_trials);

    // 2. Bucle optimizado
    for _ in 0..n_trials {
        let mut sum = 0.0f64;
        for _ in 0..n_samples {
            sum += dist.sample(&mut rng);
        }
        results.push(sum / (n_samples as f64));
    }

    Ok(to_cstring(&results))
}