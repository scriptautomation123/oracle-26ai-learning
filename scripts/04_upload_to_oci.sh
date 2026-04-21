#!/usr/bin/env bash
# Usage: ./scripts/04_upload_to_oci.sh <bucket_name> [namespace] [data_dir]
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <bucket_name> [namespace] [data_dir]" >&2
  exit 1
fi

BUCKET="$1"
NAMESPACE="${2:-$(oci os ns get --query 'data' --raw-output)}"
DATA_DIR="${3:-data}"

for file in "${DATA_DIR}"/*.csv "${DATA_DIR}"/**/*.csv; do
  [[ -f "${file}" ]] || continue
  object_name="$(realpath --relative-to="${DATA_DIR}" "${file}")"
  oci os object put --namespace "${NAMESPACE}" --bucket-name "${BUCKET}" --file "${file}" --name "${object_name}" --force
  echo "Uploaded ${file} as ${object_name}"
done
