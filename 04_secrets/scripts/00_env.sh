#!/usr/bin/env bash
# 用途：載入秘密模組設定，驗證 Secret Manager mapping 與三個 service account ID。
# 流程：載入全域/模組 env、保留全域專案值、驗證必要值後匯出設定。
# 重要變數：APP_SECRET_MAPPING、MIGRATION_SECRET_MAPPING、APP/MIGRATION/DEPLOY_SERVICE_ACCOUNT_NAME。
# 資源影響：只載入與驗證設定；本檔不建立秘密或讀取秘密值。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-${SCRIPT_DIR}/../../global-env/env.sh}"
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
  APP_SECRET_MAPPING MIGRATION_SECRET_MAPPING APP_SERVICE_ACCOUNT_NAME \
  MIGRATION_SERVICE_ACCOUNT_NAME DEPLOY_SERVICE_ACCOUNT_NAME; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

for variable in APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME \
  DEPLOY_SERVICE_ACCOUNT_NAME; do
  if [[ ! "${!variable}" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    printf '%s has an invalid service-account ID\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export APP_SECRET_MAPPING MIGRATION_SECRET_MAPPING
export APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME DEPLOY_SERVICE_ACCOUNT_NAME
