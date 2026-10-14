#!/usr/bin/env bash
# Generate foreign-language bindings from the built cdylib.
#
# Usage:
#   scripts/generate-bindings.sh                     # all languages, host lib
#   scripts/generate-bindings.sh kotlin swift        # selected languages
#   scripts/generate-bindings.sh --lib artifacts/libstarter.dylib python
#   LANGUAGE=kotlin scripts/generate-bindings.sh
#
# Bindings are written to ./bindings/<language>/.

set -euo pipefail
. "$(dirname "$0")/common.sh"

ALL_LANGUAGES=(kotlin swift python ruby)
LIB=""
LANGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --lib)     LIB="$2"; shift ;;
    --lib=*)   LIB="${1#*=}" ;;
    --out-dir) OUT_DIR="$2"; shift ;;
    --out-dir=*) OUT_DIR="${1#*=}" ;;
    --release) PROFILE="release" ;;
    --debug)   PROFILE="debug" ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    kotlin|swift|python|ruby) LANGS+=("$1") ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done

require_cmd cargo

# Default language list.
if [ "${#LANGS[@]}" -eq 0 ]; then
  if [ -n "${LANGUAGE:-}" ]; then
    LANGS=("$LANGUAGE")
  else
    LANGS=("${ALL_LANGUAGES[@]}")
  fi
fi

# Locate the library to read. Prefer an explicit --lib, else ./artifacts, else
# the raw cargo output.
if [ -z "$LIB" ]; then
  CANDIDATE="${ARTIFACTS_DIR}/$(lib_file_name "$(host_target)")"
  if [ -f "$CANDIDATE" ]; then
    LIB="$CANDIDATE"
  else
    LIB="$(target_dir_for "")/$(lib_file_name "$(host_target)")"
    [ -f "$LIB" ] || die "no built library found. Run scripts/build.sh first."
  fi
fi
[ -f "$LIB" ] || die "library not found: ${LIB}"

info "Generating bindings from ${LIB#"${ROOT_DIR}/"}"

for lang in "${LANGS[@]}"; do
  DEST="${OUT_DIR}/${lang}"
  mkdir -p "$DEST"
  printf "${C_BLUE}==>${C_RESET} %s -> %s\n" "$lang" "${DEST#"${ROOT_DIR}/"}"
  cargo run -q -p uniffi-bindgen -- generate \
    --library "$LIB" \
    --language "$lang" \
    --out-dir "$DEST"
  ok "${lang} bindings written"
done
