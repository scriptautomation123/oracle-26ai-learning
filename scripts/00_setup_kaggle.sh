#!/usr/bin/env bash
# Usage: ./scripts/00_setup_kaggle.sh /absolute/path/to/kaggle.json
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

python3 -m pip install --user --upgrade pip kaggle

KAGGLE_JSON_PATH="${1:-}"
if [[ -z "${KAGGLE_JSON_PATH}" ]]; then
  echo "Provide kaggle.json path as first argument." >&2
  exit 1
fi

mkdir -p "${HOME}/.kaggle"
cp "${KAGGLE_JSON_PATH}" "${HOME}/.kaggle/kaggle.json"
chmod 600 "${HOME}/.kaggle/kaggle.json"

echo "Kaggle CLI configured at ${HOME}/.kaggle/kaggle.json"
