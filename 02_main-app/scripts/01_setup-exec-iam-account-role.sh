#!/usr/bin/env bash
# 用途：建立或更新 CloudSQLProvisioningOperator 自訂 role 並授予執行帳號。
# 流程：載入設定，依 role 是否存在執行 create/update，再套用專案 IAM binding。
# 重要變數：ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與 IAM policy。
# 安全限制：權限固定涵蓋 Cloud SQL 建立/使用者管理，不包含密碼內容。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="MainAppProvisioningOperator"
ROLE_TITLE="Main app 佈建操作員"
ROLE_DESCRIPTION="佈建主應用程式與部署流程所需的權限"
ROLE_PERMISSIONS="cloudbuild.builds.create,cloudbuild.builds.get,cloudbuild.builds.list,cloudbuild.builds.update,cloudbuild.connections.create,cloudbuild.connections.get,cloudbuild.repositories.create,cloudbuild.repositories.get,cloudbuild.triggers.create,cloudbuild.triggers.get,cloudbuild.triggers.list,cloudbuild.triggers.update,artifactregistry.dockerimages.get,artifactregistry.dockerimages.list,artifactregistry.repositories.create,artifactregistry.repositories.get,artifactregistry.repositories.list,cloudsql.instances.create,cloudsql.instances.get,cloudsql.instances.list,cloudsql.instances.update,cloudsql.databases.create,cloudsql.databases.get,cloudsql.databases.list,cloudsql.users.create,cloudsql.users.get,cloudsql.users.list,cloudsql.users.update,compute.addresses.create,compute.addresses.get,compute.addresses.list,compute.addresses.use,compute.subnetworks.create,compute.subnetworks.get,compute.subnetworks.list,compute.subnetworks.use,compute.routers.create,compute.routers.get,compute.routers.list,compute.routers.update,compute.routers.nats.create,compute.routers.nats.get,compute.routers.nats.update,iam.roles.create,iam.serviceAccounts.create,iam.serviceAccounts.get,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy,secretmanager.secrets.create,secretmanager.secrets.get,secretmanager.secrets.list,secretmanager.secrets.getIamPolicy,secretmanager.secrets.setIamPolicy,secretmanager.versions.add,run.services.get,run.services.list,run.services.update,run.jobs.get,run.jobs.list,run.jobs.update,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy,serviceusage.services.enable,serviceusage.services.list"
# 查詢 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role 狀態；deleted role 先恢復再更新。
# 查詢 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role 是否存在及已刪除狀態，不修改資源。
if role_deleted="$(gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --format="value(deleted)" 2>/dev/null)"; then
  if [[ "${role_deleted}" == "True" ]]; then
    # 在 ${GOOGLE_PROJECT_ID} 恢復已刪除的 Cloud SQL 自訂 role。
    gcloud iam roles undelete "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}"
  fi
  # 更新 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role。
  # 在 ${GOOGLE_PROJECT_ID} 更新 Cloud SQL 自訂 role 權限。
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Cloud SQL 自訂 role。
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
