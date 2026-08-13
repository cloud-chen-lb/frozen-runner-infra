# Safeheron co-signer 設定；本檔只包含非秘密的資源名稱與規格。
# 這些值供 00_env.sh 驗證並供 IAM、KMS、VM 腳本使用。
ROLE_ID="SafeheronCoSignerBuilderRole"
ROLE_TITLE="Safeheron Co-Signer 建置操作員"
ROLE_DESCRIPTION="建立 Safeheron Co-Signer 服務所需的權限"

KMS_KEYRING="${PROJECT_NAME}-cosigner-keyring"
KMS_CRYPTO_KEY="${PROJECT_NAME}-cosigner-key"

VM_ZONE="asia-east1-a"
VM_MACHINE_TYPE="e2-medium"
VM_VPC_NETWORK="default"
VM_NAME="${PROJECT_NAME}-cosigner"
VM_STATIC_IP_NAME="${VM_NAME}-ip"
VM_SERVICE_ACCOUNT_EMAIL="${PROJECT_NAME}-cosigner-sa@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
