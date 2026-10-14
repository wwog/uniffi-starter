#!/usr/bin/env bash
# Build the UniFFI cdylib for the current host (or a given Rust target) and
# copy it into ./artifacts/ so bindgen can consume a stable path.
#
# Usage:
#   scripts/build.sh                 # host, release
#   scripts/build.sh --debug         # host, debug
#   scripts/build.sh --target aarch64-apple-ios
#   PROFILE=release scripts/build.sh

set -euo pipefail
. "$(dirname "$0")/common.sh"

TARGET=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --debug)   PROFILE="debug" ;;
    --release) PROFILE="release" ;;
    --target)  TARGET="$2"; shift ;;
    --target=*) TARGET="${1#*=}" ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

require_cmd cargo
if [ -n "$TARGET" ]; then
  require_target "$TARGET"
fi

info "Building ${ADAPTER_CRATE} (profile=${PROFILE}${TARGET:+, target=${TARGET}})"

CARGO_ARGS=(-p "$ADAPTER_CRATE")
if [ "$PROFILE" = "release" ]; then
  CARGO_ARGS+=(--release)
fi
if [ -n "$TARGET" ]; then
  CARGO_ARGS+=(--target "$TARGET")
fi
CARGO_ARGS+=("${ARGS[@]+"${ARGS[@]}"}")

cargo build "${CARGO_ARGS[@]}"

BUILD_DIR="$(target_dir_for "$TARGET")"
LIB="$(lib_file_name "${TARGET:-$(host_target)}")"
SRC="${BUILD_DIR}/${LIB}"
[ -f "$SRC" ] || die "built library not found at ${SRC}"

mkdir -p "$ARTIFACTS_DIR"
DEST="${ARTIFACTS_DIR}/${LIB}${TARGET:+.$TARGET}"
cp -f "$SRC" "$DEST"
ok "cdylib -> ${DEST#"${ROOT_DIR}/"}"
