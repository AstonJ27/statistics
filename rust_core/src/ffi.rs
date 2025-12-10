// src/ffi.rs
//use std::ptr;

/// Check that a pointer is not null and len > 0
pub fn check_ptr_len<T>(ptr: *const T, len: usize) -> bool {
    !(ptr.is_null() || len == 0)
}
