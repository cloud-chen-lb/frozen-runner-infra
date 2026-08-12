#!/usr/bin/env bash
# 用途：移除 CloudBuildSetupOperator 專案自訂 role 對執行帳號的授權。
# 流程：載入全域環境後執行單一 remove-iam-policy-binding。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；資源影響：只修改 IAM binding，不刪除 role 或其他資源。
# 安全限制：需確認目前 gcloud 專案與帳號，移除後相關建立腳本將無法執行。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="CloudBuildSetupOperator"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的自訂 role binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
