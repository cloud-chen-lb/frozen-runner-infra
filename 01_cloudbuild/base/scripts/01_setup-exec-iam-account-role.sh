#!/usr/bin/env bash
# 用途：建立或更新 CloudBuildSetupOperator 自訂 IAM role，並授予執行帳號。
# 流程：載入環境、比對 role 是否存在後 create/update，再套用專案 IAM binding。
# 重要參數：ROLE_ID、ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT。
# 資源影響：修改專案自訂 role 與專案 IAM policy；需具備 IAM 管理權限，權限清單是安全邊界。

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

ROLE_ID="CloudBuildSetupOperator"
ROLE_TITLE="Cloud Build 設定操作員"
ROLE_DESCRIPTION="佈建及操作 Cloud Build 建置流程所需的權限"
ROLE_PERMISSIONS="\
 cloudbuild.builds.create,\
 cloudbuild.connections.create,\
 cloudbuild.connections.get,\
 cloudbuild.repositories.create,\
 cloudbuild.repositories.get,\
 artifactregistry.dockerimages.get,\
 artifactregistry.repositories.create,\
 artifactregistry.repositories.get,\
 iam.roles.create,\
 iam.serviceAccounts.create,\
 iam.serviceAccounts.get,\
 iam.serviceAccounts.getIamPolicy,\
 iam.serviceAccounts.setIamPolicy,\
 resourcemanager.projects.get,\
 resourcemanager.projects.getIamPolicy,\
 resourcemanager.projects.setIamPolicy,\
 serviceusage.services.enable,\
 serviceusage.services.list"

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的自訂 role 是否存在，不修改資源。
 if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 更新 ${GOOGLE_PROJECT_ID} 的 Cloud Build 自訂 role。
  gcloud iam roles update "${ROLE_ID}" \
    --project="${GOOGLE_PROJECT_ID}" \
    --title="${ROLE_TITLE}" \
    --description="${ROLE_DESCRIPTION}" \
    --stage="GA" \
    --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Cloud Build 自訂 role。
  gcloud iam roles create "${ROLE_ID}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="${ROLE_TITLE}" \
  --description="${ROLE_DESCRIPTION}" \
  --stage="GA" \
  --permissions="${ROLE_PERMISSIONS}"
fi

# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的自訂 role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"

printf 'Granted projects/%s/roles/%s to user:%s.\n' \
  "${GOOGLE_PROJECT_ID}" "${ROLE_ID}" "${EXEC_IAM_ACCOUNT}"
