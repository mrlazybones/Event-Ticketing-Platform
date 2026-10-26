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

load_dotenv() {
  local env_file="${ROOT_DIR}/.env"
  [[ -f "${env_file}" ]] || return 0
  log "Loading environment variables from .env"
  set -a
  # shellcheck source=/dev/null
  source "${env_file}"
  set +a
}
