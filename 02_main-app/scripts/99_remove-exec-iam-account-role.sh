#!/usr/bin/env bash
# 用途：移除 CloudSQLProvisioningOperator 對執行帳號的授權。
# 流程：載入 Cloud SQL 環境後移除單一專案 IAM binding；不刪除資料庫、使用者或 role。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；移除後 provisioning 腳本將無法操作 Cloud SQL。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="MainAppProvisioningOperator"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的 Cloud SQL role binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
