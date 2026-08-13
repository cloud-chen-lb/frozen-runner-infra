#!/usr/bin/env bash
# 用途：建立或驗證專案的 custom-mode VPC。
# 流程：驗證 region，描述既有網路並檢查 CUSTOM；不存在才建立。
# 重要變數：NETWORK_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION；資源影響：建立 VPC，不修改既有 VPC。
# 安全/驗證限制：非 custom-mode 或設定漂移會停止，避免自動改動既有網路。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]]; then
  printf 'Invalid GOOGLE_PROJECT_REGION: %s\n' "${GOOGLE_PROJECT_REGION}" >&2
  exit 1
fi

vpc_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 VPC 設定，不修改資源。
if vpc_description="$(gcloud compute networks describe "${NETWORK_NAME}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Eiq 'subnetMode:[[:space:]]*CUSTOM' <<<"${vpc_description}"; then
    printf 'Drift: %s is not a custom-mode VPC\n' "${NETWORK_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 custom-mode VPC。
  gcloud compute networks create "${NETWORK_NAME}" \
    --subnet-mode=custom \
    --description="主應用程式與 Cloud SQL 使用的自訂模式 VPC 網路。" \
    --project="${GOOGLE_PROJECT_ID}"
fi
