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
[[ -f "${MERCHANT_ENV_FILE}" ]] || {
  printf 'Merchant environment file not found: %s\n' "${MERCHANT_ENV_FILE}" >&2; exit 1;
}
source "${MERCHANT_ENV_FILE}"

[[ -n "${VM_ZONE:-}" ]] || { printf 'VM_ZONE is not configured\n' >&2; exit 1; }

PUBLIC_KEY_FILE="${HOME}/.ssh/id_rsa.pub"
[[ -f "${PUBLIC_KEY_FILE}" ]] || {
  printf 'SSH public key not found: %s\n' "${PUBLIC_KEY_FILE}" >&2; exit 1;
}
PUBLIC_KEY="$(<"${PUBLIC_KEY_FILE}")"
[[ -n "${PUBLIC_KEY}" && "${PUBLIC_KEY}" != *$'\n'* ]] || {
  printf 'SSH public key must contain exactly one non-empty line: %s\n' "${PUBLIC_KEY_FILE}" >&2
  exit 1
}

VM_NAME="${PROJECT_NAME}-${MERCHANT_SLUG}-cosigner"
existing_metadata="$(gcloud compute instances describe "${VM_NAME}" --project="${GOOGLE_PROJECT_ID}" \
  --zone="${VM_ZONE}" --format='get(metadata.ssh-keys)')"
if ! printf '%s\n' "${existing_metadata}" | awk -v key="${PUBLIC_KEY}" '$0 == key { found=1 } END { exit !found }'; then
  exit 0
fi

metadata_file="$(mktemp)"
trap 'rm -f "${metadata_file}"' EXIT
printf '%s\n' "${existing_metadata}" | awk -v key="${PUBLIC_KEY}" '$0 != key' >"${metadata_file}"
if [[ -s "${metadata_file}" ]]; then
  gcloud compute instances add-metadata "${VM_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --zone="${VM_ZONE}" --metadata-from-file="ssh-keys=${metadata_file}"
else
  gcloud compute instances remove-metadata "${VM_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --zone="${VM_ZONE}" --keys=ssh-keys
fi
