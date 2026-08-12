#!/usr/bin/env bash
# 用途：載入部署模組與全域環境，驗證部署所需的網路、秘密、執行期與 service account 設定。
# 流程：讀取 env 檔、以全域專案值覆蓋模組同名值，再驗證必要欄位與 service account ID。
# 重要變數：APP_VPC_ARGS、MIGRATION_VPC_ARGS、*_SECRET_MAPPING、*_RUNTIME_ENV_VARS、*_SERVICE_ACCOUNT_NAME、APP_* resource overrides。
# 資源影響：只載入/匯出設定，不建立 GCP 資源；格式錯誤會在呼叫 gcloud 前停止。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-${SCRIPT_DIR}/../../../global-env/env.sh}"
MODULE_ENV_FILE="${MODULE_ENV_FILE:-${SCRIPT_DIR}/env/env.sh}"

for env_file in "$GLOBAL_ENV_FILE" "$MODULE_ENV_FILE"; do
  if [[ ! -f "$env_file" ]]; then
    printf 'Environment file not found: %s\n' "$env_file" >&2
    return 1 2>/dev/null || exit 1
  fi
done
source "$GLOBAL_ENV_FILE"
GLOBAL_PROJECT_NAME="$PROJECT_NAME"
GLOBAL_GOOGLE_PROJECT_ID="$GOOGLE_PROJECT_ID"
GLOBAL_GOOGLE_PROJECT_REGION="$GOOGLE_PROJECT_REGION"
GLOBAL_EXEC_IAM_ACCOUNT="$EXEC_IAM_ACCOUNT"
source "$MODULE_ENV_FILE"
PROJECT_NAME="$GLOBAL_PROJECT_NAME"
GOOGLE_PROJECT_ID="$GLOBAL_GOOGLE_PROJECT_ID"
GOOGLE_PROJECT_REGION="$GLOBAL_GOOGLE_PROJECT_REGION"
EXEC_IAM_ACCOUNT="$GLOBAL_EXEC_IAM_ACCOUNT"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT \
  CLOUD_BUILD_SOURCE_BRANCH APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING APP_RUNTIME_ENV_VARS; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

for variable in APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME \
  DEPLOY_SERVICE_ACCOUNT_NAME; do
  if [[ ! "${!variable:-}" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    printf '%s has an invalid service-account ID\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export CLOUD_BUILD_SOURCE_BRANCH DEPLOY_SMOKE_TEST_URL
export PRODUCTION_TRIGGER_NAME PRODUCTION_APP_NAME PRODUCTION_MIGRATION_JOB_NAME
export APP_SECRET_MAPPING MIGRATION_SECRET_MAPPING APP_RUNTIME_ENV_VARS MIGRATION_RUNTIME_ENV_VARS
export APP_MIN_INSTANCE APP_MAX_INSTANCE APP_CPU APP_MEMORY APP_TIMEOUT APP_CONCURRENCY
export APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME DEPLOY_SERVICE_ACCOUNT_NAME
