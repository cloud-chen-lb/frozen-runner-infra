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

TRIGGER_NAME="${PROJECT_NAME}-ci-trigger"
SOURCE_BRANCH="${CLOUD_BUILD_SOURCE_BRANCH:-master}"
TRIGGER_DESCRIPTION="驗證以 master 為目標分支的 Pull Request，使用正式環境 CI Cloud Build 設定。"

escape_re2() {
  local value="$1"
  local escaped=""
  local character

  while [[ -n "$value" ]]; do
    character="${value:0:1}"
    value="${value:1}"
    case "$character" in
      \\|'.'|'^'|'$'|'*'|'+'|'?'|'('|')'|'{'|'}'|'['|']'|'|')
        escaped+="\\${character}"
        ;;
      *)
        escaped+="$character"
        ;;
    esac
  done

  printf '%s' "$escaped"
}

SOURCE_BRANCH_PATTERN="$(escape_re2 "$SOURCE_BRANCH")"
REPOSITORY_RESOURCE="projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_PROJECT_REGION}/connections/${CLOUD_BUILD_CONNECTION_NAME}/repositories/${CLOUD_BUILD_REPOSITORY_NAME}"
SERVICE_ACCOUNT="projects/${GOOGLE_PROJECT_ID}/serviceAccounts/cb-share-build@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

if gcloud builds triggers describe "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  EXISTING_REPOSITORY="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.repository)')"
  EXISTING_BRANCH_PATTERN="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.pullRequest.branch)')"
  EXISTING_BUILD_CONFIG="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(filename)')"
  EXISTING_SERVICE_ACCOUNT="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(serviceAccount)')"
  EXISTING_REGION="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(location)')"
  EXISTING_DESCRIPTION="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(description)')"

  if [[ "$EXISTING_REPOSITORY" != "$REPOSITORY_RESOURCE" ||
    "$EXISTING_BRANCH_PATTERN" != "^${SOURCE_BRANCH_PATTERN}$" ||
    "$EXISTING_BUILD_CONFIG" != 'cicd/prod/cloudbuild-ci.yaml' ||
    "$EXISTING_SERVICE_ACCOUNT" != "$SERVICE_ACCOUNT" ||
    "$EXISTING_REGION" != "$GOOGLE_PROJECT_REGION" ||
    "$EXISTING_DESCRIPTION" != "$TRIGGER_DESCRIPTION" ]]; then
    printf 'CI trigger drift detected: %s\n' "$TRIGGER_NAME" >&2
    exit 1
  fi
  printf 'CI trigger already matches configuration: %s\n' "$TRIGGER_NAME"
  exit 0
fi

gcloud builds triggers create github \
  --name="$TRIGGER_NAME" \
  --repository="$REPOSITORY_RESOURCE" \
  --pull-request-pattern="^${SOURCE_BRANCH_PATTERN}$" \
  --description="$TRIGGER_DESCRIPTION" \
  --build-config='cicd/prod/cloudbuild-ci.yaml' \
  --region="$GOOGLE_PROJECT_REGION" \
  --project="$GOOGLE_PROJECT_ID" \
  --service-account="$SERVICE_ACCOUNT"
printf 'Created CI trigger: %s\n' "$TRIGGER_NAME"
