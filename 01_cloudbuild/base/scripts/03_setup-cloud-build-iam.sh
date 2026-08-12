#!/usr/bin/env bash
# 用途：建立共用 Cloud Build service account 並配置建置所需 IAM 權限。
# 流程：確認 cb-share-build 存在，授予 Artifact Registry、Logging、Cloud Build 角色，
# 再允許 Cloud Build service agent 使用該帳號。
# 重要變數：CI_SERVICE_ACCOUNT、GOOGLE_PROJECT_ID、PROJECT_NUMBER。
# 資源影響：建立 service account 並修改專案及帳號 IAM policy；不建立映像檔。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

CI_SERVICE_ACCOUNT="cb-share-build@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud Build service account 是否存在，不修改資源。
if gcloud iam service-accounts describe "$CI_SERVICE_ACCOUNT" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  printf 'CI service account already exists: %s\n' "$CI_SERVICE_ACCOUNT"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增共用 Cloud Build service account。
  gcloud iam service-accounts create cb-share-build \
    --display-name="${PROJECT_NAME} Cloud Build 共用建置服務帳號" \
    --project="$GOOGLE_PROJECT_ID"
  printf 'Created CI service account: %s\n' "$CI_SERVICE_ACCOUNT"
fi

for role in roles/artifactregistry.writer roles/logging.logWriter roles/cloudbuild.builds.builder; do
  # 授權共用 Cloud Build service account 使用 ${GOOGLE_PROJECT_ID} 的建置角色，修改專案 IAM policy。
  gcloud projects add-iam-policy-binding "$GOOGLE_PROJECT_ID" \
    --member="serviceAccount:${CI_SERVICE_ACCOUNT}" \
    --role="$role" \
    --condition=None \
    --project="$GOOGLE_PROJECT_ID" \
    --quiet >/dev/null
  printf 'Granted %s to %s\n' "$role" "$CI_SERVICE_ACCOUNT"
done

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 project number，不修改專案資源。
PROJECT_NUMBER="$(gcloud projects describe "$GOOGLE_PROJECT_ID" --format='value(projectNumber)')"
if [[ -z "$PROJECT_NUMBER" ]]; then
  printf 'Could not resolve project number for %s\n' "$GOOGLE_PROJECT_ID" >&2
  exit 1
fi

CLOUD_BUILD_SERVICE_AGENT="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
# 授權 Cloud Build service agent 使用共用 service account，修改 ${GOOGLE_PROJECT_ID} 的帳號 IAM policy。
gcloud iam service-accounts add-iam-policy-binding "$CI_SERVICE_ACCOUNT" \
  --member="serviceAccount:${CLOUD_BUILD_SERVICE_AGENT}" \
  --role=roles/iam.serviceAccountUser \
  --project="$GOOGLE_PROJECT_ID" \
  --quiet >/dev/null
printf 'Granted roles/iam.serviceAccountUser to %s on %s\n' "$CLOUD_BUILD_SERVICE_AGENT" "$CI_SERVICE_ACCOUNT"
