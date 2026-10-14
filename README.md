# uniffi-starter

A multi-crate template for exposing Rust code to Kotlin, Swift, Python and Ruby
with [UniFFI](https://mozilla.github.io/uniffi-rs/latest/). The point of the
layout is a clean separation: your real logic stays plain Rust, and a thin
adapter crate is the only thing that knows UniFFI exists.

## Layout

```
.
├── Cargo.toml                 # workspace root; pins `uniffi` for every member
├── Makefile                   # task shortcuts (make dev, make test, …)
├── crates/
│   ├── core/                  # starter-core  — pure Rust, NO uniffi dependency
│   └── uniffi/                # starter-uniffi — #[uniffi::*] adapter, builds the cdylib
├── uniffi-bindgen/            # standalone bindgen CLI (the generator)
├── scripts/                   # build / bindings / xcframework / aar / test helpers
├── demo/                      # real consuming apps: python, swift, kotlin
├── docs/                      # exposing core types, Kotlin/JNI backend notes
├── bindings/                  # generated output (git-ignored)
└── artifacts/                 # built libraries (git-ignored)
```

Three crates, three jobs:

| Crate | Role | Depends on uniffi? |
|-------|------|--------------------|
| `starter-core` (`crates/core`) | Domain logic. Normal Rust, unit-tested on its own. | No |
| `starter-uniffi` (`crates/uniffi`) | FFI surface. Annotates/adapts core types, builds the `cdylib`/`staticlib`. | Yes |
| `uniffi-bindgen` (`uniffi-bindgen`) | Runs the generator to emit Kotlin/Swift/Python/Ruby. | Yes (`cli` feature) |

Why split core from the adapter? The core has no FFI types in it, so it builds
for any target, tests without a UniFFI runtime, and can be reused by other
front-ends. If you later drop UniFFI for something else, `starter-core` doesn't
change. The adapter is disposable glue.

## Requirements

- Rust (stable). Pinned toolchain target list is your responsibility; macOS,
  Linux and Windows hosts all work for generating bindings.
- Optional, only for the step you need:
  - iOS/macOS framework: Xcode command line tools (`xcodebuild`).
  - Kotlin formatting: `ktlint` (bindgen warns and skips if absent).
  - Ruby formatting: `rubocop` (same).
- Cross-targets for distribution: e.g. `rustup target add aarch64-apple-ios
  aarch64-apple-ios-sim x86_64-apple-darwin`.

## Quick start

```bash
make dev        # build the cdylib + generate bindings for all four languages
make test       # run the Rust test suite
make demo-python # consume the bindings from a real program (also demo-swift, demo-kotlin)
```

That produces:

```
artifacts/libstarter.dylib      # or .so / .dll, depending on host
bindings/kotlin/uniffi/starter/starter.kt
bindings/swift/starter.swift
bindings/swift/starterFFI.h
bindings/swift/starterFFI.modulemap
bindings/python/starter.py
bindings/ruby/starter.rb
```

## What the template exposes

`starter-core` provides two things, chosen to exercise the interesting pieces of
the UniFFI surface:

1. A small stateful counter — a free function (`add`) with a fallible result, a
   `Record` (`Summary`), an `Enum` with associated data (`Operation`), an
   `Object` with constructor + methods (`Counter`), and an `Error` enum
   (`StarterError`) that becomes a thrown exception.
2. **`ExportS1`** — a struct containing *every* type UniFFI can carry, so you
   have a working reference for each one:

   | Rust type | Field(s) |
   |-----------|----------|
   | `bool` | `flag` |
   | `i8 / i16 / i32 / i64` | `i8_v … i64_v` |
   | `u8 / u16 / u32 / u64` | `u8_v … u64_v` |
   | `f32 / f64` | `f32_v`, `f64_v` |
   | `String` | `text` |
   | `Vec<u8>` (bytes) | `data` |
   | `Option<T>` | `maybe`, `maybe_child` |
   | `Vec<T>` | `tags`, `children` |
   | `HashMap<String, T>` | `scores`, `by_name` |
   | `SystemTime` / `Duration` | `created_at`, `ttl` |
   | nested `Record` / `Enum` | `child`, `color` |

   `make_export_s1()` builds one in Rust; `roundtrip_export_s1()` sends one from
   the foreign side into Rust and back, so a consumer can assert parity.

Using it from Python, once the cdylib sits next to the generated file:

```python
import starter
c = starter.Counter(10)
c.apply(starter.Operation.ADD(delta=5))   # 15
print(c.summary())                         # Summary(value=15, operations=1, label='')

s = starter.make_export_s1()
print(s.text, s.scores, s.child.id, s.color)
assert starter.roundtrip_export_s1(s) == s
```

From Swift:

```swift
let c = Counter(start: 10)
_ = try c.apply(op: .add(delta: 5))        // 15
print(c.summary())

let s = makeExportS1()
print(s.text, s.scores, s.child.id, s.color)
precondition(roundtripExportS1(value: s) == s)
```

The generated bindings are identical in shape to any hand-written UniFFI
project; nothing here is bespoke.

For a runnable consumer of each of these, see [`demo/`](demo/README.md).

## How core types reach the foreign languages

`starter-core` is UniFFI-free, but `ExportS1`, `Child` and `Color` are core
types that still need to cross the boundary. UniFFI's derives require a
`UniFfiTag` that only `setup_scaffolding!()` defines, so they **cannot** be
applied inside the core crate.

The adapter therefore declares each type with `#[uniffi::remote(...)]` and
aliases the name to the real core type:

```rust
// crates/uniffi/src/export.rs
type Child = starter_core::Child;

#[uniffi::remote(Record)]
pub struct Child { pub id: u32, pub label: String }
```

`remote` emits metadata only — it does not define a new Rust type — so values
cross the boundary as the identical `starter_core` type with **no conversion
code**, and the bindings stay in a single namespace.

Three rules, each verified experimentally:

- The remote block's fields must match the core struct **exactly** (a missing
  field is a compile error, not a runtime surprise).
- `setup_scaffolding!()` must be called in **exactly one** crate. Calling it in
  the core too yields two namespaces / two generated modules; forcing the same
  namespace name yields a duplicate-symbol link error.
- Custom types (`custom_newtype!`) need a *local* type, so they can't wrap a
  foreign core type as-is.

The full write-up, including the failed alternatives and their exact error
messages, is in [`docs/EXPOSING_CORE_TYPES.md`](docs/EXPOSING_CORE_TYPES.md).

## Adding your own API

1. Put the real implementation in `crates/core`. Keep it plain Rust.
2. Expose it from the adapter — either restate a core type with
   `#[uniffi::remote]` (as above), or derive UniFFI types directly for
   adapter-owned types:

   ```rust
   #[derive(uniffi::Record)]  pub struct MyRecord { /* fields */ }
   #[derive(uniffi::Enum)]    pub enum MyEnum { A, B { x: i32 } }
   #[derive(uniffi::Error, thiserror::Error)] pub enum MyError { /* variants */ }

   #[uniffi::export]
   impl MyObject {
       #[uniffi::constructor]
       pub fn new() -> Arc<Self> { /* … */ }
       pub fn do_thing(&self) -> Result<String, MyError> { /* … */ }
   }

   #[uniffi::export]
   pub fn top_level(x: i32) -> String { /* … */ }
   ```
3. `make dev` to rebuild and regenerate.

Conventions worth keeping:

- **Objects are shared via `Arc`.** Their methods take `&self`, so use a
  `Mutex`/`RwLock` (as `Counter` does) for interior mutability rather than
  `&mut self`, which UniFFI cannot call through an `Arc`.
- **Keep conversions total and trivial.** One FFI type maps to exactly one core
  type; no logic in the adapter beyond mapping and error translation.
- The `uniffi` namespace comes from the crate name (`starter`), and
  `uniffi::setup_scaffolding!()` is called once, at the top of the adapter lib.

## Scripts

Run through `make`, or invoke directly. All scripts accept `--debug`/`--release`
where a profile matters.

| Command | What it does |
|---------|--------------|
| `scripts/dev.sh` | Build + generate all bindings. |
| `scripts/build.sh [--target T]` | Build the cdylib for host or target `T`; copies it to `artifacts/`. |
| `scripts/generate-bindings.sh [langs…]` | Generate bindings; e.g. `… kotlin swift`. Reads from `artifacts/` by default. |
| `scripts/build-xcframework.sh` | Build iOS/macOS static libs and assemble an `.xcframework` (needs Xcode). |
| `scripts/build-aar.sh` | Assemble an Android `.aar` (Kotlin bindings → `classes.jar` + `jni/<abi>/libstarter.so`). |
| `scripts/test.sh [crate]` | `cargo test` for the workspace, or one crate. |
| `scripts/check-version.sh` | Assert the runtime and generator agree on the uniffi version. |

`make` targets mirror these: `make dev`, `make test`, `make xcframework`,
`make aar`, and `make demo-python` / `demo-swift` / `demo-kotlin`.

Bindings are generated with the library mode — the docs' recommended path:

```bash
cargo run -p uniffi-bindgen -- generate \
  --library artifacts/libstarter.dylib \
  --language kotlin \
  --out-dir bindings/kotlin
```

`generate-bindings.sh` wraps exactly that. The reason to prefer `--library`
over the legacy UDL mode is that it reads the compiled artifact directly, so
what you generate is guaranteed to match what you built.

## Distribution notes

- **Kotlin/Android**: `scripts/build-aar.sh` compiles the generated `.kt` into
  `classes.jar`, drops `libstarter.so` under `jni/<abi>/`, and zips a valid AAR
  (`AndroidManifest.xml` + `R.txt` + those). Ship it alongside the JNA runtime.
- **Kotlin/JNI**: the alternative JNI backend avoids JNA but is experimental
  and only available from the `uniffi-rs` git repo (not crates.io). See
  [`docs/KOTLIN_JNI_BACKEND.md`](docs/KOTLIN_JNI_BACKEND.md) for the wiring and
  trade-offs.
- **Swift/iOS**: static libs per architecture assembled into an `.xcframework`
  via `scripts/build-xcframework.sh`, with the generated `.swift` and
  `.h`/`.modulemap` added to the Xcode target.
- **Python/Ruby**: the generated module loads the cdylib from its own
  directory, so ship the library alongside the `.py`/`.rb` file.

## Version discipline

UniFFI refuses to load a library whose runtime version doesn't match what the
bindings were generated with. The workspace pins a single `uniffi` version in
the root `Cargo.toml` and every member inherits it (`uniffi.workspace = true`),
so mismatches can only come from a stale lockfile. If you hit one:

```bash
cargo update -p uniffi
scripts/check-version.sh
```

## More

- [UniFFI user guide](https://mozilla.github.io/uniffi-rs/latest/)
- [Foreign language bindings](https://mozilla.github.io/uniffi-rs/latest/tutorial/foreign_language_bindings.html)
- [Proc-macros reference](https://mozilla.github.io/uniffi-rs/latest/proc_macro/index.html)
