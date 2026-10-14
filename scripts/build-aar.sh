#!/usr/bin/env bash
# Assemble an Android AAR from the generated Kotlin bindings + the Rust cdylib.
#
# The AAR layout produced:
#
#   <name>.aar
#   ├── AndroidManifest.xml
#   ├── classes.jar                       # compiled Kotlin bindings
#   ├── R.txt                             # empty (no Android resources)
#   └── jni/<abi>/libstarter.so           # one shared library per ABI
#
# Usage:
#   scripts/build-aar.sh                          # build .so via cargo-ndk (needs NDK)
#   scripts/build-aar.sh --libs-dir DIR           # use prebuilt .so (DIR/<abi>/libstarter.so)
#   scripts/build-aar.sh --abis arm64-v8a,x86_64  # restrict ABIs
#
# Requires: kotlinc, a JDK (for `jar`), zip, and — unless --libs-dir is given —
# cargo-ndk plus an Android NDK.

set -euo pipefail
. "$(dirname "$0")/common.sh"

AAR_NAME="${LIB_NAME}"
ABIS="arm64-v8a,armeabi-v7a,x86_64,x86"
LIBS_DIR=""
ANDROID_MIN_SDK="${ANDROID_MIN_SDK:-24}"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)      AAR_NAME="$2"; shift ;;
    --name=*)    AAR_NAME="${1#*=}" ;;
    --abis)      ABIS="$2"; shift ;;
    --abis=*)    ABIS="${1#*=}" ;;
    --libs-dir)  LIBS_DIR="$2"; shift ;;
    --libs-dir=*) LIBS_DIR="${1#*=}" ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
  shift
done
IFS=',' read -r -a ABI_LIST <<<"$ABIS"

require_cmd kotlinc
require_cmd zip

# JDK: kotlinc ships one, but `jar` may not be on PATH.
if ! command -v jar >/dev/null 2>&1; then
  for cand in \
    /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    [ -x "${cand}/bin/jar" ] && export PATH="${cand}/bin:${PATH}" && break
  done
fi
require_cmd jar

# --- Map Android ABI -> Rust target ------------------------------------------
rust_target_for_abi() {
  case "$1" in
    arm64-v8a)   echo "aarch64-linux-android" ;;
    armeabi-v7a) echo "armv7-linux-androideabi" ;;
    x86)         echo "i686-linux-android" ;;
    x86_64)      echo "x86_64-linux-android" ;;
    *) die "unknown ABI: $1" ;;
  esac
}

# --- 1. Build the shared libraries -------------------------------------------
SO_DIR="${ARTIFACTS_DIR}/aar-jni"
rm -rf "$SO_DIR"; mkdir -p "$SO_DIR"

if [ -n "$LIBS_DIR" ]; then
  info "using prebuilt libraries from ${LIBS_DIR}"
  for abi in "${ABI_LIST[@]}"; do
    src="${LIBS_DIR}/${abi}/lib${LIB_NAME}.so"
    [ -f "$src" ] || die "missing ${src}"
    mkdir -p "${SO_DIR}/${abi}"
    cp -f "$src" "${SO_DIR}/${abi}/lib${LIB_NAME}.so"
    ok "${abi} <- ${src}"
  done
else
  require_cmd cargo-ndk
  command -v cargo-ndk >/dev/null || die "cargo-ndk not found.
  Install it with 'cargo install cargo-ndk' and set ANDROID_NDK_HOME.
  Or pass --libs-dir with prebuilt ./<abi>/lib${LIB_NAME}.so files."
  [ -n "${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}" ] || \
    warn "ANDROID_NDK_HOME is not set — cargo-ndk may fail to locate the NDK"

  info "building .so via cargo-ndk for ABIs: ${ABIS}"
  # cargo-ndk rebuilds per ABI; collect the outputs into $SO_DIR.
  for abi in "${ABI_LIST[@]}"; do
    target="$(rust_target_for_abi "$abi")"
    require_target "$target"
    cargo ndk -t "$abi" -o "$SO_DIR" build -p "$ADAPTER_CRATE" --release
    ok "built ${abi}"
  done
fi

# --- 2. Compile the Kotlin bindings into classes.jar --------------------------
KOTLIN_BINDINGS="${OUT_DIR}/kotlin"
[ -f "${KOTLIN_BINDINGS}/uniffi/${NAMESPACE}/${NAMESPACE}.kt" ] || \
  die "run 'make bindings' (or make dev) first — no Kotlin bindings at ${KOTLIN_BINDINGS}"

JNA_JAR="${JNA_JAR:-${ARTIFACTS_DIR}/jna-${JNA_VERSION:-5.14.0}.jar}"
if [ ! -f "$JNA_JAR" ]; then
  JNA_VERSION="${JNA_VERSION:-5.14.0}"
  JNA_JAR="${ARTIFACTS_DIR}/jna-${JNA_VERSION}.jar"
  info "downloading JNA ${JNA_VERSION} (needed to compile the bindings)"
  curl -fsSL -o "$JNA_JAR" \
    "https://repo1.maven.org/maven2/net/java/dev/jna/jna/${JNA_VERSION}/jna-${JNA_VERSION}.jar"
fi

STAGE="${ARTIFACTS_DIR}/aar-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE/jni"
CLASSES_JAR="${STAGE}/classes.jar"

info "compiling Kotlin bindings"
kotlinc \
  "${KOTLIN_BINDINGS}/uniffi/${NAMESPACE}/${NAMESPACE}.kt" \
  -classpath "$JNA_JAR" \
  -d "$CLASSES_JAR"

# --- 3. Assemble the AAR -----------------------------------------------------
cp -R "$SO_DIR"/* "$STAGE/jni/" 2>/dev/null || true

cat > "${STAGE}/AndroidManifest.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="uniffi.${NAMESPACE}">
    <uses-sdk android:minSdkVersion="${ANDROID_MIN_SDK}" />
</manifest>
EOF

# R.txt is expected by AGP even when empty.
: > "${STAGE}/R.txt"

AAR_PATH="${ARTIFACTS_DIR}/${AAR_NAME}.aar"
rm -f "$AAR_PATH"
info "packaging ${AAR_PATH#"${ROOT_DIR}/"}"
( cd "$STAGE" && zip -q -r "$AAR_PATH" AndroidManifest.xml classes.jar R.txt jni )

ok "AAR -> ${AAR_PATH#"${ROOT_DIR}/"} ($(du -h "$AAR_PATH" | cut -f1))"
echo
echo "AAR contents:"
unzip -l "$AAR_PATH" | sed -n '4,$p' | head -20
echo
echo "Add to your Android app:"
echo "  implementation files('libs/${AAR_NAME}.aar')"
echo "  implementation 'net.java.dev.jna:jna:5.14.0@aar'   # JNA runtime"
