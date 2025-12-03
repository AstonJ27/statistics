// src/aggregation/freq_table.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use crate::utils::bin_index;
use std::slice;
use crate::errors::Error;

#[derive(Serialize)]
pub struct ClassRow {
    pub lower: f64,
    pub upper: f64,
    pub midpoint: f64,
    pub abs_freq: u32,
    pub rel_freq: f64,
    pub cum_abs: u32,
    pub cum_rel: f64,
}

#[derive(Serialize)]
pub struct FreqTable {
    pub classes: Vec<ClassRow>,
    pub amplitude: f64,
}

pub fn frequency_table_json(ptr: *const f64, len: usize, nbins: usize) -> Result<*mut libc::c_char, Error> {
    if !check_ptr_len(ptr, len) || nbins == 0 { return Err(Error::NullOrEmptyInput); }
    unsafe {
        let data = slice::from_raw_parts(ptr, len);
        let n = len as f64;
        let minv = *data.iter().min_by(|a,b| a.partial_cmp(b).unwrap()).unwrap();
        let maxv = *data.iter().max_by(|a,b| a.partial_cmp(b).unwrap()).unwrap();
        let amplitude = if (maxv - minv) == 0.0 { 1.0 } else { (maxv - minv) / (nbins as f64) };
        let mut counts = vec![0u32; nbins];
        for &x in data.iter() {
            let idx = bin_index(x, minv, amplitude, nbins);
            counts[idx] = counts[idx].saturating_add(1);
        }
        let mut rows = Vec::with_capacity(nbins);
        let mut cum_a = 0u32;
        let mut cum_r = 0.0f64;
        
        for i in 0..nbins {
            let lower = minv + (i as f64) * amplitude;
            let upper = lower + amplitude;
            //let upper = if i == nbins - 1 { maxv } else {lower + amplitude};
            
            let midpoint = 0.5 * (lower + upper);
            let abs_f = counts[i];
            cum_a += abs_f;
            let rel = (abs_f as f64) / n;
            cum_r += rel;
            rows.push(ClassRow { lower, upper, midpoint, abs_freq: abs_f, rel_freq: rel, cum_abs: cum_a, cum_rel: cum_r });
        }
        let table = FreqTable { classes: rows, amplitude };
        Ok(to_cstring(&table))
    }
}
