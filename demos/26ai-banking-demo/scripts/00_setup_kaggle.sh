#!/usr/bin/env bash
set -euo pipefail

# Installs Kaggle CLI and validates ~/.kaggle/kaggle.json permissions.
python3 -m pip install --upgrade pip
python3 -m pip install kaggle

echo "Ensure Kaggle API key exists at ~/.kaggle/kaggle.json"
echo "1) Create API token in Kaggle account settings"
echo "2) Save to ~/.kaggle/kaggle.json"
echo "3) Run: chmod 600 ~/.kaggle/kaggle.json"

if [[ -f "${HOME}/.kaggle/kaggle.json" ]]; then
  chmod 600 "${HOME}/.kaggle/kaggle.json"
  echo "kaggle.json found and permissions set to 600"
else
  echo "WARNING: ${HOME}/.kaggle/kaggle.json not found"
fi
