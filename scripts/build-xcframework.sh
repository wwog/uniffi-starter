#!/usr/bin/env bash
# Build an iOS/macOS XCFramework from the cdylib's static libs and drop the
# Swift bindings next to it. Requires Xcode command line tools.
#
# Usage:
#   scripts/build-xcframework.sh
#   scripts/build-xcframework.sh --targets aarch64-apple-ios,aarch64-apple-ios-sim
#
# Output: ./artifacts/${LIB_NAME}.xcframework + ./bindings/swift/

set -euo pipefail
. "$(dirname "$0")/common.sh"

require_cmd xcodebuild
require_cmd rustup

TARGETS_STR="aarch64-apple-ios,aarch64-apple-ios-sim,aarch64-apple-darwin,x86_64-apple-darwin"
while [ $# -gt 0 ]; do
  case "$1" in
    --targets)   TARGETS_STR="$2"; shift ;;
    --targets=*) TARGETS_STR="${1#*=}" ;;
    -h|--help)   sed -n '2,10p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done
IFS=',' read -r -a TARGETS <<<"$TARGETS_STR"

PROFILE="release"
mkdir -p "$ARTIFACTS_DIR"

# 1. Build the static library for each target (iOS needs a static lib).
LIBS=()
for target in "${TARGETS[@]}"; do
  require_target "$target"
  info "Building for ${target}"
  cargo build -p "$ADAPTER_CRATE" --release --target "$target"
  built="$(target_dir_for "$target")/lib${LIB_NAME}.a"
  [ -f "$built" ] || die "static library not found: $built
  Add \`staticlib\` to the adapter crate's crate-type to build for iOS."
  LIBS+=("$built")
done

# 2. Generate Swift bindings from whichever built library is on the host.
HOST_LIB="$(target_dir_for "")/$(lib_file_name "$(host_target)")"
if [ -f "$HOST_LIB" ]; then
  mkdir -p "${OUT_DIR}/swift"
  cargo run -q -p uniffi-bindgen -- generate \
    --library "$HOST_LIB" --language swift --out-dir "${OUT_DIR}/swift"
fi

# 3. Assemble the XCFramework with xcodebuild -create-xcframework.
XCF_ARGS=()
for lib in "${LIBS[@]}"; do
  XCF_ARGS+=(-library "$lib")
done
XCF_PATH="${ARTIFACTS_DIR}/${LIB_NAME}.xcframework"
rm -rf "$XCF_PATH"
xcodebuild -create-xcframework "${XCF_ARGS[@]}" -output "$XCF_PATH"
ok "xcframework -> ${XCF_PATH#"${ROOT_DIR}/"}"
