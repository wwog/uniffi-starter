# Kotlin backends: JNA (default) vs JNI (experimental)

UniFFI can generate two different kinds of Kotlin bindings. This template uses
the **JNA** backend by default; this note explains when and how to switch to the
**JNI** backend, and what to know about it.

## JNA backend (what `make dev` produces)

`uniffi-bindgen generate --library ... --language kotlin` emits a single
`starter.kt` that talks to the Rust library through
[JNA](https://github.com/java-native-access/jna). It is the stable, documented
default.

- **Runtime dependency:** `net.java.dev.jna:jna` (the demo downloads the jar;
  Android apps add `net.java.dev.jna:jna:5.x@aar`). See `demo/kotlin/run.sh`.
- **Library loading:** JNA resolves the `starter` library from
  `jna.library.path` (desktop) or the app's `jniLibs` (Android). No code change.
- **Packaging:** `scripts/build-aar.sh` compiles `starter.kt` into `classes.jar`
  and drops `libstarter.so` under `jni/<abi>/`.
- **Objects:** exported as `open class`es implementing `Disposable` /
  `AutoCloseable`, so you can free them deterministically as well as via the GC.

## JNI backend (experimental)

The JNI backend generates Kotlin that calls back into Rust's own JNI bridge — no
JNA at runtime, smaller and faster at the call boundary, and objects are freed by
normal GC (no `Disposable`). It is marked **experimental** and lives *only in the
`uniffi-rs` git repository*: `uniffi-bindgen-kotlin-jni` is **not published to
crates.io** (verified against the crates.io index for 0.32.x). You must depend on
it by git tag.

### Wiring it up

```toml
# a crate that builds the shared library (your adapter)
[dependencies]
uniffi-bindgen-kotlin-jni-runtime = { git = "https://github.com/mozilla/uniffi-rs", tag = "v0.32.2" }

[build-dependencies]
uniffi-bindgen-kotlin-jni = { git = "https://github.com/mozilla/uniffi-rs", tag = "v0.32.2" }
```

```rust
// build.rs
fn main() {
    uniffi_bindgen_kotlin_jni::generate_scaffolding();
}
```

```rust
// lib.rs — include the generated JNI scaffolding
include!(concat!(env!("OUT_DIR"), "/uniffi_bindgen_kotlin_jni.uniffi.rs"));
```

Bindgen binary:

```toml
[dependencies]
uniffi-bindgen-kotlin-jni = { git = "https://github.com/mozilla/uniffi-rs", tag = "v0.32.2" }
```

```rust
fn main() { uniffi_bindgen_kotlin_jni::main() }
```

Generate with the `bindings` subcommand (note: different from
`uniffi-bindgen generate`):

```bash
cargo run -p <bindgen-crate> bindings src:<top-level-lib-crate> bindings/kotlin
```

### Constraints (from the backend's README)

- Every exported item must be `pub` **and publicly reachable**.
- The top-level library crate must directly depend on every UniFFI crate and on
  `uniffi-bindgen-kotlin-jni-runtime`.
- Records/enums holding objects no longer implement `Disposable`; objects are
  freed by the GC.
- UDL is only semi-supported.

### Why this template doesn't wire it in by default

Two reasons, both practical:

1. **Availability.** It is git-only, so a normal `cargo build` needs network
   access to `github.com` (git protocol). This repo pins `uniffi` from
   crates.io so the template builds everywhere offline.
2. **Stability.** It is explicitly experimental; the generated API surface and
   the scaffolding requirements still change between releases.

If you want the JNI backend, add it as an **optional** dependency behind a
feature (e.g. a `kotlin-jni` feature on the adapter, plus a second bindgen
binary) so the default build stays on the stable JNA path. The wiring above is
the full recipe.

## Which should I pick?

| | JNA | JNI |
|---|-----|-----|
| Availability | crates.io (`uniffi` `cli` feature) | git tag only |
| Stability | stable | experimental |
| Runtime dep | `net.java.dev.jna:jna` | none |
| Object lifetime | `Disposable` + GC | GC only |
| Call overhead | higher (JNA marshalling) | lower (direct JNI) |
| Recommended for | most projects, this template | perf-sensitive Kotlin-only apps that accept the churn |
