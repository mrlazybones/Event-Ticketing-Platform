#!/usr/bin/env bash
# Deletes the local PostgreSQL container and its volume. This erases the database.
# Refuses to run unless --yes is passed. Normal stop (db-down.sh) does not delete data.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

if [[ "${1:-}" != "--yes" ]]; then
  die "Refusing to delete the database volume. Re-run with --yes only when you mean to erase local data: scripts/db-reset.sh --yes"
fi

require_docker
compose down -v
log "PostgreSQL container and volume event-ticketing-postgres were deleted."
