#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

[[ "$#" -eq 1 && "$1" =~ ^v[0-9A-Za-z._-]+$ ]] || {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
  exit 1
}
for variable in GOOGLE_PROJECT_REGION APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING; do
  [[ -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
  [[ "${!variable}" != *';'* ]] || { printf '%s contains forbidden delimiter\n' "${variable}" >&2; exit 1; }
  [[ "${!variable}" != *$'\n'* ]] || { printf '%s contains forbidden newline\n' "${variable}" >&2; exit 1; }
done

gcloud builds triggers run "${PRODUCTION_TRIGGER_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
  --branch="${CLOUD_BUILD_SOURCE_BRANCH}" \
  --substitutions="^;^_IMAGE_TAG=$1;_REGION=${GOOGLE_PROJECT_REGION};_APP_VPC_ARGS=${APP_VPC_ARGS};_MIGRATION_VPC_ARGS=${MIGRATION_VPC_ARGS};_APP_SECRET_MAPPING=${APP_SECRET_MAPPING};_MIGRATION_SECRET_MAPPING=${MIGRATION_SECRET_MAPPING}"
