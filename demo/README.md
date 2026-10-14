# Demos — actually consuming the bindings

These projects are real consumers of the generated bindings, not just the
`.rs`/`.kt` files sitting in `bindings/`. Each one calls into the Rust library
and asserts `ExportS1` survives a full round-trip.

Run `make dev` first (or any of the per-language setup below) so `bindings/`
and `artifacts/libstarter.*` exist.

| Demo | Command | Needs |
|------|---------|-------|
| Python | `python3 demo/python/main.py` | Python 3.8+ |
| Swift  | `demo/swift/build.sh` | Xcode / `swiftc` |
| Kotlin | `demo/kotlin/run.sh` | `kotlinc` (+ JDK, JNA auto-downloaded) |

## Python

`demo/python/main.py` copies `artifacts/libstarter.{dylib,so,dll}` next to the
generated `starter.py` (the module loads the cdylib from its own directory),
then exercises the free functions, the `Counter` object, error mapping, and
`ExportS1`.

```
$ python3 demo/python/main.py
library version: 0.1.0
add(2, 3) = 5
counter: 15 after 1 op, label='demo'
divide(0) raised DivisionByZero (as expected)

ExportS1 from Rust:
  flag=True i64=-64 u64=64 f64=7.25
  ...
  round-trip: OK
```

## Swift

`demo/swift/build.sh` compiles `bindings/swift/starter.swift` plus
`demo/swift/main.swift` into a standalone binary and runs it with the cdylib on
`DYLD_LIBRARY_PATH`.

```
$ demo/swift/build.sh
library version: 0.1.0
...
  round-trip: OK
```

For an Xcode app, add `bindings/swift/*` and the `.xcframework` from
`scripts/build-xcframework.sh` to your target instead.

## Kotlin

Two options share the same `demo/kotlin/main.kt`:

- **No Gradle:** `demo/kotlin/run.sh` compiles the generated `starter.kt` and
  the demo with `kotlinc`, downloads JNA, and runs with
  `-Djna.library.path=artifacts`. This is what the table above runs.
- **Gradle (Android/JVM app):** see the snippet at the bottom of
  `demo/kotlin/run.sh` — the binding uses JNA, so you need
  `net.java.dev.jna:jna` on the classpath and the cdylib in `jna.library.path`
  (desktop) or packaged as an `.so` (Android; use `scripts/build-aar.sh`).

One Kotlin-specific gotcha the demo handles for you: `data class` equality on a
`ByteArray` field (`data`) is *reference* equality, so `echoed == s` is false
even when every byte matches. Compare `data` with `contentEquals` and the rest
field-by-field, as `main.kt` does.

## What the demos prove

- Free functions, a stateful `Object` with a constructor and methods, and
  fallible methods (errors surface as native exceptions) all work.
- `ExportS1` — bool, every integer width, floats, string, bytes, optional,
  list, map, `SystemTime`/`Duration`, nested records/enums, and collections of
  records — crosses the FFI boundary intact in both directions.
