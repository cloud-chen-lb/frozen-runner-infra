#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]]; then
  printf 'Invalid GOOGLE_PROJECT_REGION: %s\n' "${GOOGLE_PROJECT_REGION}" >&2
  exit 1
fi

vpc_description=''
if vpc_description="$(gcloud compute networks describe "${NETWORK_NAME}" --project="${GOOGLE_PROJECT_ID}" 2>/dev/null)"; then
  if ! grep -Eiq 'subnetMode:[[:space:]]*CUSTOM' <<<"${vpc_description}"; then
    printf 'Drift: %s is not a custom-mode VPC\n' "${NETWORK_NAME}" >&2
    exit 1
  fi
else
  gcloud compute networks create "${NETWORK_NAME}" \
    --subnet-mode=custom \
    --project="${GOOGLE_PROJECT_ID}"
fi
