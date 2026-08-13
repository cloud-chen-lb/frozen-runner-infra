#!/usr/bin/env bash
# 用途：移除 SafeheronCoSignerBuilderRole 對執行帳號的授權。
# 流程：載入環境後移除單一專案 IAM binding；不刪除 KMS、service account、VM 或 role。
# 重要變數：GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT、ROLE_ID；移除後 co-signer 建置腳本會失去權限。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
# 從 ${GOOGLE_PROJECT_ID} 移除執行帳號的 co-signer role binding，修改專案 IAM policy。
gcloud projects remove-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
