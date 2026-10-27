#!/usr/bin/env bash
# Shows the PostgreSQL container and whether its volume exists.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_docker
compose ps
log "Volume"
docker volume ls --filter name=event-ticketing-postgres || die "docker volume ls failed."
