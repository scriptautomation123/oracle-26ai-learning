#!/usr/bin/env bash
# Usage: ./scripts/01_download_all.sh [output_dir]
set -euo pipefail

OUT_DIR="${1:-data/raw}"
mkdir -p "${OUT_DIR}"/{paysim,lendingclub,banking77,uci_marketing}

kaggle datasets download -d ealaxi/paysim1 -p "${OUT_DIR}/paysim" --unzip
kaggle datasets download -d wordsforthewise/lending-club -p "${OUT_DIR}/lendingclub" --unzip
kaggle datasets download -d hwassner/banking77 -p "${OUT_DIR}/banking77" --unzip

curl -L "https://archive.ics.uci.edu/static/public/222/bank+marketing.zip" -o "${OUT_DIR}/uci_marketing/bank_marketing.zip"
unzip -o "${OUT_DIR}/uci_marketing/bank_marketing.zip" -d "${OUT_DIR}/uci_marketing"

echo "Downloaded datasets into ${OUT_DIR}"
