// src/json_helpers.rs
use serde::Serialize;
use std::ffi::{CString};
use std::os::raw::c_char;

/// Convert serializable obj -> *mut c_char (CString::into_raw)
/// Caller must call free_c_string.
pub fn to_cstring<T: Serialize>(obj: &T) -> *mut c_char {
    let s = serde_json::to_string(obj).unwrap_or_else(|e| format!("{{\"error\":\"{}\"}}", e));
    let c = CString::new(s).unwrap_or_else(|_| CString::new("{\"error\":\"nulled\"}").unwrap());
    c.into_raw()
}


/// Helper para convertir un puntero *mut c_char de vuelta a String de Rust.
/// Útil cuando llamamos internamente a funciones que retornan CStrings.
/// OJO: No libera el puntero original, eso debe hacerse con free_c_string después.
//pub unsafe fn ptr_to_string(ptr: *mut c_char) -> String {
//    if ptr.is_null() { return String::from("{}"); }
//    let c_str = CStr::from_ptr(ptr);
//    c_str.to_string_lossy().into_owned()
//}

#[no_mangle]
pub extern "C" fn free_c_string(s: *mut c_char) {
    if s.is_null() { return; }
    unsafe { let _ = CString::from_raw(s); } // dropped -> freed
}
