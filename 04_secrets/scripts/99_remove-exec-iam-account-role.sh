#!/usr/bin/env bash
# 用途：移除 SecretManagerProvisioningOperator 對執行帳號的授權。
# 流程：載入秘密環境後移除單一 IAM binding；不刪除 service account、secret 或 role。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；移除後秘密 provisioning 腳本將失去權限。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="SecretManagerProvisioningOperator"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的 SecretManagerProvisioningOperator IAM binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
