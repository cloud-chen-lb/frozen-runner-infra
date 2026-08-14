#!/usr/bin/env bash
# 用途：建立或驗證 app、migration、deploy 三個 runtime/deploy service account。
# 流程：驗證名稱，建立缺少帳號，並配置 deploy 與 runtime 的最小必要 IAM binding。
# 重要變數：SERVICE_ACCOUNT_NAMES、*_SERVICE_ACCOUNT_NAME、GOOGLE_PROJECT_ID；資源影響：建立帳號與修改 IAM policy。
# 安全/驗證限制：不建立 service account key，也不輸出秘密值。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

declare -a SERVICE_ACCOUNT_NAMES=(
  "${APP_SERVICE_ACCOUNT_NAME}"
  "${MIGRATION_SERVICE_ACCOUNT_NAME}"
  "${DEPLOY_SERVICE_ACCOUNT_NAME}"
)
declare -a SERVICE_ACCOUNT_CREATE_DISPLAY_NAMES=(
  "${PROJECT_NAME} main app runtime"
  "${PROJECT_NAME} database migration runtime"
  "${PROJECT_NAME} production deploy"
)

for service_account_name in "${SERVICE_ACCOUNT_NAMES[@]}"; do
  [[ "${service_account_name}" =~ ^[a-z][a-z0-9-]{5,29}$ ]] || {
    printf 'Invalid service account name: %s\n' "${service_account_name}" >&2
    exit 1
  }
done

for index in "${!SERVICE_ACCOUNT_NAMES[@]}"; do
  service_account_name="${SERVICE_ACCOUNT_NAMES[$index]}"
  expected_display_name="${SERVICE_ACCOUNT_CREATE_DISPLAY_NAMES[$index]}"
  service_account_email="${service_account_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
  # 唯讀查詢 ${GOOGLE_PROJECT_ID} service account 是否存在，不修改資源。
  if ! gcloud iam service-accounts describe "${service_account_email}" \
    --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
    # 在 ${GOOGLE_PROJECT_ID} 新增 runtime/deploy service account。
    gcloud iam service-accounts create "${service_account_name}" \
      --display-name="${expected_display_name}" --project="${GOOGLE_PROJECT_ID}"
  fi
done

deploy_email="${DEPLOY_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
# 授權 deploy service account 在 ${GOOGLE_PROJECT_ID} 管理 Cloud Run，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/run.admin"
# 授權 deploy service account 讀取 ${GOOGLE_PROJECT_ID} 的 Artifact Registry，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/artifactregistry.reader"

for runtime_name in "${APP_SERVICE_ACCOUNT_NAME}" "${MIGRATION_SERVICE_ACCOUNT_NAME}"; do
  runtime_email="${runtime_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
  # 授權 deploy service account 模擬 runtime service account，修改 ${GOOGLE_PROJECT_ID} 的帳號 IAM policy。
  gcloud iam service-accounts add-iam-policy-binding "${runtime_email}" \
    --member="serviceAccount:${deploy_email}" \
    --role="roles/iam.serviceAccountUser" --project="${GOOGLE_PROJECT_ID}"
done
