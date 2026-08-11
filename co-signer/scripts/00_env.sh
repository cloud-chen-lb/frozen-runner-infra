#!/usr/bin/env bash

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
ROLE_TITLE="Safeheron Co-Signer Builder"

# KMS key ring 名稱
KMS_KEYRING="${PROJECT_NAME}-cosigner-keyring"
# KMS crypto key 名稱
KMS_CRYPTO_KEY="${PROJECT_NAME}-cosigner-key"

# VM 所在的可用區域
VM_ZONE="asia-east1-a"
# VM 使用的機器類型
VM_MACHINE_TYPE="e2-medium"
# VM 使用的 VPC 網路，需與執行服務的 VM 相同
VM_VPC_NETWORK="default"
# 要建立的 VM 名稱
VM_NAME="${PROJECT_NAME}-cosigner"
# VM 靜態外部 IP 的名稱
VM_STATIC_IP_NAME="${VM_NAME}-ip"
# VM 使用的 Google service account email
VM_SERVICE_ACCOUNT_EMAIL="${PROJECT_NAME}-cosigner-sa@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
