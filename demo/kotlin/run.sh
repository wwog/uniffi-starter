#!/usr/bin/env bash
# Build and run the Kotlin demo WITHOUT Gradle, using kotlinc + a JNA jar.
#
#   make dev                                   # generate bindings + cdylib
#   demo/kotlin/run.sh                         # compiles & runs
#   JNA_JAR=/path/to/jna.jar demo/kotlin/run.sh
#
# Requires kotlinc on PATH (e.g. `brew install kotlin`). JNA is downloaded to
# artifacts/ if JNA_JAR is not set.

set -euo pipefail
. "$(dirname "$0")/../../scripts/common.sh"

require_cmd kotlinc

# `java` is often not usable even when a `java` binary exists: macOS ships a
# /usr/bin/java stub that fails until a JDK is installed, and Homebrew's openjdk
# is keg-only (not on PATH). Test that `java` actually runs, else fall back to
# JAVA_HOME / common install locations.
if ! java -version >/dev/null 2>&1; then
  if [ -z "${JAVA_HOME:-}" ]; then
    for cand in \
      /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
      /usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
      [ -x "${cand}/bin/java" ] && JAVA_HOME="$cand" && break
    done
  fi
  [ -n "${JAVA_HOME:-}" ] && export PATH="${JAVA_HOME}/bin:${PATH}"
fi
java -version >/dev/null 2>&1 || die "no working Java runtime found; install a JDK (e.g. 'brew install openjdk')"

LIBDIR="${ROOT_DIR}/artifacts"
KOTLIN_BINDINGS="${OUT_DIR}/kotlin"
[ -f "${KOTLIN_BINDINGS}/uniffi/starter/starter.kt" ] || die "run 'make dev' first (no Kotlin bindings)"
[ -f "${LIBDIR}/$(lib_file_name "$(host_target)")" ] || die "run 'make dev' first (no cdylib)"

# --- JNA ---------------------------------------------------------------------
JNA_VERSION="${JNA_VERSION:-5.14.0}"
JNA_JAR="${JNA_JAR:-${LIBDIR}/jna-${JNA_VERSION}.jar}"
if [ ! -f "$JNA_JAR" ]; then
  info "downloading JNA ${JNA_VERSION}"
  curl -fsSL -o "$JNA_JAR" \
    "https://repo1.maven.org/maven2/net/java/dev/jna/jna/${JNA_VERSION}/jna-${JNA_VERSION}.jar"
fi

OUT_JAR="${ARTIFACTS_DIR}/demo-kotlin.jar"
WORK="${ARTIFACTS_DIR}/kotlin-demo-classes"
rm -rf "$WORK"; mkdir -p "$WORK"

info "compiling Kotlin bindings + demo"
# Compile the generated bindings and the demo together. `-include-runtime` bakes
# the Kotlin stdlib into the jar so a plain `java -jar` works.
kotlinc \
  "${KOTLIN_BINDINGS}/uniffi/starter/starter.kt" \
  "${ROOT_DIR}/demo/kotlin/main.kt" \
  -classpath "$JNA_JAR" \
  -include-runtime \
  -d "$OUT_JAR"

info "running (jna.library.path=${LIBDIR})"
# `-jar` ignores -cp, so put both the demo jar and JNA on the classpath
# explicitly. Kotlin stdlib is already baked into the demo jar (-include-runtime).
java -Djna.library.path="$LIBDIR" -cp "${OUT_JAR}:${JNA_JAR}" demo.MainKt
