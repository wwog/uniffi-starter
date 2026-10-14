# Exposing `starter-core` types to the foreign languages

This document answers two questions with results from experiments run against
UniFFI **0.32.2**:

1. **Can `starter-core` use the UniFFI proc-macros directly?**
2. **What is the best practice for exporting a core struct like `ExportS1`?**

Short version: no, the core cannot derive UniFFI types on its own, and the
pattern that keeps the layering clean is `#[uniffi::remote]` restatement in the
adapter. Everything below is the evidence.

---

## 1. Can the core use `#[derive(uniffi::Record)]` directly?

**No.** UniFFI's derives expand to code referencing a `UniFfiTag` type that is
only defined by `uniffi::setup_scaffolding!()`. A crate that doesn't call that
macro — which is exactly the point of a UniFFI-free core — fails to compile:

```
error[E0425]: cannot find type `UniFfiTag` in the crate root
 --> core/src/lib.rs:2:10
  |
2 | #[derive(uniffi::Record)]
  |          ^^^^^^^^^^^^^^ not found in the crate root
```

That leaves the obvious follow-up: *then call `setup_scaffolding!()` in the core
too.* Three variants were tested, and all have problems.

### Variant A — only the core calls `setup_scaffolding!`

Compiles, but the adapter's own types then have nowhere to register; in practice
you need the scaffolding in the crate that builds the cdylib.

### Variant B — both crates call `setup_scaffolding!()` (default namespace)

Compiles, but UniFFI treats each `setup_scaffolding!` as a **separate
namespace**, so binding generation emits **two modules**:

```
bindings/python/exp_core.py
bindings/python/expadapter.py
```

For a consumer that is confusing: `ExportS1` lives in one module, the functions
that use it in another. It works, but it leaks your internal crate split into
the public API surface.

### Variant C — both crates call `setup_scaffolding!("same_name")`

The worst case: the scaffolding metadata symbol collides.

```
warning: duplicate symbol '_UNIFFI_META_NAMESPACE_EXP'
...
Unknown namespace for Record(...) (exp_core)
```

The generator cannot resolve which namespace the type belongs to. Do not do
this.

### Conclusion

`setup_scaffolding!()` must be called in **exactly one** crate — the adapter
that builds the cdylib. The core stays macro-free.

---

## 2. Best practice: `#[uniffi::remote]` restatement

The adapter restates each core type and aliases the name to the real type:

```rust
// crates/uniffi/src/export.rs
use starter_core::ExportS1;

type Child = starter_core::Child;
type Color = starter_core::Color;

#[uniffi::remote(Record)]
pub struct Child { pub id: u32, pub label: String }

#[uniffi::remote(Enum)]
pub enum Color { Red, Green, Blue { shade: u8 } }

#[uniffi::remote(Record)]
pub struct ExportS1 { /* every field, same names + types */ }
```

Why this is the right default here:

- **The core stays UniFFI-free.** No `uniffi` dependency, no macros, unit-tests
  without an FFI runtime. This is the whole reason the crate exists.
- **No conversion code.** `remote` declares metadata only; it does not define a
  new type. A value crosses the boundary as the identical `starter_core` type,
  so there is no struct-to-struct copying to keep in sync.
- **One namespace.** Only the adapter calls `setup_scaffolding!`, so you get a
  single generated module.
- **Cheap to verify.** A `roundtrip_export_s1` function proves the whole struct
  survives field-for-field (see below).

### The catch: the restatement must match exactly

`remote` is a *re-declaration*, not an alias, so the compiler checks your
restatement against the real struct:

- A **missing field** → `error[E0063]: missing field 'length' in initializer`.
- A **wrong type** → a normal type mismatch.
- A **forgotten `type` alias** → `cannot find struct ... in this scope`.

So core and adapter have to be edited together when a field changes. That cost
is the price of not coupling the core to UniFFI, and it is a compile-time error
rather than a runtime surprise.

### When to reach for the alternatives instead

| Situation | Use |
|-----------|-----|
| You control the type and it's fine for it to know about UniFFI | Derive `uniffi::Record`/`Enum` on it directly in the crate that calls `setup_scaffolding!` |
| Types live in a crate you don't own, or a shared "external types" crate | Official **external types** support: the defining crate calls `setup_scaffolding!` and derives; consumers import the types and the generator emits cross-referencing modules (this is the `bindgen-tests/external-types` pattern in the UniFFI repo) |
| A brand-new domain type with custom lowering | Derive directly (it lives in the adapter, or in a UniFFI-aware crate) |

For a *plain Rust core + FFI adapter* like this template, `remote` is the right
trade: the core stays pure and the adapter owns all FFI knowledge.

---

## 3. What `ExportS1` covers

`crates/core/src/export_s1.rs` defines a struct that includes every type UniFFI
can carry, so you have a working reference for each:

| Rust type | FFI / generated type | Field |
|-----------|----------------------|-------|
| `bool` | `Boolean` / `bool` | `flag` |
| `i8 i16 i32 i64` | signed ints | `i8_v … i64_v` |
| `u8 u16 u32 u64` | unsigned ints | `u8_v … u64_v` |
| `f32 f64` | floats | `f32_v`, `f64_v` |
| `String` | string | `text` |
| `Vec<u8>` | byte buffer (`ByteArray` / `Data`) | `data` |
| `Option<T>` | nullable / optional | `maybe`, `maybe_child` |
| `Vec<T>` | list / sequence | `tags`, `children` |
| `HashMap<String, T>` | map / dictionary | `scores`, `by_name` |
| `SystemTime` | timestamp (`Duration` for negative?) | `created_at` |
| `Duration` | duration | `ttl` |
| nested `Record` | record | `child` |
| `Enum` with data | sealed class / enum-with-payload | `color` |

Note there is **no** separate `uniffi::Bytes` marker in 0.32 — a byte buffer is
just `Vec<u8>` (or `&[u8]` / `&mut [u8]` for zero-copy parameters).

### Custom types (newtypes over builtins)

`uniffi::custom_type!` / `custom_newtype!` require the target to be a **local**
type or a type alias, because the generated trait impl is orphaned otherwise.
This fails when the adapter tries to wrap a foreign core type:

```
error[E0210]: type parameter `UT` must be used as an argument to some local type
```

So if you want a custom-typed field, define it *in the core* alongside its
UniFFI macro, or define it in the adapter. The core-side form:

```rust
// in starter-core, IF you accept a uniffi dependency there:
pub struct Meters(pub f64);
uniffi::custom_newtype!(Meters, f64);
```

In this template the core is UniFFI-free, so custom-typed fields would be
defined in the adapter (with the derive) and `remote`-restated like the rest.

---

## 4. How the exported API looks to consumers

```python
import starter

s = starter.make_export_s1()
s.flag, s.i64_v, s.u64_v, s.f64_v      # bool, -64, 64, 7.25
s.text, s.data, s.tags, s.scores       # str, bytes, list, dict
s.created_at, s.ttl                    # datetime, timedelta
s.child.id, s.color                    # nested record, enum
[(c.id, c.label) for c in s.children]  # list of records

assert starter.roundtrip_export_s1(s) == s   # full round-trip
```

```swift
let s = makeExportS1()
s.flag; s.i64V; s.u64V; s.f64V
s.text; s.data; s.tags; s.scores
s.createdAt; s.ttl
s.child.id; s.color
s.children.map { ($0.id, $0.label) }

print(roundtripExportS1(value: s) == s)      // true
```

Both were run against the built cdylib and round-trip all fields correctly.

---

## 5. Checklist for adding a new core type

1. Define the plain Rust type in `starter-core` (no macros), add a unit test.
2. Add a `type X = starter_core::X;` alias in `crates/uniffi/src/export.rs`.
3. Restate it with `#[uniffi::remote(Record)]` / `(Enum)` / `(Object)` +
   **every field exactly as declared**.
4. For objects, restate as `#[uniffi::remote(Object)] pub struct X;` (a unit
   struct) and export the methods on the adapter side.
5. `make dev` and check `bindings/` — one module, all types present.
6. Add a `roundtrip_*` function if you want the demo apps to assert parity.
