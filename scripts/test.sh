#!/usr/bin/env bash
# Runs the automated tests of every module.
#
# Usage:   scripts/test.sh [extra Maven arguments]
# Example: scripts/test.sh -Dtest=HealthControllerTest -Dsurefire.failIfNoSpecifiedTests=false
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_java

log "Running all automated tests"
run_maven test "$@" || die "Tests failed. See the Maven output above and the reports in */target/surefire-reports/."

log "All tests passed."
