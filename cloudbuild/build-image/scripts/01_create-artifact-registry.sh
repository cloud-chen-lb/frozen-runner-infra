#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 0 ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/../../base/scripts/00_env.sh"

REPOSITORY_NAME="${PROJECT_NAME}-container-repository"
if gcloud artifacts repositories describe "$REPOSITORY_NAME" \
  --location="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  printf 'Artifact Registry repository already exists: %s\n' \
    "${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}"
else
  gcloud artifacts repositories create "$REPOSITORY_NAME" \
    --repository-format=docker \
    --location="$GOOGLE_PROJECT_REGION" \
    --project="$GOOGLE_PROJECT_ID"
  printf 'Created Artifact Registry repository: %s\n' \
    "${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}"
fi
