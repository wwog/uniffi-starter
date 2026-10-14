#!/usr/bin/env bash
# One-shot: build the cdylib and generate all bindings.
#
#   scripts/dev.sh              # release
#   scripts/dev.sh --debug
#
set -euo pipefail
DIR="$(dirname "$0")"
"$DIR/build.sh" "$@"
"$DIR/generate-bindings.sh" "$@"
