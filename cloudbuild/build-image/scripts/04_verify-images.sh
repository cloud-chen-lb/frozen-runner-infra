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
REPOSITORY_NAME="${PROJECT_NAME}-container-repository"

for image in "${PROJECT_NAME}-app" "${PROJECT_NAME}-migration"; do
  IMAGE_URI="${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}/${image}:$1"
  gcloud artifacts docker images describe "$IMAGE_URI" \
    --project="$GOOGLE_PROJECT_ID" \
    --format='value(image_summary.digest)'
  printf 'Verified image: %s\n' "$IMAGE_URI"
done
