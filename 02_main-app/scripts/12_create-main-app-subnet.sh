#!/usr/bin/env bash
# 用途：建立或驗證主應用程式 subnet 的 CIDR、VPC 與區域合約。
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

if subnet_description="$(gcloud compute networks subnets describe "${MAIN_APP_SUBNET_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${MAIN_APP_SUBNET_CIDR}" <<<"${subnet_description}" || \
    ! grep -Fq "${NETWORK_NAME}" <<<"${subnet_description}" || \
    ! grep -Fq "${GOOGLE_PROJECT_REGION}" <<<"${subnet_description}"; then
    printf 'Drift: %s subnet contract does not match\n' "${MAIN_APP_SUBNET_NAME}" >&2
    exit 1
  fi
else
  gcloud compute networks subnets create "${MAIN_APP_SUBNET_NAME}" \
    --network="${NETWORK_NAME}" --description="主應用程式執行環境使用的子網路。" \
    --region="${GOOGLE_PROJECT_REGION}" --range="${MAIN_APP_SUBNET_CIDR}" \
    --project="${GOOGLE_PROJECT_ID}"
fi
