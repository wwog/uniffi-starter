#!/usr/bin/env bash
# Report the UniFFI version the workspace resolves to, and warn if the runtime
# used by `starter-uniffi` differs from the one used by `uniffi-bindgen`. A
# mismatch shows up as a panic when the generated bindings load.
#
#   scripts/check-version.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"

require_cmd cargo

# Resolved version baked into the adapter cdylib.
RUNTIME_VER="$(cargo tree -p starter-uniffi -i uniffi --depth 0 2>/dev/null \
  | sed -n 's/^uniffi v\([0-9.]*\).*/\1/p' | head -1)"
# Resolved version used by the bindgen CLI.
BINDGEN_VER="$(cargo tree -p uniffi-bindgen -i uniffi --depth 0 2>/dev/null \
  | sed -n 's/^uniffi v\([0-9.]*\).*/\1/p' | head -1)"

echo "runtime (starter-uniffi): ${RUNTIME_VER:-unknown}"
echo "bindgen (uniffi-bindgen): ${BINDGEN_VER:-unknown}"

if [ -n "$RUNTIME_VER" ] && [ "$RUNTIME_VER" = "$BINDGEN_VER" ]; then
  ok "versions match"
else
  die "version mismatch — align the 'uniffi' pin in the workspace Cargo.toml"
fi
