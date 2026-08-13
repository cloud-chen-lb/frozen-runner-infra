#!/usr/bin/env bash
# 用途：啟用主應用程式 Cloud SQL、Cloud Build、Artifact Registry、Run 與 IAM API。
# 流程：載入環境，唯讀列出已啟用 API，再逐一啟用缺少項目。
# 重要變數：APIS、GOOGLE_PROJECT_ID；資源影響：修改專案 API 啟用狀態。
# 安全/驗證限制：只驗證 API 名稱與啟用結果，不驗證服務設定；需要 serviceusage 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

APIS=(
  artifactregistry.googleapis.com
  cloudbuild.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  logging.googleapis.com
)

for api in "${APIS[@]}"; do
# 唯讀列出 ${GOOGLE_PROJECT_ID} 已啟用的 API，不修改資源。
  enabled_api="$(gcloud services list \
    --enabled \
    --project="$GOOGLE_PROJECT_ID" \
    --filter="config.name=$api" \
    --format='value(config.name)')"
  if [[ "$enabled_api" == "$api" ]]; then
    printf 'API already enabled: %s\n' "$api"
  else
    # 在 ${GOOGLE_PROJECT_ID} 啟用缺少的 API，修改專案服務設定。
    gcloud services enable "$api" --project="$GOOGLE_PROJECT_ID"
    printf 'Enabled API: %s\n' "$api"
  fi
done
