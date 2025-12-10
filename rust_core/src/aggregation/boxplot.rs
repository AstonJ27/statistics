// src/aggregation/boxplot.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use std::slice;
use crate::errors::Error;

#[derive(Serialize, Clone)]
pub struct BoxStats {
    pub min: f64,
    pub q1: f64,
    pub median: f64,
    pub q3: f64,
    pub max: f64,
    pub iqr: f64,
    pub lower_fence: f64,
    pub upper_fence: f64,
    pub outliers: Vec<f64>,
}

fn percentile_sorted(sorted: &[f64], p: f64) -> f64 {
    let n = sorted.len();
    if n == 0 { return f64::NAN; }
    let r = p * (n as f64 - 1.0);
    let i = r.floor() as usize;
    let f = r - (i as f64);
    if i + 1 < n { sorted[i] * (1.0 - f) + sorted[i+1] * f } else { sorted[i] }
}

/// Lógica Pura: Asume datos ordenados
pub fn calculate_boxplot_sorted(sorted_data: &[f64]) -> BoxStats {
    if sorted_data.is_empty() {
        return BoxStats { min:0.0, q1:0.0, median:0.0, q3:0.0, max:0.0, iqr:0.0, lower_fence:0.0, upper_fence:0.0, outliers: vec![] };
    }
    
    let minv = *sorted_data.first().unwrap();
    let maxv = *sorted_data.last().unwrap();
    
    let q1 = percentile_sorted(sorted_data, 0.25);
    let median = percentile_sorted(sorted_data, 0.5);
    let q3 = percentile_sorted(sorted_data, 0.75);
    
    let iqr = q3 - q1;
    let lower_f = q1 - 1.5 * iqr;
    let upper_f = q3 + 1.5 * iqr;
    
    // Outliers: al estar ordenado, podríamos optimizar la búsqueda, 
    // pero filter es suficientemente rápido y claro.
    let outliers: Vec<f64> = sorted_data.iter().cloned()
        .filter(|&x| x < lower_f || x > upper_f).collect();
        
    BoxStats { min: minv, q1, median, q3, max: maxv, iqr, lower_fence: lower_f, upper_fence: upper_f, outliers }
}

// Wrapper FFI
pub fn boxplot_json(ptr: *const f64, len: usize) -> Result<*mut libc::c_char, Error> {
    if !check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    unsafe {
        let mut data = slice::from_raw_parts(ptr, len).to_vec();
        data.sort_by(|a,b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let stats = calculate_boxplot_sorted(&data);
        Ok(to_cstring(&stats))
    }
}