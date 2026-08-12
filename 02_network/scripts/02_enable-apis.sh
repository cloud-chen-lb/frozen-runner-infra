#!/usr/bin/env bash
# 用途：啟用網路、Cloud SQL、Cloud Run、Secret Manager 等部署所需 API。
# 流程：取得已啟用服務清單，逐一啟用缺少的 required_services。
# 重要變數：required_services、GOOGLE_PROJECT_ID；資源影響：修改指定專案的 API 啟用狀態。
# 安全/驗證限制：只驗證 API 名稱，不檢查後續資源設定；需要 serviceusage 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

required_services=(
  compute.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  logging.googleapis.com
  run.googleapis.com
  secretmanager.googleapis.com
  servicenetworking.googleapis.com
  sqladmin.googleapis.com
  vpcaccess.googleapis.com
)

# 唯讀列出 ${GOOGLE_PROJECT_ID} 已啟用的 API，不修改專案資源。
enabled_services="$(gcloud services list --enabled --project="${GOOGLE_PROJECT_ID}" --format='value(config.name)')"
for service in "${required_services[@]}"; do
  if ! grep -Fxq "${service}" <<<"${enabled_services}"; then
    # 在 ${GOOGLE_PROJECT_ID} 啟用缺少的 API，修改專案服務設定。
    gcloud services enable "${service}" --project="${GOOGLE_PROJECT_ID}"
  fi
done
