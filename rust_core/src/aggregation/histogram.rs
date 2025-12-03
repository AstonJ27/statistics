// src/aggregation/histogram.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use crate::utils::bin_index;
use std::slice;
use crate::errors::Error;

#[derive(Serialize)]
struct HistJson {
    edges: Vec<f64>,
    counts: Vec<u32>,
    centers: Vec<f64>,
    densities: Vec<f64>, // counts / (n * width)
}

pub fn histogram_json(ptr: *const f64, len: usize, nbins: usize) -> Result<*mut libc::c_char, Error> {
    if !check_ptr_len(ptr, len) || nbins == 0 { return Err(Error::NullOrEmptyInput); }
    unsafe {
        let data = slice::from_raw_parts(ptr, len);
        let n = len as f64;
        let minv = *data.iter().min_by(|a,b| a.partial_cmp(b).unwrap()).unwrap();
        let maxv = *data.iter().max_by(|a,b| a.partial_cmp(b).unwrap()).unwrap();
        let width = if (maxv - minv) == 0.0 { 1.0 } else { (maxv - minv) / (nbins as f64) };
        let mut counts = vec![0u32; nbins];
        for &x in data.iter() {
            let idx = bin_index(x, minv, width, nbins);
            counts[idx] = counts[idx].saturating_add(1);
        }
        let mut edges = Vec::with_capacity(nbins + 1);
        let mut centers = Vec::with_capacity(nbins);
        for i in 0..=nbins {
            edges.push(minv + (i as f64) * width);
            if i < nbins {
                centers.push(minv + (i as f64 + 0.5) * width);
            }
        }
        let densities = counts.iter().map(|&c| (c as f64) / (n * width)).collect();
        let out = HistJson { edges, counts, centers, densities };
        Ok(to_cstring(&out))
    }
}
