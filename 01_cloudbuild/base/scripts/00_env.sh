#!/usr/bin/env bash
# 用途：載入 Cloud Build 基礎模組與全域環境，並驗證必要專案/IAM 設定。
# 流程：依腳本位置尋找兩個 env 檔，保留全域值，再匯出 Cloud Build 連線資訊。
# 重要變數：GLOBAL_ENV_FILE、BASE_ENV_FILE、PROJECT_NAME、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT。
# 資源影響：只讀取並匯出環境，不建立或修改 GCP 資源；缺檔或空值會立即失敗。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${SCRIPT_DIR}/../../../global-env/env.sh"
BASE_ENV_FILE="${SCRIPT_DIR}/env/env.sh"

for env_file in "$GLOBAL_ENV_FILE" "$BASE_ENV_FILE"; do
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
source "$BASE_ENV_FILE"
PROJECT_NAME="$GLOBAL_PROJECT_NAME"
GOOGLE_PROJECT_ID="$GLOBAL_GOOGLE_PROJECT_ID"
GOOGLE_PROJECT_REGION="$GLOBAL_GOOGLE_PROJECT_REGION"
EXEC_IAM_ACCOUNT="$GLOBAL_EXEC_IAM_ACCOUNT"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured in %s\n' "$variable" "$GLOBAL_ENV_FILE" >&2
    return 1 2>/dev/null || exit 1
  fi
done

export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export CLOUD_BUILD_CONNECTION_NAME CLOUD_BUILD_REPOSITORY_NAME
