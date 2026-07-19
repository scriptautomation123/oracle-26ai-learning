#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/require_venv.sh"
require_demo_venv

usage() {
  cat <<'EOF'
Usage:
  06_run_sql_sequence.sh --connect user/password@dsn [--sql-client auto|sql|sqlplus] file1.sql [file2.sql ...]

Examples:
  ./scripts/06_run_sql_sequence.sh --connect ADMIN/Secret@mydb_high sql/01_schema.sql sql/02_staging_ddl.sql
  ./scripts/06_run_sql_sequence.sh --sql-client sqlplus --connect testuser/TestPass123@localhost:1521/FREEPDB1 sql/09_uc1_card_view.sql
EOF
}

SQL_CLIENT="auto"
CONNECT_STRING=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sql-client)
      SQL_CLIENT="${2:-}"
      shift 2
      ;;
    --connect)
      CONNECT_STRING="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if [[ -z "${CONNECT_STRING}" || ${#FILES[@]} -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "${SQL_CLIENT}" == "auto" ]]; then
  if command -v sql >/dev/null 2>&1; then
    SQL_CLIENT="sql"
  elif command -v sqlplus >/dev/null 2>&1; then
    SQL_CLIENT="sqlplus"
  else
    echo "ERROR: No SQL client found. Install SQLcl (sql) or SQL*Plus (sqlplus)."
    exit 1
  fi
fi

run_one() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "ERROR: SQL file not found: ${file}"
    return 1
  fi

  echo "Running ${file}"
  if [[ "${SQL_CLIENT}" == "sql" ]]; then
    sql -S "${CONNECT_STRING}" @"${file}"
  elif [[ "${SQL_CLIENT}" == "sqlplus" ]]; then
    sqlplus -L -S "${CONNECT_STRING}" @"${file}"
  else
    echo "ERROR: Unsupported SQL client '${SQL_CLIENT}'."
    return 1
  fi
}

for sql_file in "${FILES[@]}"; do
  run_one "${sql_file}"
done

echo "SQL sequence completed."
