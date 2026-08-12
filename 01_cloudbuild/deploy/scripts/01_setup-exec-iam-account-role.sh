#!/usr/bin/env bash
# 用途：建立或更新正式部署流程所需的 CloudBuildDeployProvisioningOperator role。
# 流程：載入部署環境，依 role 是否存在執行 update/create，再授予執行帳號。
# 重要變數：ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改自訂 role 與專案 IAM policy。
# 安全限制：權限範圍由固定清單決定，執行者仍需有 IAM 管理權限。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="CloudBuildDeployProvisioningOperator"
ROLE_TITLE="Cloud Build 部署佈建操作員"
ROLE_DESCRIPTION="佈建正式環境部署流程所需的權限"
ROLE_PERMISSIONS="cloudbuild.builds.create,cloudbuild.triggers.create,cloudbuild.triggers.get,cloudbuild.triggers.list,cloudbuild.triggers.update,run.services.get,run.services.list,run.services.update,run.jobs.get,run.jobs.list,run.jobs.update,artifactregistry.repositories.get,artifactregistry.repositories.list,artifactregistry.dockerimages.get,artifactregistry.dockerimages.list,iam.serviceAccounts.get,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的部署自訂 role 是否存在，不修改資源。
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 更新 ${GOOGLE_PROJECT_ID} 的部署自訂 role。
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增部署自訂 role。
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的部署自訂 role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
