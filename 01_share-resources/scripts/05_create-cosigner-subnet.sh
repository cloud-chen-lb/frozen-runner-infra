#!/usr/bin/env bash
# 用途：建立或驗證 co-signer VM 使用的 subnet。
# 流程：載入設定，唯讀檢查既有 subnet 合約，不存在才建立。
# 重要變數：COSIGNER_SUBNET_CIDR、COSIGNER_SUBNET_NAME、NETWORK_NAME。
# 資源影響：建立 subnet；安全/驗證限制：既有 CIDR、VPC 或 region 漂移時停止。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 co-signer subnet 設定，不修改資源。
if subnet_description="$(gcloud compute networks subnets describe "${COSIGNER_SUBNET_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${COSIGNER_SUBNET_CIDR}" <<<"${subnet_description}" ||
    ! grep -Fq "${NETWORK_NAME}" <<<"${subnet_description}" ||
    ! grep -Fq "${GOOGLE_PROJECT_REGION}" <<<"${subnet_description}"; then
    printf 'Drift: %s subnet contract does not match\n' "${COSIGNER_SUBNET_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 co-signer subnet。
  gcloud compute networks subnets create "${COSIGNER_SUBNET_NAME}" \
    --network="${NETWORK_NAME}" --description="Co-Signer VM 使用的子網路。" \
    --region="${GOOGLE_PROJECT_REGION}" --range="${COSIGNER_SUBNET_CIDR}" \
    --project="${GOOGLE_PROJECT_ID}"
fi
