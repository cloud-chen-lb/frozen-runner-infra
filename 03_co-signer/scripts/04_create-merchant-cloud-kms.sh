#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if (($# != 1)); then printf 'Usage: %s <merchant>\n' "$0" >&2; exit 1; fi
MERCHANT_SLUG="$1"
[[ "${MERCHANT_SLUG}" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || {
  printf 'A valid merchant slug is required\n' >&2; exit 1;
}
MERCHANT_ENV_FILE="${SCRIPT_DIR}/env/merchant-cosigner-${MERCHANT_SLUG}.env"
[[ -f "${MERCHANT_ENV_FILE}" ]] || { printf 'Merchant environment file not found: %s\n' "${MERCHANT_ENV_FILE}" >&2; exit 1; }
source "${MERCHANT_ENV_FILE}"

for variable in VM_ZONE VM_MACHINE_TYPE VM_VPC_NETWORK; do
  [[ -n "${!variable:-}" ]] || { printf '%s is not configured\n' "$variable" >&2; exit 1; }
done
KMS_CRYPTO_KEY="${PROJECT_NAME}-${MERCHANT_SLUG}-cosigner-kms-key"
VM_SERVICE_ACCOUNT_NAME="${PROJECT_NAME}-${MERCHANT_SLUG}-cosigner-sa"
VM_SERVICE_ACCOUNT_EMAIL="${VM_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${VM_SERVICE_ACCOUNT_NAME}" --project="${GOOGLE_PROJECT_ID}" \
  --display-name="Safeheron Co-Signer ${MERCHANT_SLUG} service account"
gcloud kms keys create "${KMS_CRYPTO_KEY}" --project="${GOOGLE_PROJECT_ID}" \
  --location="${GOOGLE_PROJECT_REGION}" --keyring="${KMS_KEYRING}" --purpose=encryption
gcloud kms keys add-iam-policy-binding "${KMS_CRYPTO_KEY}" --project="${GOOGLE_PROJECT_ID}" \
  --location="${GOOGLE_PROJECT_REGION}" --keyring="${KMS_KEYRING}" \
  --member="serviceAccount:${VM_SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
