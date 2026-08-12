#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

APIS=(
  artifactregistry.googleapis.com
  cloudbuild.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  logging.googleapis.com
)

for api in "${APIS[@]}"; do
  enabled_api="$(gcloud services list \
    --enabled \
    --project="$GOOGLE_PROJECT_ID" \
    --filter="config.name=$api" \
    --format='value(config.name)')"
  if [[ "$enabled_api" == "$api" ]]; then
    printf 'API already enabled: %s\n' "$api"
  else
    gcloud services enable "$api" --project="$GOOGLE_PROJECT_ID"
    printf 'Enabled API: %s\n' "$api"
  fi
done
