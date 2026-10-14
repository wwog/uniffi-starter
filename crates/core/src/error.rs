use thiserror::Error;

/// Errors returned by the core domain logic.
///
/// This is a plain Rust error type. The UniFFI adapter crate maps each variant
/// onto a UniFFI `#[derive(uniffi::Error)]` equivalent.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum Error {
    #[error("integer overflow computing {lhs} + {rhs}")]
    Overflow { lhs: i64, rhs: i64 },

    #[error("cannot divide by zero")]
    DivisionByZero,
}
