mod models;
mod engine;

use std::ffi::{c_char, CStr};
use crate::json_helpers::to_cstring;
use crate::errors::Error;
use models::SimConfig;

pub fn run_simulation_dynamic(json_config: *const c_char) -> Result<*mut c_char, Error> {
    if json_config.is_null() { return Err(Error::NullOrEmptyInput); }
    
    let config: SimConfig = unsafe {
        let c_str = CStr::from_ptr(json_config);
        let s = c_str.to_str().map_err(|_| Error::Other("Invalid UTF-8".into()))?;
        serde_json::from_str(s)?
    };

    let response = engine::execute_simulation(config)?;
    Ok(to_cstring(&response))
}