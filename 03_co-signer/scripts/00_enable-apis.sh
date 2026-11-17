#!/usr/bin/env bash
# 用途：啟用 Co-Signer 建置所需的 Cloud KMS、Compute、IAM 與 Cloud SQL API。
# 流程：載入環境，逐一檢查 API 狀態，只啟用尚未啟用的 API。
# 重要變數：APIS、GOOGLE_PROJECT_ID；資源影響：修改指定專案的 API 啟用狀態。
# 安全限制：只啟用本模組所需 API；需要 serviceusage.services.enable 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

APIS=(
  cloudkms.googleapis.com
  compute.googleapis.com
  iam.googleapis.com
  sqladmin.googleapis.com
)

for api in "${APIS[@]}"; do
  enabled_api="$(gcloud services list \
    --enabled \
    --project="${GOOGLE_PROJECT_ID}" \
    --filter="config.name=${api}" \
    --format='value(config.name)')"
  if [[ "${enabled_api}" == "${api}" ]]; then
    printf 'API already enabled: %s\n' "${api}"
  else
    gcloud services enable "${api}" --project="${GOOGLE_PROJECT_ID}"
    printf 'Enabled API: %s\n' "${api}"
  fi
done
