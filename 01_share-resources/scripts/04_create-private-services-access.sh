#!/usr/bin/env bash
# 用途：建立或驗證 Cloud SQL 使用的 Private Services Access 位址範圍與 VPC peering。
# 流程：驗證 CIDR，檢查/建立 VPC_PEERING global address，再檢查/連接 servicenetworking peering。
# 重要變數：PRIVATE_SERVICES_RANGE_CIDR、PRIVATE_SERVICES_RANGE_NAME、NETWORK_NAME。
# 資源影響：建立 global private range 並建立 VPC peering；既有合約漂移時停止。
# 安全限制：CIDR 不可隨意變更，錯誤範圍會影響 Cloud SQL 私有連線。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

valid_cidr() {
  local cidr octet
  cidr="$1"
  [[ "${cidr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  IFS=. read -r -a octets <<<"${cidr%/*}"
  for octet in "${octets[@]}"; do (( octet <= 255 )) || return 1; done
  [[ "${cidr#*/}" -ge 1 ]]
}

if ! valid_cidr "${PRIVATE_SERVICES_RANGE_CIDR}" || [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]]; then
  printf 'Invalid private-services CIDR or region\n' >&2
  exit 1
fi

range_ip="${PRIVATE_SERVICES_RANGE_CIDR%/*}"
range_prefix="${PRIVATE_SERVICES_RANGE_CIDR#*/}"
range_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Private Services Access 位址範圍，不修改資源。
if range_description="$(gcloud compute addresses describe "${PRIVATE_SERVICES_RANGE_NAME}" \
  --global --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${range_ip}" <<<"${range_description}" || \
    ! grep -Fq "${range_prefix}" <<<"${range_description}" || \
    ! grep -Eiq 'purpose:[[:space:]]*VPC_PEERING' <<<"${range_description}" || \
    ! grep -Fq "${NETWORK_NAME}" <<<"${range_description}"; then
    printf 'Drift: %s private services range contract does not match\n' "${PRIVATE_SERVICES_RANGE_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 VPC_PEERING global 位址範圍。
  gcloud compute addresses create "${PRIVATE_SERVICES_RANGE_NAME}" \
    --global --purpose=VPC_PEERING --prefix-length="${range_prefix}" \
    --addresses="${range_ip}" --network="${NETWORK_NAME}" \
    --description="Cloud SQL Private Services Access 使用的 VPC peering 位址範圍。" \
    --project="${GOOGLE_PROJECT_ID}"
fi

# 唯讀列出 ${GOOGLE_PROJECT_ID} VPC peering，不修改網路資源。
peerings="$(gcloud services vpc-peerings list --network="${NETWORK_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"
if grep -Fq 'servicenetworking.googleapis.com' <<<"${peerings}"; then
  if ! grep -Fq "${PRIVATE_SERVICES_RANGE_NAME}" <<<"${peerings}"; then
    printf 'Drift: Private Services Access range does not match\n' >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 建立 Service Networking VPC peering。
  gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges="${PRIVATE_SERVICES_RANGE_NAME}" \
    --network="${NETWORK_NAME}" --project="${GOOGLE_PROJECT_ID}"
fi
