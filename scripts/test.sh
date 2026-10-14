#!/usr/bin/env bash
# Run the Rust test suite (core logic + adapter).
#
# Usage:
#   scripts/test.sh                 # whole workspace
#   scripts/test.sh starter-core    # a single crate

set -euo pipefail
. "$(dirname "$0")/common.sh"

require_cmd cargo

if [ $# -gt 0 ]; then
  info "cargo test -p $1"
  cargo test -p "$1"
else
  info "cargo test (workspace)"
  cargo test --workspace
fi
ok "tests passed"
