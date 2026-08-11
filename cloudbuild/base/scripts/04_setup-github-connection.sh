#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s CONNECTION_NAME REPOSITORY_NAME GITHUB_REMOTE_URI\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 3 ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/00_env.sh"
CONNECTION_NAME="$1"
REPOSITORY_NAME="$2"
REMOTE_URI="$3"

if gcloud builds connections describe "$CONNECTION_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  printf 'Cloud Build connection already exists: %s\n' "$CONNECTION_NAME" >&2
else
  gcloud builds connections create github "$CONNECTION_NAME" \
    --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID"
fi

REPOSITORY_RESOURCE="projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_PROJECT_REGION}/connections/${CONNECTION_NAME}/repositories/${REPOSITORY_NAME}"
if gcloud builds repositories describe "$REPOSITORY_NAME" \
  --connection="$CONNECTION_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  EXISTING_REMOTE_URI="$(gcloud builds repositories describe "$REPOSITORY_NAME" \
    --connection="$CONNECTION_NAME" --region="$GOOGLE_PROJECT_REGION" \
    --project="$GOOGLE_PROJECT_ID" --format='value(remoteUri)')"
  if [[ "$EXISTING_REMOTE_URI" != "$REMOTE_URI" ]]; then
    printf 'Repository remote URI differs: existing=%s requested=%s\n' "$EXISTING_REMOTE_URI" "$REMOTE_URI" >&2
    printf 'Correction command: gcloud builds repositories delete %q --connection=%q --region=%q --project=%q\n' \
      "$REPOSITORY_NAME" "$CONNECTION_NAME" "$GOOGLE_PROJECT_REGION" "$GOOGLE_PROJECT_ID" >&2
    exit 1
  fi
  printf 'Cloud Build repository already exists: %s\n' "$REPOSITORY_RESOURCE" >&2
else
  gcloud builds repositories create "$REPOSITORY_NAME" \
    --remote-uri="$REMOTE_URI" \
    --connection="$REPOSITORY_RESOURCE" \
    --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID"
fi

printf 'CLOUD_BUILD_CONNECTION_NAME=%s\n' "$CONNECTION_NAME"
printf 'CLOUD_BUILD_REPOSITORY_NAME=%s\n' "$REPOSITORY_NAME"
