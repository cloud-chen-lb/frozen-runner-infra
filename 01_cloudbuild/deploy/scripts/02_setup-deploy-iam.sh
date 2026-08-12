#!/usr/bin/env bash
# 用途：建立正式部署 service account 並授予執行 Cloud Run/讀取映像/模擬 runtime 帳號的權限。
# 流程：驗證 deploy 帳號名稱與 display name，建立或檢查後套用三類 IAM binding。
# 重要變數：DEPLOY_SERVICE_ACCOUNT_NAME、APP_SERVICE_ACCOUNT_NAME、MIGRATION_SERVICE_ACCOUNT_NAME。
# 資源影響：建立 service account、修改專案/registry/帳號 IAM；display name 漂移時停止不覆蓋。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

deploy_name="${DEPLOY_SERVICE_ACCOUNT_NAME}"
deploy_email="${deploy_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
for variable in deploy_name deploy_email; do
  [[ -n "${!variable}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 deploy service account display name，不修改資源。
if display_name="$(gcloud iam service-accounts describe "${deploy_email}" \
  --project="${GOOGLE_PROJECT_ID}" --format='value(displayName)' 2>/dev/null)"; then
    [[ "${display_name}" == "${PROJECT_NAME} 正式環境部署" ]] || {
    printf 'Drift: %s display name is %s\n' "${deploy_name}" "${display_name}" >&2
    exit 1
  }
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 production deploy service account。
  gcloud iam service-accounts create "${deploy_name}" \
    --display-name="${PROJECT_NAME} 正式環境部署" --project="${GOOGLE_PROJECT_ID}"
fi

# 授權 deploy service account 在 ${GOOGLE_PROJECT_ID} 管理 Cloud Run，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/run.admin"
# 授權 deploy service account 讀取 ${GOOGLE_PROJECT_ID} 的 Artifact Registry repository，修改 repository IAM policy。
gcloud artifacts repositories add-iam-policy-binding "${PROJECT_NAME}-container-repository" \
  --location="${GOOGLE_PROJECT_REGION}" \
  --member="serviceAccount:${deploy_email}" --role="roles/artifactregistry.reader" \
  --project="${GOOGLE_PROJECT_ID}"
for runtime_name in "${APP_SERVICE_ACCOUNT_NAME}" "${MIGRATION_SERVICE_ACCOUNT_NAME}"; do
  # 授權 deploy service account 模擬 runtime service account，修改 ${GOOGLE_PROJECT_ID} 的帳號 IAM policy。
  gcloud iam service-accounts add-iam-policy-binding \
    "${runtime_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
    --member="serviceAccount:${deploy_email}" \
    --role="roles/iam.serviceAccountUser" --project="${GOOGLE_PROJECT_ID}"
done
