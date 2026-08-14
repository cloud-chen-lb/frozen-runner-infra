#!/usr/bin/env bash
# 用途：建立正式部署 service account 並授予執行 Cloud Run/寫入 Cloud Logging/讀取映像/模擬 runtime 帳號的權限。
# 流程：驗證 deploy 帳號名稱，建立或檢查後套用專案與 service account IAM binding。
# 重要變數：DEPLOY_SERVICE_ACCOUNT_NAME、APP_SERVICE_ACCOUNT_NAME、MIGRATION_SERVICE_ACCOUNT_NAME。
# 資源影響：建立 service account、修改專案/registry/帳號 IAM。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

deploy_display_name="${PROJECT_NAME} production deploy"
deploy_name="${DEPLOY_SERVICE_ACCOUNT_NAME}"
deploy_email="${deploy_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
for variable in deploy_name deploy_email; do
  [[ -n "${!variable}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 deploy service account 是否存在，不修改資源。
if ! gcloud iam service-accounts describe "${deploy_email}" \
  --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 在 ${GOOGLE_PROJECT_ID} 新增 production deploy service account。
  gcloud iam service-accounts create "${deploy_name}" \
    --display-name="${deploy_display_name}" --project="${GOOGLE_PROJECT_ID}"
fi

# 授權 deploy service account 在 ${GOOGLE_PROJECT_ID} 管理 Cloud Run，修改專案 IAM policy。
for role in roles/run.admin roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
    --member="serviceAccount:${deploy_email}" --role="${role}" --condition=None
done
# 授權執行帳號在 ${GOOGLE_PROJECT_ID} 使用 deploy service account，修改帳號 IAM policy。
gcloud iam service-accounts add-iam-policy-binding "${deploy_email}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="roles/iam.serviceAccountUser" --condition=None --project="${GOOGLE_PROJECT_ID}"
for runtime_name in "${APP_SERVICE_ACCOUNT_NAME}" "${MIGRATION_SERVICE_ACCOUNT_NAME}"; do
  # 授權 deploy service account 模擬 runtime service account，修改 ${GOOGLE_PROJECT_ID} 的帳號 IAM policy。
  gcloud iam service-accounts add-iam-policy-binding \
    "${runtime_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
    --member="serviceAccount:${deploy_email}" \
    --role="roles/iam.serviceAccountUser" --project="${GOOGLE_PROJECT_ID}"
done
