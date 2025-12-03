// src/aggregation/boxplot.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use std::slice;
use crate::errors::Error;

#[derive(Serialize)]
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

fn percentile(sorted: &Vec<f64>, p: f64) -> f64 {
    let n = sorted.len();
    if n == 0 { return f64::NAN; }
    let r = p * (n as f64 - 1.0);
    let i = r.floor() as usize;
    let f = r - (i as f64);
    if i + 1 < n { sorted[i] * (1.0 - f) + sorted[i+1] * f } else { sorted[i] }
}

pub fn boxplot_json(ptr: *const f64, len: usize) -> Result<*mut libc::c_char, Error> {
    if !check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    unsafe {
        let mut data = slice::from_raw_parts(ptr, len).to_vec();
        data.sort_by(|a,b| a.partial_cmp(b).unwrap());
        let minv = *data.first().unwrap();
        let maxv = *data.last().unwrap();
        let q1 = percentile(&data, 0.25);
        let median = percentile(&data, 0.5);
        let q3 = percentile(&data, 0.75);
        let iqr = q3 - q1;
        let lower_f = q1 - 1.5 * iqr;
        let upper_f = q3 + 1.5 * iqr;
        let outliers: Vec<f64> = data.iter().cloned().filter(|&x| x < lower_f || x > upper_f).collect();
        let stats = BoxStats { min: minv, q1, median, q3, max: maxv, iqr, lower_fence: lower_f, upper_fence: upper_f, outliers };
        Ok(to_cstring(&stats))
    }
}
