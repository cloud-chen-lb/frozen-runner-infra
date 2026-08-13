#!/usr/bin/env bash
# 用途：載入 co-signer 所需的全域專案設定與 KMS/VM 資源名稱。
# 流程：檢查全域 env 存在並驗證四個必要變數，再設定 KMS key ring、crypto key 與 VM 參數。
# 重要變數：KMS_KEYRING、KMS_CRYPTO_KEY、VM_ZONE、VM_MACHINE_TYPE、VM_VPC_NETWORK、VM_SERVICE_ACCOUNT_EMAIL。
# 資源影響：只載入設定，不建立資源；目前 VM、KMS 與 service account 值含固定區域/網路假設。
# 安全限制：本檔不含秘密，但 VM 會使用 cloud-platform scope，執行前須確認 service account 權限。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_ENV_FILE="${SCRIPT_DIR}/../../global-env/env.sh"

if [[ ! -f "$GLOBAL_ENV_FILE" ]]; then
  echo "Global environment file not found: $GLOBAL_ENV_FILE" >&2
  exit 1
fi

source "$GLOBAL_ENV_FILE"

for variable in PROJECT_NAME GOOGLE_PROJECT_ID GOOGLE_PROJECT_REGION EXEC_IAM_ACCOUNT; do
  if [[ -z "${!variable:-}" ]]; then
    echo "${variable} is not configured in $GLOBAL_ENV_FILE" >&2
    exit 1
  fi
done

# 自訂 IAM role 的識別名稱
ROLE_ID="SafeheronCoSignerBuilderRole"
# 自訂 IAM role 在 GCP 顯示的名稱
ROLE_TITLE="Safeheron Co-Signer 建置操作員"
ROLE_DESCRIPTION="建立 Safeheron Co-Signer 服務所需的權限"

# KMS key ring 名稱
KMS_KEYRING="${PROJECT_NAME}-cosigner-keyring"
# KMS crypto key 名稱
KMS_CRYPTO_KEY="${PROJECT_NAME}-cosigner-key"

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
