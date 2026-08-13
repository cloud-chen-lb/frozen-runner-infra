#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

[[ "${MYSQL_VERSION}" == MYSQL_8_0 && "${MYSQL_EDITION}" == ENTERPRISE &&
  "${MYSQL_CPU}" =~ ^[0-9]+$ && "${MYSQL_MEMORY_MB}" =~ ^[0-9]+$ &&
  "${MYSQL_STORAGE_GB}" =~ ^[0-9]+$ && "${MYSQL_NETWORK_NAME}" == frozen-runner-vpc ]] || {
  printf 'Invalid MySQL instance configuration\n' >&2
  exit 1
}

if gcloud sql instances describe "${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  private_network="$(gcloud sql instances describe "${MYSQL_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" --format='value(settings.ipConfiguration.privateNetwork)')"
  [[ "${private_network}" == "${MYSQL_NETWORK_NAME}" ||
    "${private_network}" == "projects/${GOOGLE_PROJECT_ID}/global/networks/${MYSQL_NETWORK_NAME}" ]] || {
    printf 'Drift: %s does not match MySQL private network\n' "${MYSQL_INSTANCE_NAME}" >&2
    exit 1
  }
else
  gcloud sql instances create "${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --database-version="${MYSQL_VERSION}" --edition="${MYSQL_EDITION}" --cpu="${MYSQL_CPU}" \
    --memory="${MYSQL_MEMORY_MB}MB" --storage-size="${MYSQL_STORAGE_GB}" \
    --region="${GOOGLE_PROJECT_REGION}" --availability-type=REGIONAL \
    --network="${MYSQL_NETWORK_NAME}" --no-assign-ip --backup-start-time=03:00 \
    --enable-point-in-time-recovery --deletion-protection
fi
