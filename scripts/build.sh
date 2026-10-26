#!/usr/bin/env bash
# Compiles and packages all modules. Tests are compiled but not run; use test.sh or verify.sh for that.
#
# Usage: scripts/build.sh [extra Maven arguments]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_java

log "Compiling and packaging all modules (tests are compiled but not run)"
run_maven clean package -DskipTests "$@" || die "Build failed. See the Maven output above."

log "Build succeeded. Executable JAR: booking-api/target/booking-api-*.jar"
