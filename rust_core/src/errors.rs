// src/errors.rs
#[derive(Debug)]
pub enum Error {
    NullOrEmptyInput,
    SerdeError(String),
    Other(String),
}

impl From<serde_json::Error> for Error {
    fn from(e: serde_json::Error) -> Self {
        Error::SerdeError(e.to_string())
    }
}
