#!/usr/bin/env bash
# Starts booking-api locally through the Maven Wrapper (spring-boot:run, default profile "dev").
#
# Usage:   scripts/dev.sh [extra Maven arguments]
# Example: scripts/dev.sh -Dspring-boot.run.arguments=--server.port=9090
#
# Variables in a .env file at the repository root (see .env.example) are exported first.
# Spring Boot does not read .env itself. DB_URL, DB_USERNAME and DB_PASSWORD are picked up
# because application-dev.yml refers to them.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_java
load_dotenv

log "Starting booking-api (Ctrl+C stops it)"
log "Liveness:  http://localhost:${SERVER_PORT:-8080}/api/v1/health"
log "Readiness: http://localhost:${SERVER_PORT:-8080}/api/v1/health/readiness"
status=0
run_maven -pl booking-api -am spring-boot:run "$@" || status=$?

case "${status}" in
  0 | 130 | 143) log "booking-api stopped." ;;
  *) die "booking-api failed to start or stopped with an error (exit code ${status}). See the output above." ;;
esac
