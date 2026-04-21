#!/usr/bin/env bash
set -euo pipefail

# Upload processed CSV assets to OCI Object Storage.
# Requires OCI CLI auth configured: oci setup config

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/data"
: "${OCI_BUCKET_NAME:?Set OCI_BUCKET_NAME}"
: "${OCI_NAMESPACE:?Set OCI_NAMESPACE}"

upload_file() {
  local file_path="$1"
  if [[ -f "$file_path" ]]; then
    echo "Uploading ${file_path}"
    oci os object put \
      --namespace-name "${OCI_NAMESPACE}" \
      --bucket-name "${OCI_BUCKET_NAME}" \
      --name "$(basename "$file_path")" \
      --file "$file_path" \
      --force
  fi
}

upload_file "${DATA_DIR}/raw/paysim/PS_20174392719_1491204439457_log.csv"
upload_file "${DATA_DIR}/processed/lendingclub_5k.csv"
upload_file "${DATA_DIR}/processed/banking77_conversations.csv"
upload_file "${DATA_DIR}/raw/uci/bank-additional/bank-additional-full.csv"

echo "Upload complete."
