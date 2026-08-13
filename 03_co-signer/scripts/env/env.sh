# 用途：提供 Safeheron co-signer IAM、KMS、VM 與網路資源名稱/規格。
# 流程：由 00_env.sh 載入驗證，供 role、KMS、VM 與 MySQL 腳本使用。
# 重要變數：ROLE_ID、KMS_KEYRING、KMS_CRYPTO_KEY、VM_NAME、VM_SERVICE_ACCOUNT_EMAIL。
# 資源影響：設定會影響 IAM、KMS 與 VM 建立；安全/驗證限制：不含秘密，固定 zone/network 需先確認。
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
