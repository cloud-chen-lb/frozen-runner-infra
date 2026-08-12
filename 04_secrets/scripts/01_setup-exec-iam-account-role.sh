#!/usr/bin/env bash
# 用途：建立或更新 SecretManagerProvisioningOperator 自訂 role 並授予執行帳號。
# 流程：載入秘密設定，建立/更新 role 後套用專案 IAM binding。
# 重要變數：ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與 IAM policy。
# 安全限制：權限涵蓋 service account/Secret Manager metadata 管理，不授予讀取秘密值的角色。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="SecretManagerProvisioningOperator"
ROLE_TITLE="Secret Manager 佈建操作員"
ROLE_DESCRIPTION="佈建執行期 service account 與秘密所需的權限"
ROLE_PERMISSIONS="iam.serviceAccounts.create,iam.serviceAccounts.get,iam.serviceAccounts.list,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy,secretmanager.secrets.create,secretmanager.secrets.get,secretmanager.secrets.list,secretmanager.secrets.getIamPolicy,secretmanager.secrets.setIamPolicy,secretmanager.versions.add,run.services.get,run.services.list,run.jobs.get,run.jobs.list,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy,serviceusage.services.enable,serviceusage.services.list"
# 查詢 ${GOOGLE_PROJECT_ID} 的自訂 role 狀態；deleted role 先恢復再更新。
if role_deleted="$(gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --format="value(deleted)" 2>/dev/null)"; then
  if [[ "${role_deleted}" == "True" ]]; then
    gcloud iam roles undelete "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}"
  fi
  # 更新 ${GOOGLE_PROJECT_ID} 中的 Secret Manager provisioning 自訂 role，不改變權限清單以外的行為。
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Secret Manager provisioning 自訂 role。
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的 SecretManagerProvisioningOperator role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
