#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
if (($# != 1)); then printf 'Usage: %s <merchant>\n' "$0" >&2; exit 1; fi
MERCHANT_SLUG="$1"
[[ "${MERCHANT_SLUG}" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || { printf 'A valid merchant slug is required\n' >&2; exit 1; }
MERCHANT_ENV_FILE="${SCRIPT_DIR}/env/env-merchant-${MERCHANT_SLUG}.sh"
[[ -f "${MERCHANT_ENV_FILE}" ]] || { printf 'Merchant environment file not found: %s\n' "${MERCHANT_ENV_FILE}" >&2; exit 1; }
source "${MERCHANT_ENV_FILE}"

VM_NAME="${PROJECT_NAME}-${MERCHANT_SLUG}-cosigner"
VM_STATIC_IP_NAME="${VM_NAME}-ip"
VM_SERVICE_ACCOUNT_EMAIL="${MERCHANT_SLUG}-cosigner-sa@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
if ! gcloud compute addresses describe "${VM_STATIC_IP_NAME}" --project="${GOOGLE_PROJECT_ID}" \
  --region="${GOOGLE_PROJECT_REGION}" >/dev/null 2>&1; then
  gcloud compute addresses create "${VM_STATIC_IP_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --region="${GOOGLE_PROJECT_REGION}" --network-tier=PREMIUM
fi
gcloud compute instances create "${VM_NAME}" --project="${GOOGLE_PROJECT_ID}" --zone="${VM_ZONE}" \
  --machine-type="${VM_MACHINE_TYPE}" --service-account="${VM_SERVICE_ACCOUNT_EMAIL}" \
  --scopes="https://www.googleapis.com/auth/cloud-platform" --image-family="ubuntu-2404-lts-amd64" \
  --image-project="ubuntu-os-cloud" \
  --network-interface="address=${VM_STATIC_IP_NAME},network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=${VM_VPC_NETWORK}" \
  --boot-disk-size=100G
