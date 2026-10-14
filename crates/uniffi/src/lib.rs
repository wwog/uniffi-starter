//! `starter-uniffi` — the UniFFI adapter layer.
//!
//! This crate contains **no business logic**. Its only job is to describe the
//! public interface with UniFFI's proc-macros and translate between the FFI
//! types and the plain types in `starter-core`.
//!
//! Layering rule of thumb:
//!   * `starter-core`  — logic, plain Rust, no FFI.
//!   * `starter-uniffi` (this crate) — `#[uniffi::*]` annotations + conversion.
//!   * `uniffi-bindgen` — generates Kotlin/Swift/Python/Ruby from this crate.
//!
//! Keep conversions thin and total: every FFI type maps to exactly one core
//! type, so the core stays testable without a UniFFI runtime.

use std::sync::{Arc, Mutex};

use starter_core::{Counter as CoreCounter, Operation as CoreOperation, Summary as CoreSummary};

mod error;
mod export;

pub use error::StarterError;
pub use export::{make_export_s1, roundtrip_export_s1};

// Namespace used by the generated bindings (Kotlin package, Swift module).
uniffi::setup_scaffolding!();

/// A snapshot of a counter's state. Records are plain value types on the FFI
/// boundary — cheap to construct, copied by value.
#[derive(Debug, Clone, uniffi::Record)]
pub struct Summary {
    pub value: i64,
    pub operations: u64,
    pub label: String,
}

impl From<CoreSummary> for Summary {
    fn from(s: CoreSummary) -> Self {
        Self {
            value: s.value,
            operations: s.operations,
            label: s.label,
        }
    }
}

/// A mutation to apply to a counter. Enums with associated data are supported
/// as-is and become sealed classes / enums with associated values in the
/// generated bindings.
#[derive(Debug, Clone, uniffi::Enum)]
pub enum Operation {
    Add { delta: i64 },
    Sub { delta: i64 },
    Reset,
}

impl From<Operation> for CoreOperation {
    fn from(op: Operation) -> Self {
        match op {
            Operation::Add { delta } => CoreOperation::Add(delta),
            Operation::Sub { delta } => CoreOperation::Sub(delta),
            Operation::Reset => CoreOperation::Reset,
        }
    }
}

/// A stateful object exposed as an interface with methods.
///
/// `#[derive(uniffi::Object)]` turns this into a reference-counted handle in the
/// foreign language. Methods take `&self` (objects are shared via `Arc`), so
/// mutation goes through a `Mutex` — this is the standard UniFFI pattern for
/// stateful objects and makes them safely callable from multiple threads.
#[derive(uniffi::Object)]
pub struct Counter {
    inner: Mutex<CoreCounter>,
}

#[uniffi::export]
impl Counter {
    /// Constructor. Named after the type so bindings produce `Counter(start)`.
    #[uniffi::constructor]
    pub fn new(start: i64) -> Arc<Self> {
        Arc::new(Self {
            inner: Mutex::new(CoreCounter::new(start)),
        })
    }

    pub fn value(&self) -> i64 {
        self.inner.lock().expect("counter mutex poisoned").value()
    }

    pub fn apply(&self, op: Operation) -> Result<i64, StarterError> {
        self.inner
            .lock()
            .expect("counter mutex poisoned")
            .apply(op.into())
            .map_err(Into::into)
    }

    pub fn divide(&self, divisor: i64) -> Result<i64, StarterError> {
        self.inner
            .lock()
            .expect("counter mutex poisoned")
            .divide(divisor)
            .map_err(Into::into)
    }

    pub fn set_label(&self, label: String) {
        self.inner
            .lock()
            .expect("counter mutex poisoned")
            .set_label(label);
    }

    pub fn summary(&self) -> Summary {
        self.inner
            .lock()
            .expect("counter mutex poisoned")
            .summary()
            .into()
    }
}

/// A free function (no receiver) exposed at the namespace level.
#[uniffi::export]
pub fn add(a: i64, b: i64) -> Result<i64, StarterError> {
    a.checked_add(b)
        .ok_or(StarterError::Overflow { lhs: a, rhs: b })
}

/// Expose the crate version so foreign code can assert it loaded the build it
/// expects.
#[uniffi::export]
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
