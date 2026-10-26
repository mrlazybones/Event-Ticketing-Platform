#!/usr/bin/env bash
# Full verification pipeline:
#   1. ./mvnw clean verify - Maven Enforcer rules, compilation with warnings treated as errors,
#      all tests and packaging.
#   2. Smoke test - starts the packaged JAR and checks that /api/v1/health reports UP.
#
# Usage:       scripts/verify.sh [extra Maven arguments]
# Environment: SMOKE_TEST_PORT (default 18080), SMOKE_TEST_TIMEOUT_SECONDS (default 60)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SMOKE_TEST_PORT="${SMOKE_TEST_PORT:-18080}"
SMOKE_TEST_TIMEOUT_SECONDS="${SMOKE_TEST_TIMEOUT_SECONDS:-60}"
APP_PID=""

stop_app() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" 2>/dev/null; then
    kill "${APP_PID}" 2>/dev/null || true
    wait "${APP_PID}" 2>/dev/null || true
  fi
  APP_PID=""
}

smoke_test() {
  local jars=(booking-api/target/booking-api-*.jar)
  local jar="${jars[0]}"
  [[ -f "${jar}" ]] || die "No executable JAR found in booking-api/target. Did the package phase run?"

  local log_file="booking-api/target/smoke-test.log"
  local url="http://localhost:${SMOKE_TEST_PORT}/api/v1/health"
  local deadline=$((SECONDS + SMOKE_TEST_TIMEOUT_SECONDS))
  local body

  log "Starting ${jar} on port ${SMOKE_TEST_PORT} (log: ${log_file})"
  "${JAVA_CMD}" -jar "${jar}" --server.port="${SMOKE_TEST_PORT}" >"${log_file}" 2>&1 &
  APP_PID=$!
  trap stop_app EXIT

  until body="$(curl --silent --fail --max-time 2 "${url}")"; do
    if ! kill -0 "${APP_PID}" 2>/dev/null; then
      tail -n 40 "${log_file}" >&2 || true
      die "The application exited before it became healthy. Full log: ${log_file}"
    fi
    if ((SECONDS >= deadline)); then
      tail -n 40 "${log_file}" >&2 || true
      die "No response from ${url} within ${SMOKE_TEST_TIMEOUT_SECONDS}s. Is port ${SMOKE_TEST_PORT} free? Override it with SMOKE_TEST_PORT."
    fi
    sleep 1
  done

  [[ "${body}" == *'"status":"UP"'* ]] || die "Unexpected response from ${url}: ${body}"
  log "Health endpoint responded: ${body}"
  stop_app
}

require_java
command -v curl >/dev/null 2>&1 || die "curl is required for the smoke test. Install curl and retry."

log "Step 1/2: Maven verify (enforcer rules, compilation, tests, packaging)"
run_maven clean verify "$@" || die "Maven verification failed. See the output above."

log "Step 2/2: Smoke test of the packaged application"
smoke_test

log "Verification succeeded."
