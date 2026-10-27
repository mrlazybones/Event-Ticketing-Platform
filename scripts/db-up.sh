#!/usr/bin/env bash
# Starts PostgreSQL with Docker Compose and waits until its health check passes.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_docker
compose up -d
wait_for_postgres
log "PostgreSQL is healthy. From the host, the app uses jdbc:postgresql://localhost:<DB_HOST_PORT>/<DB_NAME> (defaults: localhost:5432/event_ticketing)."
