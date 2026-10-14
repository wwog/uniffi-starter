#!/usr/bin/env python3
"""Demo: consume the generated Python bindings for `starter`.

Run after `make dev` (Linux/macOS):

    python3 demo/python/main.py

On macOS the generated module loads `libstarter.dylib` from its own directory,
so this script copies the built artifact next to it automatically. On Linux the
same applies with `.so`.
"""
from __future__ import annotations

import importlib
import os
import platform
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BINDINGS = ROOT / "bindings" / "python"
ARTIFACTS = ROOT / "artifacts"


def lib_filename() -> str:
    system = platform.system()
    if system == "Darwin":
        return "libstarter.dylib"
    if system == "Windows":
        return "starter.dll"
    return "libstarter.so"


def ensure_native_lib() -> None:
    """Copy the cdylib next to the generated module, where it is expected."""
    target = BINDINGS / lib_filename()
    source = ARTIFACTS / lib_filename()
    if target.exists():
        return
    if not source.exists():
        sys.exit(
            f"missing {source}. Build it first:\n    make dev"
        )
    shutil.copy2(source, target)


def main() -> None:
    ensure_native_lib()
    sys.path.insert(0, str(BINDINGS))
    starter = importlib.import_module("starter")

    print(f"library version: {starter.version()}")
    print(f"add(2, 3) = {starter.add(2, 3)}")

    # --- stateful object -----------------------------------------------------
    counter = starter.Counter(10)
    counter.apply(starter.Operation.ADD(delta=5))
    counter.set_label("demo")
    summary = counter.summary()
    print(f"counter: {summary.value} after {summary.operations} op, label={summary.label!r}")

    # --- error mapping -------------------------------------------------------
    try:
        counter.divide(0)
    except starter.StarterError.DivisionByZero:
        print("divide(0) raised DivisionByZero (as expected)")
    except Exception as exc:  # noqa: BLE001 - demo only
        print(f"unexpected error: {exc!r}")

    # --- ExportS1: every supported type, both directions ---------------------
    s = starter.make_export_s1()
    print("\nExportS1 from Rust:")
    print(f"  flag={s.flag} i64={s.i64_v} u64={s.u64_v} f64={s.f64_v}")
    print(f"  text={s.text!r} data={s.data} tags={s.tags}")
    print(f"  scores={s.scores} created_at={s.created_at} ttl={s.ttl}")
    print(f"  child=({s.child.id}, {s.child.label!r}) color={s.color}")
    print(f"  children={[(c.id, c.label) for c in s.children]}")
    print(f"  maybe_child={s.maybe_child.id if s.maybe_child else None}")

    echoed = starter.roundtrip_export_s1(s)
    assert echoed == s, "round-trip mismatch!"
    print("  round-trip: OK")


if __name__ == "__main__":
    main()
