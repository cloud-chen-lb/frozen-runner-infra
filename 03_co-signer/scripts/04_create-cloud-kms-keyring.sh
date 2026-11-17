#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
describe_output_file="$(mktemp)"
trap 'rm -f "${describe_output_file}"' EXIT

printf 'Checking KMS keyring %s in project %s, location %s...\n' \
  "${KMS_KEYRING}" "${GOOGLE_PROJECT_ID}" "${GOOGLE_PROJECT_REGION}"
if gcloud kms keyrings describe "${KMS_KEYRING}" --project="${GOOGLE_PROJECT_ID}" \
  --location="${GOOGLE_PROJECT_REGION}" --format=none 2>&1 | tee "${describe_output_file}"; then
  printf 'KMS keyring %s already exists.\n' "${KMS_KEYRING}"
elif grep -Fq 'NOT_FOUND' "${describe_output_file}" &&
  grep -Fq "${KMS_KEYRING}" "${describe_output_file}"; then
  printf 'Creating KMS keyring %s...\n' "${KMS_KEYRING}"
  gcloud kms keyrings create "${KMS_KEYRING}" --project="${GOOGLE_PROJECT_ID}" \
    --location="${GOOGLE_PROJECT_REGION}"
else
  exit 1
fi
