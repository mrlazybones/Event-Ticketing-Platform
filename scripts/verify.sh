#!/usr/bin/env bash
# Full verification pipeline:
#   1. ./mvnw clean verify - enforcer rules, compilation, database-independent tests,
#      PostgreSQL integration tests (unless -DskipITs is passed) and packaging.
#   2. Smoke test - when PostgreSQL accepts a TCP connection, starts the packaged JAR and checks
#      /api/v1/health and /api/v1/health/readiness.
#
# Usage:       scripts/verify.sh [extra Maven arguments]
# Environment: SMOKE_TEST_PORT (default 18080), SMOKE_TEST_TIMEOUT_SECONDS (default 60),
#              DATABASE_CHECKS=skipped to run only the database-free part and say so.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

SMOKE_TEST_PORT="${SMOKE_TEST_PORT:-18080}"
SMOKE_TEST_TIMEOUT_SECONDS="${SMOKE_TEST_TIMEOUT_SECONDS:-60}"
APP_PID=""
SKIP_ITS=false

stop_app() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" 2>/dev/null; then
    kill "${APP_PID}" 2>/dev/null || true
    wait "${APP_PID}" 2>/dev/null || true
  fi
  APP_PID=""
}

database_endpoint() {
  local url="${DB_URL:-jdbc:postgresql://localhost:5432/event_ticketing}"
  if [[ ! "${url}" =~ ^jdbc:postgresql://([^/:?#]+)(:([0-9]+))?/ ]]; then
    die "DB_URL is not a PostgreSQL JDBC URL: ${url}"
  fi
  DB_HOST="${BASH_REMATCH[1]}"
  DB_PORT="${BASH_REMATCH[3]:-5432}"
}

# Returns 0 when a TCP connection succeeds within about two seconds. Uses bash only, so it also
# works in Git Bash, where the Windows timeout.exe would not stop a hung connection attempt.
database_reachable() {
  local host="$1" port="$2" attempt=0 pid=""
  (echo >/dev/tcp/"${host}"/"${port}") >/dev/null 2>&1 &
  pid=$!
  while ((attempt < 10)); do
    if ! kill -0 "${pid}" 2>/dev/null; then
      # wait's non-zero status must not abort the script under set -e.
      wait "${pid}" && return 0
      return 1
    fi
    sleep 0.2
    attempt=$((attempt + 1))
  done
  kill "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true
  return 1
}

smoke_test() {
  local jars=(booking-api/target/booking-api-*.jar)
  local jar="${jars[0]}"
  [[ -f "${jar}" ]] || die "No executable JAR found in booking-api/target. Did the package phase run?"

  local log_file="booking-api/target/smoke-test.log"
  local liveness="http://localhost:${SMOKE_TEST_PORT}/api/v1/health"
  local readiness="http://localhost:${SMOKE_TEST_PORT}/api/v1/health/readiness"
  local deadline=$((SECONDS + SMOKE_TEST_TIMEOUT_SECONDS))
  local body ready_body ready_code

  log "Starting ${jar} on port ${SMOKE_TEST_PORT} (log: ${log_file})"
  "${JAVA_CMD}" -jar "${jar}" --server.port="${SMOKE_TEST_PORT}" >"${log_file}" 2>&1 &
  APP_PID=$!
  trap stop_app EXIT

  until body="$(curl --silent --fail --max-time 2 "${liveness}")"; do
    if ! kill -0 "${APP_PID}" 2>/dev/null; then
      tail -n 40 "${log_file}" >&2 || true
      die "The application exited before it became healthy. Full log: ${log_file}"
    fi
    if ((SECONDS >= deadline)); then
      tail -n 40 "${log_file}" >&2 || true
      die "No response from ${liveness} within ${SMOKE_TEST_TIMEOUT_SECONDS}s. Is port ${SMOKE_TEST_PORT} free? Override it with SMOKE_TEST_PORT."
    fi
    sleep 1
  done
  [[ "${body}" == *'"status":"UP"'* ]] || die "Unexpected response from ${liveness}: ${body}"
  log "Liveness responded: ${body}"

  ready_code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 "${readiness}")"
  ready_body="$(curl --silent --max-time 5 "${readiness}")"
  [[ "${ready_code}" == "200" && "${ready_body}" == *'"status":"UP"'* ]] \
    || die "Database readiness check failed: HTTP ${ready_code} ${ready_body}"
  log "Readiness responded: ${ready_body}"
  stop_app
}

for argument in "$@"; do
  if [[ "${argument}" == "-DskipITs" || "${argument}" == "-DskipITs=true" ]]; then
    SKIP_ITS=true
  fi
done

require_java
command -v curl >/dev/null 2>&1 || die "curl is required for the smoke test. Install curl and retry."
load_dotenv

log "Step 1/2: Maven verify (enforcer rules, compilation, tests, packaging)"
run_maven clean verify "$@" || die "Maven verification failed. See the output above."

if [[ "${DATABASE_CHECKS:-}" == "skipped" ]]; then
  log "PostgreSQL integration tests and the packaged-JAR smoke test were not run (DATABASE_CHECKS=skipped). The Linux CI job runs them against PostgreSQL."
  exit 0
fi

database_endpoint
log "Step 2/2: Smoke test when PostgreSQL accepts connections at ${DB_HOST}:${DB_PORT}"
if database_reachable "${DB_HOST}" "${DB_PORT}"; then
  smoke_test
elif [[ "${SKIP_ITS}" == "true" ]]; then
  die "NOT VERIFIED: PostgreSQL is not reachable at ${DB_HOST}:${DB_PORT}, and integration tests were skipped."
else
  log "PostgreSQL is not reachable at ${DB_HOST}:${DB_PORT}. The packaged JAR was not started. Connectivity was verified by the Testcontainers integration tests."
fi

log "Verification succeeded."
