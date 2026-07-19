#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/require_venv.sh"
require_demo_venv

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

RUNTIME="${ORACLE_CONTAINER_RUNTIME:-docker}"
CONTAINER_NAME="${ORACLE_CONTAINER_NAME:-oracle-26ai-nudges}"
CONTAINER_IMAGE="${ORACLE_CONTAINER_IMAGE:-container-registry.oracle.com/database/free:latest}"
CONTAINER_PASSWORD="${ORACLE_CONTAINER_PASSWORD:-Welcome12345#}"
HOST_PORT="${ORACLE_CONTAINER_PORT:-1521}"
DB_PORT="1521"

if ! command -v "${RUNTIME}" >/dev/null 2>&1; then
  echo "ERROR: ${RUNTIME} is not installed. Set ORACLE_CONTAINER_RUNTIME=docker|podman."
  exit 1
fi

if "${RUNTIME}" ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
  STATUS=$("${RUNTIME}" inspect -f '{{.State.Status}}' "${CONTAINER_NAME}")
  if [[ "${STATUS}" != "running" ]]; then
    echo "Starting existing container ${CONTAINER_NAME}..."
    "${RUNTIME}" start "${CONTAINER_NAME}" >/dev/null
  else
    echo "Container ${CONTAINER_NAME} already running."
  fi
else
  echo "Creating and starting container ${CONTAINER_NAME} from ${CONTAINER_IMAGE}..."
  "${RUNTIME}" run -d \
    --name "${CONTAINER_NAME}" \
    -p "${HOST_PORT}:${DB_PORT}" \
    -e ORACLE_PWD="${CONTAINER_PASSWORD}" \
    -e APP_USER="${ORACLE_LOCAL_USER:-testuser}" \
    -e APP_USER_PASSWORD="${ORACLE_LOCAL_PASSWORD:-TestPass123}" \
    "${CONTAINER_IMAGE}" >/dev/null
fi

echo "Waiting for Oracle listener on localhost:${HOST_PORT}..."
for _ in $(seq 1 120); do
  if (echo >"/dev/tcp/127.0.0.1/${HOST_PORT}") >/dev/null 2>&1; then
    echo "Oracle listener is reachable."
    exit 0
  fi
  sleep 5
done

echo "ERROR: timed out waiting for container listener on port ${HOST_PORT}."
exit 1
