#!/usr/bin/env bash
# 用途：載入 co-signer MySQL 設定並驗證必要環境檔案。
# 流程：定位全域與 MySQL module env，交由設定檔提供 instance/database 變數。
# 重要變數：GLOBAL_ENV_FILE、MODULE_ENV_FILE、MYSQL_INSTANCE_NAME、MYSQL_NETWORK_NAME。
# 資源影響：只載入設定；安全/驗證限制：缺少 env 檔案時停止，不執行 GCP 命令。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-${SCRIPT_DIR}/../../global-env/env.sh}"
MODULE_ENV_FILE="${MODULE_ENV_FILE:-${SCRIPT_DIR}/env/env.sh}"
source "${GLOBAL_ENV_FILE}"
source "${MODULE_ENV_FILE}"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION MYSQL_VERSION MYSQL_EDITION \
  MYSQL_CPU MYSQL_MEMORY_MB MYSQL_STORAGE_GB MYSQL_NETWORK_NAME MYSQL_INSTANCE_NAME; do
  [[ -n "${!variable:-}" ]] || { printf '%s is not configured\n' "${variable}" >&2; exit 1; }
done
export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION MYSQL_VERSION MYSQL_EDITION
export MYSQL_CPU MYSQL_MEMORY_MB MYSQL_STORAGE_GB MYSQL_NETWORK_NAME MYSQL_INSTANCE_NAME
