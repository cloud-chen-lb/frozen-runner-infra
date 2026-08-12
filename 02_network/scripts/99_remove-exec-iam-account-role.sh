#!/usr/bin/env bash
# 用途：移除 NetworkProvisioningOperator 對執行帳號的專案授權。
# 流程：載入網路環境後移除單一 IAM binding；不刪除 role 或網路資源。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；移除後網路建立腳本將失去所需權限。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="NetworkProvisioningOperator"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的網路 role binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
