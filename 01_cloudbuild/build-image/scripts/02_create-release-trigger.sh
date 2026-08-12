#!/usr/bin/env bash
# 用途：建立或驗證 v* tag 觸發的正式映像建置 trigger。
# 流程：組合 repository、app/migration 映像名稱，完整比對既有 trigger 合約後才建立。
# 重要變數：PROJECT_NAME、GOOGLE_PROJECT_REGION、CLOUD_BUILD_*；資源影響：建立 Cloud Build release trigger。
# 安全/驗證限制：既有設定漂移時停止；只接受 v 開頭 tag，映像內容由固定 cloudbuild 設定決定。
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

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 release trigger 是否存在，不修改資源。
if gcloud builds triggers describe "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  # 以下查詢只讀取 ${GOOGLE_PROJECT_ID} 既有 release trigger 的各項設定，不修改資源。
  # 逐項取值是為了在建立前檢查 trigger 是否發生設定漂移。
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

# 在 ${GOOGLE_PROJECT_ID} 新增 tag release Cloud Build trigger。
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
