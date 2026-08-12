#!/usr/bin/env bash
#!/usr/bin/env bash

# 用途：移除 CloudBuildDeployProvisioningOperator 對執行帳號的專案授權。
# 流程：載入 Cloud Build deploy 環境後移除單一 IAM policy binding。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；移除後 deploy provisioning 腳本將失去權限。
# 資源影響：只修改指定專案的 IAM policy，不刪除自訂 role、trigger 或部署資源。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
deploy_email="${DEPLOY_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
ROLE_ID="CloudBuildDeployProvisioningOperator"
# 從 deploy service account 移除執行帳號的 serviceAccountUser binding，修改帳號 IAM policy。
gcloud iam service-accounts remove-iam-policy-binding "${deploy_email}" \
  --member="user:${EXEC_IAM_ACCOUNT}" --role="roles/iam.serviceAccountUser" \
  --condition=None --project="${GOOGLE_PROJECT_ID}"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的部署 role binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
