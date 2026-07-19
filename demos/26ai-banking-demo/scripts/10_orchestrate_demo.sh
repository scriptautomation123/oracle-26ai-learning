#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
SQL_DIR="${ROOT_DIR}/sql"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/require_venv.sh"
require_demo_venv

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

usage() {
  cat <<'EOF'
Oracle 26ai Banking Demo Orchestrator

Usage:
  10_orchestrate_demo.sh [options]

Options:
  --mode cloud|container         Deployment mode (defaults to ORACLE_DEPLOYMENT or cloud)
  --stage data|upload|container|sql-core|sql-uc|all
                                 Stage to run (default: all)
  --sql-client auto|sql|sqlplus  SQL client for SQL execution (default: auto)
  --skip-kaggle-setup            Skip scripts/00_setup_kaggle.sh
  --skip-download                Skip scripts/01_download_all.sh
  --skip-upload                  Skip scripts/04_upload_to_oci.sh
  --connect user/password@dsn    Explicit DB connect string override
  -h, --help                     Show this help

Environment variables:
  ORACLE_DEPLOYMENT=cloud|container
  ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN
  ORACLE_LOCAL_USER, ORACLE_LOCAL_PASSWORD, ORACLE_LOCAL_DSN
  TNS_ADMIN

Examples:
  ./scripts/10_orchestrate_demo.sh --mode cloud --stage all
  ./scripts/10_orchestrate_demo.sh --mode container --stage sql-core
  ./scripts/10_orchestrate_demo.sh --mode cloud --stage sql-uc --connect ADMIN/Secret@mydb_high
EOF
}

MODE="${ORACLE_DEPLOYMENT:-cloud}"
STAGE="all"
SQL_CLIENT="auto"
SKIP_KAGGLE_SETUP="false"
SKIP_DOWNLOAD="false"
SKIP_UPLOAD="false"
CONNECT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --stage)
      STAGE="${2:-}"
      shift 2
      ;;
    --sql-client)
      SQL_CLIENT="${2:-}"
      shift 2
      ;;
    --skip-kaggle-setup)
      SKIP_KAGGLE_SETUP="true"
      shift
      ;;
    --skip-download)
      SKIP_DOWNLOAD="true"
      shift
      ;;
    --skip-upload)
      SKIP_UPLOAD="true"
      shift
      ;;
    --connect)
      CONNECT_OVERRIDE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "${MODE}" != "cloud" && "${MODE}" != "container" ]]; then
  echo "ERROR: --mode must be cloud or container."
  exit 1
fi

build_connect_string() {
  if [[ -n "${CONNECT_OVERRIDE}" ]]; then
    echo "${CONNECT_OVERRIDE}"
    return
  fi

  if [[ "${MODE}" == "cloud" ]]; then
    if [[ -z "${ORACLE_USER:-}" || -z "${ORACLE_PASSWORD:-}" || -z "${ORACLE_DSN:-}" ]]; then
      echo "ERROR: cloud mode requires ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN." >&2
      exit 1
    fi
    echo "${ORACLE_USER}/${ORACLE_PASSWORD}@${ORACLE_DSN}"
  else
    local u="${ORACLE_LOCAL_USER:-testuser}"
    local p="${ORACLE_LOCAL_PASSWORD:-TestPass123}"
    local d="${ORACLE_LOCAL_DSN:-localhost:1521/FREEPDB1}"
    echo "${u}/${p}@${d}"
  fi
}

run_data_stage() {
  if [[ "${SKIP_KAGGLE_SETUP}" != "true" ]]; then
    "${SCRIPTS_DIR}/00_setup_kaggle.sh"
  fi
  if [[ "${SKIP_DOWNLOAD}" != "true" ]]; then
    "${SCRIPTS_DIR}/01_download_all.sh"
  fi

  python "${SCRIPTS_DIR}/02_trim_lending.py" \
    --input "${ROOT_DIR}/data/raw/lendingclub/accepted_2007_to_2018Q4.csv" \
    --output "${ROOT_DIR}/data/processed/lendingclub_5k.csv"

  python "${SCRIPTS_DIR}/03_gen_conversations.py" \
    --input "${ROOT_DIR}/data/raw/banking77/banking77.csv" \
    --output "${ROOT_DIR}/data/processed/banking77_conversations.csv"
}

run_upload_stage() {
  if [[ "${MODE}" != "cloud" ]]; then
    echo "Skipping upload stage: OCI upload is only used in cloud mode."
    return
  fi
  if [[ "${SKIP_UPLOAD}" == "true" ]]; then
    echo "Skipping upload stage by request."
    return
  fi
  "${SCRIPTS_DIR}/04_upload_to_oci.sh"
}

run_container_stage() {
  if [[ "${MODE}" != "container" ]]; then
    echo "Skipping container stage in cloud mode."
    return
  fi
  "${SCRIPTS_DIR}/05_start_oracle_container.sh"
}

run_sql_core_stage() {
  local connect
  connect="$(build_connect_string)"

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    export TNS_ADMIN
  fi

  "${SCRIPTS_DIR}/06_run_sql_sequence.sh" \
    --sql-client "${SQL_CLIENT}" \
    --connect "${connect}" \
    "${SQL_DIR}/01_schema.sql" \
    "${SQL_DIR}/02_staging_ddl.sql" \
    "${SQL_DIR}/03_load_onnx_model.sql" \
    "${SQL_DIR}/04_copy_data.sql" \
    "${SQL_DIR}/05_transform.sql" \
    "${SQL_DIR}/06_embed_and_index.sql" \
    "${SQL_DIR}/07_property_graph.sql" \
    "${SQL_DIR}/08_select_ai_profile.sql"
}

run_sql_uc_stage() {
  local connect
  connect="$(build_connect_string)"

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    export TNS_ADMIN
  fi

  "${SCRIPTS_DIR}/06_run_sql_sequence.sh" \
    --sql-client "${SQL_CLIENT}" \
    --connect "${connect}" \
    "${SQL_DIR}/09_uc1_card_view.sql" \
    "${SQL_DIR}/10_uc2_abandoned_app.sql" \
    "${SQL_DIR}/11_uc3_declined_txn.sql"
}

echo "Mode: ${MODE}"
echo "Stage: ${STAGE}"

case "${STAGE}" in
  data)
    run_data_stage
    ;;
  upload)
    run_upload_stage
    ;;
  container)
    run_container_stage
    ;;
  sql-core)
    run_sql_core_stage
    ;;
  sql-uc)
    run_sql_uc_stage
    ;;
  all)
    run_data_stage
    run_container_stage
    run_upload_stage
    run_sql_core_stage
    run_sql_uc_stage
    ;;
  *)
    echo "ERROR: Unknown stage '${STAGE}'."
    usage
    exit 1
    ;;
esac

echo "Orchestration stage '${STAGE}' completed successfully."
