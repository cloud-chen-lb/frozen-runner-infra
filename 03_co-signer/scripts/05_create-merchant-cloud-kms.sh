#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if (($# != 1)); then printf 'Usage: %s <merchant>\n' "$0" >&2; exit 1; fi
MERCHANT_SLUG="$1"
[[ "${MERCHANT_SLUG}" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || {
  printf 'A valid merchant slug is required\n' >&2; exit 1;
}
MERCHANT_ENV_FILE="${SCRIPT_DIR}/env/env-merchant-${MERCHANT_SLUG}.sh"
[[ -f "${MERCHANT_ENV_FILE}" ]] || { printf 'Merchant environment file not found: %s\n' "${MERCHANT_ENV_FILE}" >&2; exit 1; }
source "${MERCHANT_ENV_FILE}"

for variable in VM_ZONE VM_MACHINE_TYPE VM_VPC_NETWORK; do
  [[ -n "${!variable:-}" ]] || { printf '%s is not configured\n' "$variable" >&2; exit 1; }
done
KMS_CRYPTO_KEY="${PROJECT_NAME}-${MERCHANT_SLUG}-cosigner-kms-key"
VM_SERVICE_ACCOUNT_NAME="${MERCHANT_SLUG}-cosigner-sa"
VM_SERVICE_ACCOUNT_EMAIL="${VM_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "${VM_SERVICE_ACCOUNT_EMAIL}" \
  --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${VM_SERVICE_ACCOUNT_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --display-name="Safeheron Co-Signer ${MERCHANT_SLUG} service account"
fi
if ! gcloud kms keys describe "${KMS_CRYPTO_KEY}" --project="${GOOGLE_PROJECT_ID}" \
  --location="${GOOGLE_PROJECT_REGION}" --keyring="${KMS_KEYRING}" >/dev/null 2>&1; then
  gcloud kms keys create "${KMS_CRYPTO_KEY}" --project="${GOOGLE_PROJECT_ID}" \
    --location="${GOOGLE_PROJECT_REGION}" --keyring="${KMS_KEYRING}" --purpose=encryption
fi

for attempt in 1 2 3 4 5 6; do
  if gcloud kms keys add-iam-policy-binding "${KMS_CRYPTO_KEY}" --project="${GOOGLE_PROJECT_ID}" \
    --location="${GOOGLE_PROJECT_REGION}" --keyring="${KMS_KEYRING}" \
    --member="serviceAccount:${VM_SERVICE_ACCOUNT_EMAIL}" \
    --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"; then
    break
  fi
  if [[ "${attempt}" == 6 ]]; then
    printf 'Timed out waiting for service account propagation: %s\n' "${VM_SERVICE_ACCOUNT_EMAIL}" >&2
    exit 1
  fi
  sleep_seconds=$((2 ** attempt))
  sleep "${sleep_seconds}"
done
