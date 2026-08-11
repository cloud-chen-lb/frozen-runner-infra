#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 1 || ! "$1" =~ ^v.+$ ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/../../base/scripts/00_env.sh"
TRIGGER_NAME="${PROJECT_NAME}-release-build-trigger"

gcloud builds triggers run "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --tag="$1"
