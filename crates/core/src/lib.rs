//! `starter-core` — pure Rust domain logic.
//!
//! This crate deliberately has **no** dependency on UniFFI (or any FFI layer).
//! It is a normal Rust library: usable from other Rust code, testable with
//! `cargo test -p starter-core`, and free of foreign-language concerns.
//!
//! The UniFFI-facing crate (`starter-uniffi`) is a thin adapter on top of this
//! one. Keeping the two apart means you can evolve the core without touching
//! the bindings, and you can expose the same core from more than one front-end.

mod counter;
mod error;
mod export_s1;
mod model;

pub use counter::Counter;
pub use error::Error;
pub use export_s1::{Child, Color, ExportS1};
pub use model::{Operation, Summary};
