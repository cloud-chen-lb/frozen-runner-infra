#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${SCRIPT_DIR}/../../../global-env/env.sh"
BASE_ENV_FILE="${SCRIPT_DIR}/env/env.sh"

for env_file in "$GLOBAL_ENV_FILE" "$BASE_ENV_FILE"; do
  if [[ ! -f "$env_file" ]]; then
    printf 'Environment file not found: %s\n' "$env_file" >&2
    return 1 2>/dev/null || exit 1
  fi
  source "$env_file"
done

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured in %s\n' "$variable" "$GLOBAL_ENV_FILE" >&2
    return 1 2>/dev/null || exit 1
  fi
done

export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export CLOUD_BUILD_CONNECTION_NAME CLOUD_BUILD_REPOSITORY_NAME
