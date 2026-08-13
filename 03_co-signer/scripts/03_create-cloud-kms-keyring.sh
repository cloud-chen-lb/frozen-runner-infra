#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
if ! gcloud kms keyrings describe "${KMS_KEYRING}" --project="${GOOGLE_PROJECT_ID}" \
  --location="${GOOGLE_PROJECT_REGION}" >/dev/null 2>&1; then
  gcloud kms keyrings create "${KMS_KEYRING}" --project="${GOOGLE_PROJECT_ID}" \
    --location="${GOOGLE_PROJECT_REGION}"
fi
