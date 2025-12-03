// src/aggregation/stem_leaf.rs
use serde::Serialize;
use crate::json_helpers::to_cstring;
use crate::ffi::check_ptr_len;
use std::collections::BTreeMap;
use std::slice;
use crate::errors::Error;

#[derive(Serialize)]
pub struct StemLeaf {
    pub stem: i64,
    pub leaves: Vec<i64>,
}

/// scale: multiplicador para ajustar precisión (e.g., 10 para 1 decimal)
pub fn stem_leaf_json(ptr: *const f64, len: usize, scale: f64) -> Result<*mut libc::c_char, Error> {
    
    if !check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    
    if scale <= 0.0 { return Err(Error::Other("scale must be > 0".to_string())); }
    
    unsafe {
        let data = slice::from_raw_parts(ptr, len);
        let mut map: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
        for &x in data.iter() {
            let scaled = (x * scale).round() as i64;
            let stem = scaled / (scale as i64);
            let leaf = (scaled % (scale as i64)).abs();
            map.entry(stem).or_default().push(leaf);
        }
        let mut out = Vec::new();
        for (stem, mut leaves) in map {
            leaves.sort_unstable();
            out.push(StemLeaf { stem, leaves });
        }
        Ok(to_cstring(&out))
    }
}
