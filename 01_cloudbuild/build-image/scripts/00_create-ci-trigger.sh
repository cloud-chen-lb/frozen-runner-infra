#!/usr/bin/env bash
# 用途：建立或驗證 Pull Request CI Cloud Build trigger。
# 流程：載入連線設定、將來源分支轉成 RE2、比對既有 trigger 合約，不符即停止。
# 重要變數：CLOUD_BUILD_SOURCE_BRANCH、CLOUD_BUILD_*、TRIGGER_NAME；資源影響：建立 CI trigger。
# 安全/驗證限制：只接受零參數，既有設定漂移時不自動修正；建置設定固定為 cicd/prod/cloudbuild-ci.yaml。
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
TRIGGER_DESCRIPTION="Validate Pull Requests targeting master with the production CI Cloud Build configuration."

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

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 CI trigger，不修改資源。
if gcloud builds triggers describe "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  # 唯讀查詢既有 CI trigger 的 repository 設定，不修改資源。
  EXISTING_REPOSITORY="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.repository)')"
  # 唯讀查詢既有 CI trigger 的分支設定，不修改資源。
  EXISTING_BRANCH_PATTERN="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(repositoryEventConfig.pullRequest.branch)')"
  # 唯讀查詢既有 CI trigger 的 build config，不修改資源。
  EXISTING_BUILD_CONFIG="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(filename)')"
  # 唯讀查詢既有 CI trigger 的 service account，不修改資源。
  EXISTING_SERVICE_ACCOUNT="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(serviceAccount)')"
  # 唯讀查詢既有 CI trigger 的區域，不修改資源。
  EXISTING_REGION="$(gcloud builds triggers describe "$TRIGGER_NAME" --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --format='value(location)')"
  if [[ "$EXISTING_REPOSITORY" != "$REPOSITORY_RESOURCE" ||
    "$EXISTING_BRANCH_PATTERN" != "^${SOURCE_BRANCH_PATTERN}$" ||
    "$EXISTING_BUILD_CONFIG" != 'cicd/prod/cloudbuild-ci.yaml' ||
    "$EXISTING_SERVICE_ACCOUNT" != "$SERVICE_ACCOUNT" ||
    "$EXISTING_REGION" != "$GOOGLE_PROJECT_REGION" ]]; then
    printf 'CI trigger drift detected: %s\n' "$TRIGGER_NAME" >&2
    exit 1
  fi
  printf 'CI trigger already matches configuration: %s\n' "$TRIGGER_NAME"
  exit 0
fi

# 在 ${GOOGLE_PROJECT_ID} 新增 GitHub CI Cloud Build trigger。
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
