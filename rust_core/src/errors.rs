// src/errors.rs
use std::fmt; // <--- Importante

#[derive(Debug)]
pub enum Error {
    NullOrEmptyInput,
    SerdeError(String),
    Other(String),
}

// Implementación manual de Display para mensajes bonitos
impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::NullOrEmptyInput => write!(f, "Input was null or empty"),
            Error::SerdeError(msg) => write!(f, "Serialization error: {}", msg),
            Error::Other(msg) => write!(f, "Error: {}", msg),
        }
    }
}

impl From<serde_json::Error> for Error {
    fn from(e: serde_json::Error) -> Self {
        Error::SerdeError(e.to_string())
    }
}