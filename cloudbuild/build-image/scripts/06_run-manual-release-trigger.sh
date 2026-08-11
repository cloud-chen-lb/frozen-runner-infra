#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s v<release> BRANCH\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 2 || ! "$1" =~ ^v.+$ || -z "$2" ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/../../base/scripts/00_env.sh"

TRIGGER_NAME="${PROJECT_NAME}-manual-release-build-trigger"
SOURCE_BRANCH="$2"

gcloud builds triggers run "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" \
  --branch="$SOURCE_BRANCH" --substitutions="_IMAGE_TAG=$1"
