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
if ! gcloud sql databases describe "${database_name}" --instance="${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud sql databases create "${database_name}" --instance="${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}"
fi
if ! gcloud sql users describe "${user_name}" --instance="${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  password=''
  if [[ -t 0 ]]; then read -r -s -p 'Merchant MySQL password: ' password < /dev/tty; printf '\n' >&2
  else IFS= read -r password || true; fi
  [[ -n "${password}" && "${password}" != *$'\n'* ]] || { printf 'Password input is required\n' >&2; exit 1; }
  flags_file="$(mktemp)"; chmod 600 "${flags_file}"; trap 'rm -f "${flags_file}"' EXIT
  printf -- "--password: '%s'\n" "${password//\'/\'\'}" >"${flags_file}"
  gcloud sql users create "${user_name}" --instance="${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" --flags-file="${flags_file}"
fi
