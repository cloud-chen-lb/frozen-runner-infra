#!/usr/bin/env bash
# 用途：確保 Cloud Build 基礎流程所需的 Google API 已啟用。
# 流程：逐一查詢 artifact registry、Cloud Build、IAM、Logging 與 Service Usage，缺少才啟用。
# 重要變數：APIS、GOOGLE_PROJECT_ID；資源影響：修改指定 GCP 專案的 API 啟用狀態。
# 安全/驗證限制：只以 API 名稱比對，不驗證其他專案設定；需有 serviceusage 啟用權限。
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
