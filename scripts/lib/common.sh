# Shared helpers for the scripts in this directory. Source this file; do not execute it.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly ROOT_DIR
cd "${ROOT_DIR}"

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# Sets JAVA_CMD to the java executable that the Maven Wrapper uses as well.
require_java() {
  if [[ -n "${JAVA_HOME:-}" ]]; then
    JAVA_CMD="${JAVA_HOME}/bin/java"
    [[ -x "${JAVA_CMD}" ]] || die "JAVA_HOME is '${JAVA_HOME}', but ${JAVA_CMD} does not exist. Point JAVA_HOME to a JDK 21+ installation."
  elif command -v java >/dev/null 2>&1; then
    JAVA_CMD="$(command -v java)"
  else
    die "Java was not found. Install JDK 21 or newer, then set JAVA_HOME or add java to PATH."
  fi
}

run_maven() {
  local wrapper="${ROOT_DIR}/mvnw"
  [[ -f "${wrapper}" ]] || die "Maven Wrapper not found at ${wrapper}."
  log "./mvnw $*"
  if [[ -x "${wrapper}" ]]; then
    "${wrapper}" "$@"
  else
    warn "mvnw is not executable, so it is run with sh. Fix it with: chmod +x mvnw scripts/*.sh"
    sh "${wrapper}" "$@"
  fi
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker was not found. Install Docker, start it, and retry."
  docker compose version >/dev/null 2>&1 || die "The Docker Compose plugin is not available. Use 'docker compose', which comes with Docker Desktop."
  docker info >/dev/null 2>&1 || die "Docker is installed but the engine is not running. Start Docker and retry."
}

compose() {
  log "docker compose $*"
  docker compose "$@" || die "docker compose $* failed."
}

wait_for_postgres() {
  local timeout="${DB_READY_TIMEOUT_SECONDS:-60}"
  local deadline=$((SECONDS + timeout))
  local id="" status=""
  log "Waiting up to ${timeout}s for the PostgreSQL health check"
  while ((SECONDS < deadline)); do
    id="$(docker compose ps -q postgres 2>/dev/null | head -n 1 || true)"
    if [[ -n "${id}" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}")"
      if [[ "${status}" == "healthy" ]]; then
        return 0
      fi
      if [[ "${status}" == "unhealthy" ]]; then
        die "PostgreSQL is unhealthy. Run scripts/db-logs.sh"
      fi
    fi
    sleep 2
  done
  die "PostgreSQL did not become healthy within ${timeout}s. Run scripts/db-logs.sh"
}

load_dotenv() {
  local env_file="${ROOT_DIR}/.env"
  [[ -f "${env_file}" ]] || return 0
  log "Loading environment variables from .env"
  set -a
  # shellcheck source=/dev/null
  source "${env_file}"
  set +a
}
