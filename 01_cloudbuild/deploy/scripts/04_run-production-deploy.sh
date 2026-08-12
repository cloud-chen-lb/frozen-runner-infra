#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

IMAGE_TAG="${_IMAGE_TAG:-}"
for argument in "$@"; do
  case "$argument" in
    v[0-9A-Za-z._-]*) [[ -z "$IMAGE_TAG" ]] || { printf 'duplicate image tag\n' >&2; exit 1; }; IMAGE_TAG="$argument";;
    --_IMAGE_TAG=*) IMAGE_TAG="${argument#*=}";;
    --_APP_SECRET_MAPPING=*) APP_SECRET_MAPPING="${argument#*=}";;
    --_MIGRATION_SECRET_MAPPING=*) MIGRATION_SECRET_MAPPING="${argument#*=}";;
    --_APP_RUNTIME_ENV_VARS=*) APP_RUNTIME_ENV_VARS="${argument#*=}";;
    --_MIGRATION_RUNTIME_ENV_VARS=*) MIGRATION_RUNTIME_ENV_VARS="${argument#*=}";;
    *) printf 'Usage: %s v<release> [--_KEY=value]\n' "${BASH_SOURCE[0]}" >&2; exit 1;;
  esac
done

validate_secret_mapping() {
  local variable="$1" mapping="$2" item key
  [[ "$mapping" != *,*,,* && "$mapping" != ,* && "$mapping" != *, ]] || {
    printf '%s contains an empty secret mapping item\n' "$variable" >&2
    return 1
  }
  IFS=',' read -r -a items <<<"$mapping"
  for item in "${items[@]}"; do
    [[ "$item" =~ ^([A-Z][A-Z0-9_]*)=[a-zA-Z0-9_-]{1,255}:[a-zA-Z0-9_-]+$ ]] || {
      printf '%s contains an invalid secret mapping\n' "$variable" >&2
      return 1
    }
    key="${BASH_REMATCH[1]}"
    case "$variable:$key" in
      APP_SECRET_MAPPING:APP_INTERNAL_ADMIN_PASSWORD|\
      APP_SECRET_MAPPING:APP_ALERT_API_BEARER_TOKEN|\
      APP_SECRET_MAPPING:APP_DATA_ENCRYPTION_SECRET|\
      APP_SECRET_MAPPING:APP_DATABASE_URL|\
      APP_SECRET_MAPPING:APP_MAILGUN_API_KEY|\
      MIGRATION_SECRET_MAPPING:APP_DATABASE_URL) ;;
      *)
        printf '%s contains an unauthorized secret key\n' "$variable" >&2
        return 1
        ;;
    esac
  done
}

for variable in IMAGE_TAG GOOGLE_PROJECT_REGION APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING APP_RUNTIME_ENV_VARS MIGRATION_RUNTIME_ENV_VARS; do
  [[ "${variable}" == MIGRATION_RUNTIME_ENV_VARS || -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
  [[ "${!variable}" != *';'* ]] || { printf '%s contains forbidden delimiter\n' "${variable}" >&2; exit 1; }
  [[ "${!variable}" != *$'\n'* ]] || { printf '%s contains forbidden newline\n' "${variable}" >&2; exit 1; }
done
validate_secret_mapping APP_SECRET_MAPPING "$APP_SECRET_MAPPING"
validate_secret_mapping MIGRATION_SECRET_MAPPING "$MIGRATION_SECRET_MAPPING"

gcloud builds triggers run "${PRODUCTION_TRIGGER_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
  --branch="${CLOUD_BUILD_SOURCE_BRANCH}" \
  --substitutions="^;^_IMAGE_TAG=${IMAGE_TAG};_REGION=${GOOGLE_PROJECT_REGION};_APP_VPC_ARGS=${APP_VPC_ARGS};_MIGRATION_VPC_ARGS=${MIGRATION_VPC_ARGS};_APP_SECRET_MAPPING=${APP_SECRET_MAPPING};_MIGRATION_SECRET_MAPPING=${MIGRATION_SECRET_MAPPING};_APP_RUNTIME_ENV_VARS=${APP_RUNTIME_ENV_VARS};_MIGRATION_RUNTIME_ENV_VARS=${MIGRATION_RUNTIME_ENV_VARS}"
