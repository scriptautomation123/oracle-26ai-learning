#!/usr/bin/env bash
set -euo pipefail

require_demo_venv() {
  local script_dir demo_root expected_venv
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  demo_root="$(cd "${script_dir}/../.." && pwd)"
  expected_venv="${demo_root}/.venv"

  if [[ "${VIRTUAL_ENV:-}" != "${expected_venv}" ]]; then
    echo "ERROR: Expected active virtual environment at ${expected_venv}."
    echo "Run this first from demo root: source scripts/00_setup_venv.sh"
    exit 1
  fi

  if ! command -v python >/dev/null 2>&1; then
    echo "ERROR: python is not available in the active environment."
    echo "Run this first from demo root: source scripts/00_setup_venv.sh"
    exit 1
  fi
}
