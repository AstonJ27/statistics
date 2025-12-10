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

// LÓGICA PURA: Recibe un slice, devuelve Vector de estructuras.
// Analysis.rs puede llamar a esto directamente.
pub fn calculate_stem_leaf_logic(data: &[f64], scale: f64) -> Vec<StemLeaf> {
    let safe_scale = if scale <= 0.0 { 1.0 } else { scale };
    let mut map: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
    
    for &x in data {
        // Redondeo seguro para evitar errores de precisión flotante
        let scaled = (x * safe_scale).round() as i64;
        let stem = scaled / (safe_scale as i64);
        let leaf = (scaled % (safe_scale as i64)).abs();
        map.entry(stem).or_default().push(leaf);
    }
    
    let mut out = Vec::new();
    for (stem, mut leaves) in map {
        leaves.sort_unstable();
        out.push(StemLeaf { stem, leaves });
    }
    out
}

// WRAPPER FFI: Para llamar solo esto desde Flutter si fuera necesario
pub fn stem_leaf_json(ptr: *const f64, len: usize, scale: f64) -> Result<*mut libc::c_char, Error> {
    if !check_ptr_len(ptr, len) { return Err(Error::NullOrEmptyInput); }
    if scale <= 0.0 { return Err(Error::Other("scale must be > 0".to_string())); }
    
    unsafe {
        let data = slice::from_raw_parts(ptr, len);
        let result = calculate_stem_leaf_logic(data, scale);
        Ok(to_cstring(&result))
    }
}