#!/usr/bin/env bash
# Shared configuration and helpers for the build scripts.
# Source this file from the other scripts: `. "$(dirname "$0")/common.sh"`

set -euo pipefail

# --- Resolve paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Project configuration ---------------------------------------------------
# The name of the UniFFI adapter crate (the one that builds the cdylib).
ADAPTER_CRATE="starter-uniffi"
# The `[lib] name` from that crate — determines the on-disk library name.
LIB_NAME="starter"
# The UniFFI namespace baked into the generated bindings.
NAMESPACE="starter"

PROFILE="${PROFILE:-release}"
OUT_DIR="${ROOT_DIR}/bindings"
ARTIFACTS_DIR="${ROOT_DIR}/artifacts"

# --- Pretty logging ----------------------------------------------------------
if [ -t 1 ]; then
  C_RESET='\033[0m'; C_BLUE='\033[1;34m'; C_GREEN='\033[1;32m'; C_RED='\033[1;31m'; C_YELLOW='\033[1;33m'
else
  C_RESET=''; C_BLUE=''; C_GREEN=''; C_RED=''; C_YELLOW=''
fi
info()  { printf "${C_BLUE}==>${C_RESET} %s\n" "$*"; }
ok()    { printf "${C_GREEN}ok${C_RESET}  %s\n" "$*"; }
warn()  { printf "${C_YELLOW}warn${C_RESET} %s\n" "$*" >&2; }
die()   { printf "${C_RED}error${C_RESET} %s\n" "$*" >&2; exit 1; }

# --- Helpers -----------------------------------------------------------------
# Map a Rust target triple to the cdylib file name (host or cross).
lib_file_name() {
  local target="$1"
  case "$target" in
    *-apple-darwin) echo "lib${LIB_NAME}.dylib" ;;
    *-apple-ios*)   echo "lib${LIB_NAME}.a" ;;
    *-linux-*)      echo "lib${LIB_NAME}.so" ;;
    *-windows-*)    echo "${LIB_NAME}.dll" ;;
    *)              echo "lib${LIB_NAME}.so" ;;
  esac
}

host_target() {
  rustc -vV | awk '/^host:/ {print $2}'
}

# Directory cargo puts build output in for a given target.
target_dir_for() {
  local target="$1"
  if [ -z "$target" ] || [ "$target" = "$(host_target)" ]; then
    echo "${ROOT_DIR}/target/${PROFILE}"
  else
    echo "${ROOT_DIR}/target/${target}/${PROFILE}"
  fi
}

require_target() {
  local target="$1"
  if ! rustup target list --installed 2>/dev/null | grep -qx "$target"; then
    die "Rust target '${target}' is not installed. Install it with:
    rustup target add ${target}"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
