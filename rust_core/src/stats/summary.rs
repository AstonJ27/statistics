// src/stats/summary.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use std::slice;

#[derive(Serialize, Debug, Clone)]
pub struct SummaryStats {
    pub n: usize,
    pub mean: f64,
    pub variance_pop: f64,
    pub variance_sample: f64,
    pub std_pop: f64,
    pub std_sample: f64,
    pub cv: f64,    // Nuevo campo
    pub median: f64,
    pub mode: Vec<f64>,
    pub skewness: f64,
    pub kurtosis_excess: f64,
    pub min: f64,
    pub max: f64,
    pub range: f64,
    pub k: usize,
    pub amplitude: f64,
}

/// Lógica PURA: Recibe un slice YA ORDENADO.
/// Esto evita reordenar múltiples veces en analysis.rs.
pub fn calculate_summary_sorted(sorted_data: &[f64], nbins: usize) -> SummaryStats {
    let n = sorted_data.len();
    
    if n == 0 {
        return SummaryStats {
            n: 0, mean: 0.0, variance_pop: 0.0, variance_sample: 0.0,
            std_pop: 0.0, std_sample: 0.0, cv: 0.0, median: 0.0, mode: vec![],
            skewness: 0.0, kurtosis_excess: 0.0, min: 0.0, max: 0.0, range: 0.0,
            k: nbins, amplitude: 0.0,
        };
    }

    let min = sorted_data[0];
    let max = sorted_data[n - 1];
    let range = max - min;
    let sum: f64 = sorted_data.iter().sum();
    let mean = sum / (n as f64);
    
    // Amplitud segura
    let safe_nbins = if nbins == 0 { 1 } else { nbins };
    let amplitude = if range == 0.0 { 0.0 } else { range / (safe_nbins as f64) };

    // Momentos
    let mut m2 = 0.0;
    let mut m3 = 0.0;
    let mut m4 = 0.0;

    for &x in sorted_data {
        let d = x - mean;
        let d2 = d * d;
        m2 += d2;
        m3 += d2 * d;
        m4 += d2 * d2;
    }

    let variance_pop = m2 / (n as f64);
    let variance_sample = if n > 1 { m2 / ((n - 1) as f64) } else { 0.0 };
    let std_pop = variance_pop.sqrt();
    let std_sample = variance_sample.sqrt();

    let cv = if mean.abs() < 1e-9 {0.0} else {(std_sample/mean) * 100.0};

    let skewness = if m2 == 0.0 { 0.0 } else { ((n as f64) * m3) / m2.powf(1.5) };
    let kurtosis_excess = if m2 == 0.0 { -3.0 } else { ((n as f64) * m4) / (m2 * m2) - 3.0 };

    // Mediana (Acceso directo O(1) porque ya está ordenado)
    let mid = n / 2;
    let median = if n % 2 == 0 {
        (sorted_data[mid - 1] + sorted_data[mid]) * 0.5
    } else {
        sorted_data[mid]
    };

    // Moda: Algoritmo de barrido lineal O(N) optimizado (sin HashMap)
    let mut modes = Vec::new();
    let mut max_streak = 0;
    let mut current_streak = 0;
    let mut current_val = sorted_data[0];
    let precision = 10000.0; // Tolerancia para agrupar floats

    // Paso 1: Encontrar frecuencia máxima
    for &x in sorted_data {
        // Comparamos usando epsilon implícito con la precisión
        if (x - current_val).abs() * precision < 1.0 {
            current_streak += 1;
        } else {
            if current_streak > max_streak { max_streak = current_streak; }
            current_streak = 1;
            current_val = x;
        }
    }
    if current_streak > max_streak { max_streak = current_streak; }

    // Paso 2: Recolectar modas (solo si hay repetición > 1)
    if max_streak > 1 {
        current_streak = 0;
        current_val = sorted_data[0];
        for &x in sorted_data {
            if (x - current_val).abs() * precision < 1.0 {
                current_streak += 1;
            } else {
                if current_streak == max_streak { modes.push(current_val); }
                current_streak = 1;
                current_val = x;
            }
        }
        if current_streak == max_streak { modes.push(current_val); }
    }
    
    
    modes.dedup_by(|a, b| (*a - *b).abs() < 1e-9);

    SummaryStats {
        n, mean, variance_pop, variance_sample, std_pop, std_sample, cv,
        median, mode: modes, skewness, kurtosis_excess, min, max, range,
        k: safe_nbins, amplitude,
    }
}

// Wrapper FFI
pub fn summary_stats_json(ptr: *const f64, len: usize) -> Result<*mut std::os::raw::c_char, crate::errors::Error> {
    if !check_ptr_len(ptr, len) { return Err(crate::errors::Error::NullOrEmptyInput); }
    unsafe {
        let mut data = slice::from_raw_parts(ptr, len).to_vec();
        // Ordenamos aquí para este endpoint específico
        data.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        
        let k = crate::utils::sturges_bins(len);
        let stats = calculate_summary_sorted(&data, k);
        Ok(to_cstring(&stats))
    }
}