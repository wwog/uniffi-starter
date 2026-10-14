//! Exposing `starter-core` types to the foreign languages.
//!
//! ## The layering problem
//!
//! `starter-core` is intentionally UniFFI-free, but we still want its structs
//! (`ExportS1`, `Child`, `Color`) to cross the FFI boundary. UniFFI's derives
//! need a `UniFfiTag` that only `setup_scaffolding!` defines, so they cannot be
//! used in a crate that does not itself call `setup_scaffolding!`.
//!
//! ## The chosen pattern: `#[uniffi::remote]`
//!
//! We restate each type here with `#[uniffi::remote(...)]`, and alias the name
//! to the *real* core type with `type X = starter_core::X;`. The remote
//! declaration is metadata only — it does **not** define a new Rust type, so
//! values pass across the boundary as the very same `starter_core` type with no
//! conversion code.
//!
//! Rules that matter (each one learned the hard way, see
//! `docs/EXPOSING_CORE_TYPES.md`):
//!   * The remote block's **fields must match the core struct exactly** —
//!     a missing/extra/renamed field fails to compile.
//!   * The `type` alias must be in scope, or `remote` cannot find the type.
//!   * Only *one* crate may call `setup_scaffolding!` (the adapter). Calling it
//!     in `starter-core` too would emit a second namespace and split the
//!     generated bindings into two modules.

use starter_core::ExportS1;

// --- The real core types, brought into scope under their own names ----------
type Child = starter_core::Child;
type Color = starter_core::Color;

/// Mirrors [`starter_core::Child`].
#[uniffi::remote(Record)]
pub struct Child {
    pub id: u32,
    pub label: String,
}

/// Mirrors [`starter_core::Color`].
#[uniffi::remote(Enum)]
pub enum Color {
    Red,
    Green,
    Blue { shade: u8 },
}

/// Mirrors [`starter_core::ExportS1`] — every UniFFI-supported type.
#[uniffi::remote(Record)]
pub struct ExportS1 {
    pub flag: bool,

    pub i8_v: i8,
    pub i16_v: i16,
    pub i32_v: i32,
    pub i64_v: i64,

    pub u8_v: u8,
    pub u16_v: u16,
    pub u32_v: u32,
    pub u64_v: u64,

    pub f32_v: f32,
    pub f64_v: f64,

    pub text: String,
    pub data: Vec<u8>,

    pub maybe: Option<String>,
    pub tags: Vec<String>,
    pub scores: std::collections::HashMap<String, i64>,

    pub created_at: std::time::SystemTime,
    pub ttl: std::time::Duration,

    pub child: Child,
    pub color: Color,

    pub children: Vec<Child>,
    pub by_name: std::collections::HashMap<String, Child>,
    pub maybe_child: Option<Child>,
}

/// Build a fully-populated [`ExportS1`] in Rust and hand it to the foreign side.
#[uniffi::export]
pub fn make_export_s1() -> ExportS1 {
    starter_core::ExportS1::sample()
}

/// Send an [`ExportS1`] from the foreign side into Rust and get it back. This is
/// the cheapest way for a consumer app to prove the whole struct survives the
/// trip field-for-field.
#[uniffi::export]
pub fn roundtrip_export_s1(value: ExportS1) -> ExportS1 {
    value.touch()
}
