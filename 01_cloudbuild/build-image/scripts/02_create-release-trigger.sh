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

if [[ -z "${CLOUD_BUILD_CONNECTION_NAME:-}" || -z "${CLOUD_BUILD_REPOSITORY_NAME:-}" ]]; then
  printf 'CLOUD_BUILD_CONNECTION_NAME and CLOUD_BUILD_REPOSITORY_NAME are required\n' >&2
  exit 1
fi

REPOSITORY_NAME="${PROJECT_NAME}-container-repository"
APP_IMAGE="${PROJECT_NAME}-app"
MIGRATION_IMAGE="${PROJECT_NAME}-migration"
TRIGGER_NAME="${PROJECT_NAME}-release-build-trigger"
TRIGGER_DESCRIPTION="當推送符合 v* 的版本標籤時，建置並發布正式環境的 app 與 migration 映像檔。"
REPOSITORY_RESOURCE="projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_PROJECT_REGION}/connections/${CLOUD_BUILD_CONNECTION_NAME}/repositories/${CLOUD_BUILD_REPOSITORY_NAME}"
SERVICE_ACCOUNT="projects/${GOOGLE_PROJECT_ID}/serviceAccounts/cb-share-build@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

if gcloud builds triggers describe "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  EXISTING_REPOSITORY="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.repository)')"
  EXISTING_TAG_PATTERN="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.push.tag)')"
  EXISTING_BUILD_CONFIG="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(filename)')"
  EXISTING_SERVICE_ACCOUNT="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(serviceAccount)')"
  EXISTING_REGION="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(substitutions._REGION)')"
  EXISTING_DESCRIPTION="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(description)')"
  EXISTING_REPOSITORY_NAME="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(substitutions._REPOSITORY)')"
  EXISTING_APP_IMAGE="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(substitutions._APP_IMAGE)')"
  EXISTING_MIGRATION_IMAGE="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(substitutions._MIGRATION_IMAGE)')"

  if [[ "$EXISTING_REPOSITORY" != "$REPOSITORY_RESOURCE" ||
    "$EXISTING_TAG_PATTERN" != '^v.*$' ||
    "$EXISTING_BUILD_CONFIG" != 'cicd/prod/cloudbuild-release.yaml' ||
    "$EXISTING_SERVICE_ACCOUNT" != "$SERVICE_ACCOUNT" ||
    "$EXISTING_REGION" != "$GOOGLE_PROJECT_REGION" ||
    "$EXISTING_REPOSITORY_NAME" != "$REPOSITORY_NAME" ||
    "$EXISTING_APP_IMAGE" != "$APP_IMAGE" ||
    "$EXISTING_MIGRATION_IMAGE" != "$MIGRATION_IMAGE" ||
    "$EXISTING_DESCRIPTION" != "$TRIGGER_DESCRIPTION" ]]; then
    printf 'Release trigger drift detected: %s\n' "$TRIGGER_NAME" >&2
    exit 1
  fi
  printf 'Release trigger already matches configuration: %s\n' "$TRIGGER_NAME"
  exit 0
fi

gcloud builds triggers create github \
  --name="$TRIGGER_NAME" \
  --repository="$REPOSITORY_RESOURCE" \
  --tag-pattern='^v.*$' \
  --description="$TRIGGER_DESCRIPTION" \
  --build-config='cicd/prod/cloudbuild-release.yaml' \
  --region="$GOOGLE_PROJECT_REGION" \
  --project="$GOOGLE_PROJECT_ID" \
  --service-account="$SERVICE_ACCOUNT" \
  --substitutions="_REGION=${GOOGLE_PROJECT_REGION},_REPOSITORY=${REPOSITORY_NAME},_APP_IMAGE=${APP_IMAGE},_MIGRATION_IMAGE=${MIGRATION_IMAGE}"
printf 'Created release trigger: %s\n' "$TRIGGER_NAME"
