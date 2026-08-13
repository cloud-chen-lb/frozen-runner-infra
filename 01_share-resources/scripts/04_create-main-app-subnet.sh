#!/usr/bin/env bash
# 用途：建立或驗證主應用程式 subnet 的 CIDR、VPC 與區域合約。
# 流程：驗證 CIDR/region，檢查既有 subnet，不存在才依設定建立。
# 重要變數：MAIN_APP_SUBNET_CIDR、MAIN_APP_SUBNET_NAME、NETWORK_NAME；資源影響：建立 subnet。
# 安全/驗證限制：既有 subnet 合約不符時停止，不會自動調整可能影響服務的網路設定。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

valid_cidr() {
  local cidr prefix octet
  cidr="$1"
  [[ "${cidr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  prefix="${cidr#*/}"
  IFS=. read -r -a octets <<<"${cidr%/*}"
  for octet in "${octets[@]}"; do (( octet <= 255 )) || return 1; done
  [[ "${prefix}" -ge 1 ]]
}

if ! valid_cidr "${MAIN_APP_SUBNET_CIDR}" || [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]]; then
  printf 'Invalid main-app subnet CIDR or region\n' >&2
  exit 1
fi

subnet_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的主應用程式 subnet 設定，不修改資源。
if subnet_description="$(gcloud compute networks subnets describe "${MAIN_APP_SUBNET_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${MAIN_APP_SUBNET_CIDR}" <<<"${subnet_description}" || \
    ! grep -Fq "${NETWORK_NAME}" <<<"${subnet_description}" || \
    ! grep -Fq "${GOOGLE_PROJECT_REGION}" <<<"${subnet_description}"; then
    printf 'Drift: %s subnet contract does not match\n' "${MAIN_APP_SUBNET_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增主應用程式 subnet。
  gcloud compute networks subnets create "${MAIN_APP_SUBNET_NAME}" \
    --network="${NETWORK_NAME}" \
    --description="主應用程式執行環境使用的子網路。" \
    --region="${GOOGLE_PROJECT_REGION}" \
    --range="${MAIN_APP_SUBNET_CIDR}" \
    --project="${GOOGLE_PROJECT_ID}"
fi
