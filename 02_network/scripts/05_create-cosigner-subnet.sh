#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if subnet_description="$(gcloud compute networks subnets describe "${COSIGNER_SUBNET_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Fq "${COSIGNER_SUBNET_CIDR}" <<<"${subnet_description}" ||
    ! grep -Fq "${NETWORK_NAME}" <<<"${subnet_description}" ||
    ! grep -Fq "${GOOGLE_PROJECT_REGION}" <<<"${subnet_description}"; then
    printf 'Drift: %s subnet contract does not match\n' "${COSIGNER_SUBNET_NAME}" >&2
    exit 1
  fi
else
  gcloud compute networks subnets create "${COSIGNER_SUBNET_NAME}" \
    --network="${NETWORK_NAME}" --description="Co-Signer VM 使用的子網路。" \
    --region="${GOOGLE_PROJECT_REGION}" --range="${COSIGNER_SUBNET_CIDR}" \
    --project="${GOOGLE_PROJECT_ID}"
fi
