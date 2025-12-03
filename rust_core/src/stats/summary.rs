use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use std::slice;
use std::collections::HashMap;

#[derive(Serialize, Debug)]
pub struct SummaryStats {
    pub n: usize,
    pub mean: f64,
    pub variance_pop: f64,
    pub variance_sample: f64,
    pub std_pop: f64,
    pub std_sample: f64,
    pub median: f64,
    pub mode: Vec<f64>, // Lista para soportar múltiples modas
    pub skewness: f64,
    pub kurtosis_excess: f64,
    pub min: f64,
    pub max: f64,
    pub range: f64,
    // Nuevos campos solicitados
    pub k: usize,
    pub amplitude: f64,
}

fn percentile(sorted: &Vec<f64>, p: f64) -> f64 {
    let n = sorted.len();
    if n == 0 { return f64::NAN; }
    let r = p * (n as f64 - 1.0);
    let i = r.floor() as usize;
    let f = r - (i as f64);
    if i + 1 < n { sorted[i] * (1.0 - f) + sorted[i+1] * f } else { sorted[i] }
}

/// Función interna pura de Rust. Recibe 'nbins' (k) calculado externamente.
pub fn calculate_summary(data: &Vec<f64>, nbins: usize) -> SummaryStats {
    let n = data.len();
    if n == 0 {
        // Retorno seguro vacío
        return SummaryStats {
            n: 0, mean: 0.0, variance_pop: 0.0, variance_sample: 0.0,
            std_pop: 0.0, std_sample: 0.0, median: 0.0, mode: vec![],
            skewness: 0.0, kurtosis_excess: 0.0, min: 0.0, max: 0.0, range: 0.0,
            k: nbins, amplitude: 0.0,
        };
    }

    // 1. Min, Max, Suma
    let mut min = f64::MAX;
    let mut max = f64::MIN;
    let mut sum = 0.0;
    
    for &x in data {
        if x < min { min = x; }
        if x > max { max = x; }
        sum += x;
    }
    
    let range = max - min;
    let safe_nbins = if nbins == 0 { 1 } else { nbins };
    let amplitude = if range == 0.0 { 0.0 } else { range / (safe_nbins as f64) };
    let mean = sum / (n as f64);

    // 2. Momentos (Varianza, Asimetría, Curtosis)
    let mut m2 = 0.0;
    let mut m3 = 0.0;
    let mut m4 = 0.0;

    for &x in data {
        let d = x - mean;
        let d2 = d*d;
        m2 += d2;
        m3 += d2 * d;
        m4 += d2 * d2;
    }

    let variance_pop = m2 / (n as f64);
    let variance_sample = if n > 1 { m2 / ((n - 1) as f64) } else { 0.0 };
    let std_pop = variance_pop.sqrt();
    let std_sample = variance_sample.sqrt();

    let skewness = if m2 == 0.0 { 0.0 } else { ((n as f64) * m3) / m2.powf(1.5) };
    let kurtosis_excess = if m2 == 0.0 { -3.0 } else { ((n as f64) * m4) / (m2*m2) - 3.0 };

    // 3. Mediana (requiere orden)
    let mut sorted = data.clone();
    sorted.sort_by(|a,b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let median = percentile(&sorted, 0.5);

    // 4. Moda (con agrupación por precisión para floats)
    let mut counts: HashMap<i64, usize> = HashMap::new();
    let precision = 10000.0; // 4 decimales
    for &x in data {
        let key = (x * precision).round() as i64;
        *counts.entry(key).or_insert(0) += 1;
    }
    
    let mut max_freq = 0;
    for &c in counts.values() {
        if c > max_freq { max_freq = c; }
    }

    let mut modes = Vec::new();
    // Solo reportamos moda si hay repetición (>1)
    if max_freq > 1 { 
        for (&k_int, &c) in &counts {
            if c == max_freq {
                modes.push((k_int as f64) / precision);
            }
        }
    }
    modes.sort_by(|a,b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

    SummaryStats {
        n,
        mean,
        variance_pop,
        variance_sample,
        std_pop,
        std_sample,
        median,
        mode: modes,
        skewness,
        kurtosis_excess,
        min,
        max,
        range,
        k: safe_nbins,
        amplitude,
    }
}

// FFI Wrapper para uso directo si es necesario
pub fn summary_stats_json(ptr: *const f64, len: usize) -> Result<*mut std::os::raw::c_char, crate::errors::Error> {
    if !check_ptr_len(ptr, len) { return Err(crate::errors::Error::NullOrEmptyInput); }
    unsafe {
        let data = slice::from_raw_parts(ptr, len).to_vec();
        // Calculamos K internamente porque la firma FFI antigua no lo recibe
        let k = crate::utils::sturges_bins(len);
        let stats = calculate_summary(&data, k);
        Ok(to_cstring(&stats))
    }
}