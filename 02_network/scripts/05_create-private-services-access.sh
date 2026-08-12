#!/usr/bin/env bash
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
  gcloud compute addresses create "${PRIVATE_SERVICES_RANGE_NAME}" \
    --global --purpose=VPC_PEERING --prefix-length="${range_prefix}" \
    --addresses="${range_ip}" --network="${NETWORK_NAME}" \
    --project="${GOOGLE_PROJECT_ID}"
fi

peerings="$(gcloud services vpc-peerings list --network="${NETWORK_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"
if grep -Fq 'servicenetworking.googleapis.com' <<<"${peerings}"; then
  if ! grep -Fq "${PRIVATE_SERVICES_RANGE_NAME}" <<<"${peerings}"; then
    printf 'Drift: Private Services Access range does not match\n' >&2
    exit 1
  fi
else
  gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges="${PRIVATE_SERVICES_RANGE_NAME}" \
    --network="${NETWORK_NAME}" --project="${GOOGLE_PROJECT_ID}"
fi
