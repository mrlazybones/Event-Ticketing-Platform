#!/usr/bin/env bash
# Stops PostgreSQL. The named volume is kept, so the data remains.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_docker
compose stop
log "PostgreSQL is stopped. The volume event-ticketing-postgres was kept."
