#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RAW_DIR="${ROOT_DIR}/data/raw"
mkdir -p "${RAW_DIR}" "${ROOT_DIR}/data/processed"

# PaySim
echo "Downloading PaySim..."
kaggle datasets download -d ealaxi/paysim1 -p "${RAW_DIR}/paysim" --unzip

# LendingClub
echo "Downloading LendingClub..."
kaggle datasets download -d wordsforthewise/lending-club -p "${RAW_DIR}/lendingclub" --unzip

# Banking77
echo "Downloading Banking77..."
kaggle datasets download -d hwassner/banking77 -p "${RAW_DIR}/banking77" --unzip

# UCI Bank Marketing
echo "Downloading UCI Bank Marketing..."
mkdir -p "${RAW_DIR}/uci"
curl -L "https://archive.ics.uci.edu/static/public/222/bank+marketing.zip" -o "${RAW_DIR}/uci/bank_marketing.zip"
unzip -o "${RAW_DIR}/uci/bank_marketing.zip" -d "${RAW_DIR}/uci"

echo "Download complete. Run scripts/02_trim_lending.py next."
