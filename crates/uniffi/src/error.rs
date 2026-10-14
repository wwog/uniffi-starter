use starter_core::Error as CoreError;

/// FFI-visible error type.
///
/// UniFFI maps this onto a thrown exception in Kotlin/Java, a `throws` error in
/// Swift, and an exception in Python/Ruby. Variants stay simple (repr-style)
/// because foreign languages have to reconstruct them from a serialised form.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum StarterError {
    #[error("integer overflow computing {lhs} + {rhs}")]
    Overflow { lhs: i64, rhs: i64 },

    #[error("cannot divide by zero")]
    DivisionByZero,
}

impl From<CoreError> for StarterError {
    fn from(e: CoreError) -> Self {
        match e {
            CoreError::Overflow { lhs, rhs } => StarterError::Overflow { lhs, rhs },
            CoreError::DivisionByZero => StarterError::DivisionByZero,
        }
    }
}
