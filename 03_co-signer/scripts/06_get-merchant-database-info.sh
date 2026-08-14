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

database_name="cosigner_${MERCHANT_SLUG//-/_}"
user_name="${database_name}_user"
private_ip="$(gcloud sql instances describe "${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" \
  --format='value(ipAddresses[?type="PRIVATE"].ipAddress)')"

printf 'DATABASE_USER_NAME=%s\nDATABASE_PRIVATE_IP=%s\n' "${user_name}" "${private_ip}"
