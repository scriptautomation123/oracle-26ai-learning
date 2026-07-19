#!/usr/bin/env bash
set -euo pipefail

# Creates/reuses .venv in the demo root, ensures pip exists and is upgraded,
# and installs requirements.txt only when its hash has changed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENV_DIR="${DEMO_ROOT}/.venv"
REQ_FILE="${DEMO_ROOT}/requirements.txt"
REQ_HASH_FILE="${VENV_DIR}/.requirements.sha256"
IS_SOURCED=0

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  IS_SOURCED=1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "Creating virtual environment at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
if [[ "${VIRTUAL_ENV:-}" != "${VENV_DIR}" ]]; then
  source "${VENV_DIR}/bin/activate"
  echo "Activated virtual environment: ${VENV_DIR}"
else
  echo "Virtual environment already active: ${VENV_DIR}"
fi

if ! python -m pip --version >/dev/null 2>&1; then
  echo "pip not found in venv, bootstrapping with ensurepip"
  python -m ensurepip --upgrade
fi

echo "Upgrading pip in venv"
python -m pip install --upgrade pip

if [[ ! -f "${REQ_FILE}" ]]; then
  echo "requirements.txt not found at ${REQ_FILE}; skipping dependency install"
  exit 0
fi

if command -v sha256sum >/dev/null 2>&1; then
  CURRENT_HASH="$(sha256sum "${REQ_FILE}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  CURRENT_HASH="$(shasum -a 256 "${REQ_FILE}" | awk '{print $1}')"
else
  echo "No SHA-256 tool found (sha256sum/shasum). Installing requirements unconditionally."
  python -m pip install -r "${REQ_FILE}"
  exit 0
fi

if [[ -f "${REQ_HASH_FILE}" ]]; then
  PREV_HASH="$(cat "${REQ_HASH_FILE}")"
else
  PREV_HASH=""
fi

if [[ "${CURRENT_HASH}" == "${PREV_HASH}" ]]; then
  echo "requirements.txt already installed for this venv (hash unchanged)."
else
  echo "Installing dependencies from requirements.txt"
  python -m pip install -r "${REQ_FILE}"
  echo "${CURRENT_HASH}" > "${REQ_HASH_FILE}"
  echo "Dependency install complete; recorded requirements hash."
fi

if [[ "${IS_SOURCED}" -eq 0 ]]; then
  echo "Note: run 'source scripts/00_setup_venv.sh' to keep .venv active in your current shell."
fi
