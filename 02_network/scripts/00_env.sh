#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-${SCRIPT_DIR}/../../global-env/env.sh}"
MODULE_ENV_FILE="${MODULE_ENV_FILE:-${SCRIPT_DIR}/env/env.sh}"

for env_file in "$GLOBAL_ENV_FILE" "$MODULE_ENV_FILE"; do
  if [[ ! -f "$env_file" ]]; then
    printf 'Environment file not found: %s\n' "$env_file" >&2
    return 1 2>/dev/null || exit 1
  fi
done
source "$GLOBAL_ENV_FILE"
GLOBAL_PROJECT_NAME="$PROJECT_NAME"
GLOBAL_GOOGLE_PROJECT_ID="$GOOGLE_PROJECT_ID"
GLOBAL_GOOGLE_PROJECT_REGION="$GOOGLE_PROJECT_REGION"
GLOBAL_EXEC_IAM_ACCOUNT="$EXEC_IAM_ACCOUNT"
source "$MODULE_ENV_FILE"
PROJECT_NAME="$GLOBAL_PROJECT_NAME"
GOOGLE_PROJECT_ID="$GLOBAL_GOOGLE_PROJECT_ID"
GOOGLE_PROJECT_REGION="$GLOBAL_GOOGLE_PROJECT_REGION"
EXEC_IAM_ACCOUNT="$GLOBAL_EXEC_IAM_ACCOUNT"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT \
  MAIN_APP_SUBNET_CIDR PRIVATE_SERVICES_RANGE_CIDR; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

valid_cidr() {
  local cidr octet
  cidr="$1"
  [[ "${cidr}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  IFS=. read -r -a octets <<<"${cidr%/*}"
  for octet in "${octets[@]}"; do (( octet <= 255 )) || return 1; done
  [[ "${cidr#*/}" -ge 1 ]]
}

if [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]] || \
  ! valid_cidr "${MAIN_APP_SUBNET_CIDR}" || ! valid_cidr "${PRIVATE_SERVICES_RANGE_CIDR}"; then
  printf 'Invalid network region or CIDR configuration\n' >&2
  return 1 2>/dev/null || exit 1
fi

export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export MAIN_APP_SUBNET_CIDR PRIVATE_SERVICES_RANGE_CIDR
export NETWORK_NAME MAIN_APP_SUBNET_NAME PRIVATE_SERVICES_RANGE_NAME
export ROUTER_NAME EGRESS_IP_NAME NAT_NAME
