// Demo: consume the generated Swift bindings for `starter`.
//
// Build a framework-free binary with swiftc (see demo/swift/build.sh), or drop
// `bindings/swift/*` plus the cdylib into an Xcode target.
//
// The generated module is `starter` (from starter.swift); `starterFFI` is the
// C header module (starterFFI.h + starterFFI.modulemap).

import Foundation

print("library version: \(version())")
print("add(2, 3) = \(try add(a: 2, b: 3))")

// --- stateful object ---------------------------------------------------------
let counter = Counter(start: 10)
_ = try counter.apply(op: .add(delta: 5))
counter.setLabel(label: "demo")
let summary = counter.summary()
print("counter: \(summary.value) after \(summary.operations) op, label=\(summary.label)")

// --- error mapping -----------------------------------------------------------
do {
    _ = try counter.divide(divisor: 0)
} catch StarterError.DivisionByZero {
    print("divide(0) raised DivisionByZero (as expected)")
} catch {
    print("unexpected error: \(error)")
}

// --- ExportS1: every supported type, both directions -------------------------
let s = makeExportS1()
print("\nExportS1 from Rust:")
print("  flag=\(s.flag) i64=\(s.i64V) u64=\(s.u64V) f64=\(s.f64V)")
print("  text=\(s.text) data=\(Array(s.data)) tags=\(s.tags)")
print("  scores=\(s.scores) createdAt=\(s.createdAt) ttl=\(s.ttl)")
print("  child=(\(s.child.id), \(s.child.label)) color=\(s.color)")
print("  children=\(s.children.map { ($0.id, $0.label) })")
print("  maybeChild=\(s.maybeChild.map { $0.id } as Any)")

let echoed = roundtripExportS1(value: s)
precondition(echoed == s, "round-trip mismatch!")
print("  round-trip: OK")
