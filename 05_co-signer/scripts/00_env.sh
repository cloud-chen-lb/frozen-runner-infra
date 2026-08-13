#!/usr/bin/env bash
# 用途：載入 co-signer 所需的全域專案設定與 KMS/VM 資源名稱。
# 流程：載入全域/模組 env，保留全域專案值，驗證必要設定後匯出資源名稱。
# 重要變數：KMS_KEYRING、KMS_CRYPTO_KEY、VM_ZONE、VM_MACHINE_TYPE、VM_VPC_NETWORK、VM_SERVICE_ACCOUNT_EMAIL。
# 資源影響：只載入與驗證設定；目前 VM、KMS 與 service account 值含固定區域/網路假設。
# 安全限制：本檔不含秘密，但 VM 會使用 cloud-platform scope，執行前須確認 service account 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${GLOBAL_ENV_FILE:-${SCRIPT_DIR}/../../global-env/env.sh}"
MODULE_ENV_FILE="${MODULE_ENV_FILE:-${SCRIPT_DIR}/env/env.sh}"

for env_file in "$GLOBAL_ENV_FILE" "$MODULE_ENV_FILE"; do
  if [[ ! -f "$env_file" ]]; then
    printf 'Environment file not found: %s\n' "$env_file" >&2
    return 1 2>/dev/null || exit 1
  fi
done

source "$GLOBAL_ENV_FILE"
GLOBAL_PROJECT_NAME="$PROJECT_NAME"
GLOBAL_GOOGLE_PROJECT_ID="$GOOGLE_PROJECT_ID"
GLOBAL_GOOGLE_PROJECT_REGION="$GOOGLE_PROJECT_REGION"
GLOBAL_EXEC_IAM_ACCOUNT="$EXEC_IAM_ACCOUNT"
source "$MODULE_ENV_FILE"
PROJECT_NAME="$GLOBAL_PROJECT_NAME"
GOOGLE_PROJECT_ID="$GLOBAL_GOOGLE_PROJECT_ID"
GOOGLE_PROJECT_REGION="$GLOBAL_GOOGLE_PROJECT_REGION"
EXEC_IAM_ACCOUNT="$GLOBAL_EXEC_IAM_ACCOUNT"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT \
  ROLE_ID ROLE_TITLE ROLE_DESCRIPTION KMS_KEYRING KMS_CRYPTO_KEY VM_ZONE \
  VM_MACHINE_TYPE VM_VPC_NETWORK VM_NAME VM_STATIC_IP_NAME VM_SERVICE_ACCOUNT_EMAIL; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is not configured\n' "$variable" >&2
    return 1 2>/dev/null || exit 1
  fi
done

# VM 所在的可用區域
VM_ZONE="asia-east1-a"
# VM 使用的機器類型
VM_MACHINE_TYPE="e2-medium"
# VM 使用的 VPC 網路，需與執行服務的 VM 相同
VM_VPC_NETWORK="${PROJECT_NAME}-cosigner-subnet"
# 要建立的 VM 名稱
VM_NAME="${PROJECT_NAME}-cosigner"
# VM 靜態外部 IP 的名稱
VM_STATIC_IP_NAME="${VM_NAME}-ip"
# VM 使用的 Google service account email
VM_SERVICE_ACCOUNT_EMAIL="${PROJECT_NAME}-cosigner-sa@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
export PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT
export ROLE_ID ROLE_TITLE ROLE_DESCRIPTION KMS_KEYRING KMS_CRYPTO_KEY
export VM_ZONE VM_MACHINE_TYPE VM_VPC_NETWORK VM_NAME VM_STATIC_IP_NAME
export VM_SERVICE_ACCOUNT_EMAIL
