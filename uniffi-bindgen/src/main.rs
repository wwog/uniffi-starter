//! Standalone `uniffi-bindgen` binary.
//!
//! Having this as its own crate (rather than a `[[bin]]` inside the adapter
//! crate) means the FFI library is not polluted with a CLI entry point and the
//! generator can run even when the adapter crate is built for a foreign target.
//!
//! Usage (from the workspace root):
//!
//! ```text
//! cargo run -p uniffi-bindgen -- generate --library <path-to-cdylib> \
//!     --language kotlin --out-dir bindings/kotlin
//! ```
//!
//! The `scripts/` helpers wrap these invocations.

fn main() {
    uniffi::uniffi_bindgen_main()
}
