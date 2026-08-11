#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

CI_SERVICE_ACCOUNT="cb-share-build@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$CI_SERVICE_ACCOUNT" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  printf 'CI service account already exists: %s\n' "$CI_SERVICE_ACCOUNT"
else
  gcloud iam service-accounts create cb-share-build \
    --display-name="${PROJECT_NAME} Cloud Build shared builder" \
    --project="$GOOGLE_PROJECT_ID"
  printf 'Created CI service account: %s\n' "$CI_SERVICE_ACCOUNT"
fi

for role in roles/artifactregistry.writer roles/logging.logWriter roles/cloudbuild.builds.builder; do
  gcloud projects add-iam-policy-binding "$GOOGLE_PROJECT_ID" \
    --member="serviceAccount:${CI_SERVICE_ACCOUNT}" \
    --role="$role" \
    --condition=None \
    --project="$GOOGLE_PROJECT_ID" \
    --quiet >/dev/null
  printf 'Granted %s to %s\n' "$role" "$CI_SERVICE_ACCOUNT"
done

PROJECT_NUMBER="$(gcloud projects describe "$GOOGLE_PROJECT_ID" --format='value(projectNumber)')"
if [[ -z "$PROJECT_NUMBER" ]]; then
  printf 'Could not resolve project number for %s\n' "$GOOGLE_PROJECT_ID" >&2
  exit 1
fi

CLOUD_BUILD_SERVICE_AGENT="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$CI_SERVICE_ACCOUNT" \
  --member="serviceAccount:${CLOUD_BUILD_SERVICE_AGENT}" \
  --role=roles/iam.serviceAccountUser \
  --project="$GOOGLE_PROJECT_ID" \
  --quiet >/dev/null
printf 'Granted roles/iam.serviceAccountUser to %s on %s\n' "$CLOUD_BUILD_SERVICE_AGENT" "$CI_SERVICE_ACCOUNT"
