#!/usr/bin/env bash
# 用途：建立或驗證主應用程式 VPC 的 Cloud Router、固定外部 IP 與手動 NAT。
# 流程：驗證設定，逐一檢查 router、egress IP、NAT 的完整合約，不符即停止。
# 重要變數：ROUTER_NAME、EGRESS_IP_NAME、NAT_NAME、MAIN_APP_SUBNET_NAME；資源影響：建立上述網路資源。
# 安全/驗證限制：NAT 僅指定主 app subnet 且使用固定 IP；不會自動修正既有 NAT 漂移。
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

if ! valid_cidr "${MAIN_APP_SUBNET_CIDR}" || [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]]; then
  printf 'Invalid main-app subnet CIDR or region\n' >&2
  exit 1
fi

router_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud Router 設定，不修改資源。
if router_description="$(gcloud compute routers describe "${ROUTER_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${NETWORK_NAME}" <<<"${router_description}" || \
    ! grep -Fq "${GOOGLE_PROJECT_REGION}" <<<"${router_description}"; then
    printf 'Drift: %s router contract does not match\n' "${ROUTER_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Cloud Router。
  gcloud compute routers create "${ROUTER_NAME}" --network="${NETWORK_NAME}" \
    --region="${GOOGLE_PROJECT_REGION}" \
    --description="主應用程式對外連線使用的 Cloud Router。" \
    --project="${GOOGLE_PROJECT_ID}"
fi

ip_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的固定外部 IP，不修改資源。
if ip_description="$(gcloud compute addresses describe "${EGRESS_IP_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Eq '^status:[[:space:]]*RESERVED$' <<<"${ip_description}" || \
    ! grep -Eq '^addressType:[[:space:]]*EXTERNAL$' <<<"${ip_description}" || \
    ! grep -Eq "^region:[[:space:]].*/regions/${GOOGLE_PROJECT_REGION}$" <<<"${ip_description}"; then
    printf 'Drift: %s address contract does not match\n' "${EGRESS_IP_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增固定外部 IP。
  gcloud compute addresses create "${EGRESS_IP_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
    --description="主應用程式 Cloud NAT 使用的固定外部 IP。" \
    --project="${GOOGLE_PROJECT_ID}"
fi

nat_description=''
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud NAT 設定，不修改資源。
if nat_description="$(gcloud compute routers nats describe "${NAT_NAME}" \
  --router="${ROUTER_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  nat_ip_lines="$(grep -Ec "^-[[:space:]].*/addresses/[^[:space:]]+$" <<<"${nat_description}" || true)"
  nat_subnet_lines="$(grep -Ec '^- name:[[:space:]].*/subnetworks/[^[:space:]]+$' <<<"${nat_description}" || true)"
  if ! grep -Eq '^natIpAllocateOption:[[:space:]]*MANUAL_ONLY$' <<<"${nat_description}" || \
    ! grep -Eq '^sourceSubnetworkIpRangesToNat:[[:space:]]*LIST_OF_SUBNETWORKS$' <<<"${nat_description}" || \
    [[ "${nat_ip_lines}" -ne 1 ]] || \
    ! grep -Eq "^-[[:space:]].*/addresses/${EGRESS_IP_NAME}$" <<<"${nat_description}" || \
    [[ "${nat_subnet_lines}" -ne 1 ]] || \
    ! grep -Eq "^-[[:space:]]name:[[:space:]].*/subnetworks/${MAIN_APP_SUBNET_NAME}$" <<<"${nat_description}" || \
    ! grep -Eq '^  sourceIpRangesToNat:[[:space:]]*$' <<<"${nat_description}" || \
    ! grep -Eq '^  - ALL$' <<<"${nat_description}"; then
    printf 'Drift: %s NAT contract does not match\n' "${NAT_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Cloud NAT。
  gcloud compute routers nats create "${NAT_NAME}" --router="${ROUTER_NAME}" \
    --region="${GOOGLE_PROJECT_REGION}" \
    --nat-external-ip-pool="${EGRESS_IP_NAME}" \
    --nat-custom-subnet-ip-ranges="${MAIN_APP_SUBNET_NAME}:ALL" \
    --project="${GOOGLE_PROJECT_ID}"
fi
