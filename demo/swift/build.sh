#!/usr/bin/env bash
# Build and run the Swift demo against the generated bindings.
#
#   make dev                 # generate bindings + cdylib first
#   demo/swift/build.sh      # then this
#
# Compiles demo/swift/main.swift together with bindings/swift/starter.swift,
# linking the cdylib from artifacts/.

set -euo pipefail
. "$(dirname "$0")/../../scripts/common.sh"

require_cmd swiftc

LIBDIR="${ROOT_DIR}/artifacts"
SWIFT_BINDINGS="${OUT_DIR}/swift"
[ -f "${SWIFT_BINDINGS}/starter.swift" ] || die "run 'make dev' first (no Swift bindings)"
[ -f "${LIBDIR}/$(lib_file_name "$(host_target)")" ] || die "run 'make dev' first (no cdylib)"

BIN="${ROOT_DIR}/artifacts/demo-swift"
info "compiling Swift demo"
swiftc -O \
  -I "${SWIFT_BINDINGS}" \
  -L "${LIBDIR}" -l"${LIB_NAME}" \
  -Xcc -fmodule-map-file="${SWIFT_BINDINGS}/starterFFI.modulemap" \
  -o "${BIN}" \
  "${SWIFT_BINDINGS}/starter.swift" \
  "${ROOT_DIR}/demo/swift/main.swift"

info "running"
DYLD_LIBRARY_PATH="${LIBDIR}" "${BIN}"
