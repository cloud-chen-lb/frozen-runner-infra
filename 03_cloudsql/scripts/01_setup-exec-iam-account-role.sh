#!/usr/bin/env bash
# 用途：建立或更新 CloudSQLProvisioningOperator 自訂 role 並授予執行帳號。
# 流程：載入設定，依 role 是否存在執行 create/update，再套用專案 IAM binding。
# 重要變數：ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與 IAM policy。
# 安全限制：權限固定涵蓋 Cloud SQL 建立/使用者管理，不包含密碼內容。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="CloudSQLProvisioningOperator"
ROLE_TITLE="Cloud SQL 佈建操作員"
ROLE_DESCRIPTION="佈建主應用程式 PostgreSQL 資料庫所需的權限"
ROLE_PERMISSIONS="cloudsql.instances.create,cloudsql.instances.get,cloudsql.instances.list,cloudsql.instances.update,cloudsql.databases.create,cloudsql.databases.get,cloudsql.databases.list,cloudsql.users.create,cloudsql.users.get,cloudsql.users.list,cloudsql.users.update,serviceusage.services.enable,serviceusage.services.list,resourcemanager.projects.get"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role 是否存在，不修改資源。
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 更新 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role。
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Cloud SQL 自訂 role。
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的 Cloud SQL 自訂 role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
