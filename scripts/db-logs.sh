#!/usr/bin/env bash
# Prints the recent PostgreSQL logs. Pass --follow to keep streaming them.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_docker
if [[ "${1:-}" == "--follow" ]]; then
  compose logs -f postgres
else
  compose logs --tail 100 postgres
fi
