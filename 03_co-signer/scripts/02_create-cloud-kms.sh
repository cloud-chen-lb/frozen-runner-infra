#!/usr/bin/env bash
# 用途：建立 co-signer KMS key ring、crypto key 與相關 service account 權限。
# 流程：以區域建立 key ring/key，建立固定名稱 service account，再授予 VM service account 加解密權。
# 重要變數：KMS_KEYRING、KMS_CRYPTO_KEY、GOOGLE_PROJECT_REGION、VM_SERVICE_ACCOUNT_EMAIL。
# 資源影響：建立 KMS/service account 並修改 crypto key IAM policy；重跑可能因既有資源失敗。
# 安全限制：只授予指定 VM service account 加解密角色，仍須確認 VM email 與專案正確。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 在 ${GOOGLE_PROJECT_ID} 新增指定區域的 KMS key ring。
gcloud kms keyrings create "$KMS_KEYRING" \
   --location "$GOOGLE_PROJECT_REGION"
# 在 ${GOOGLE_PROJECT_ID} 的 KMS key ring 新增加密 crypto key。
gcloud kms keys create "$KMS_CRYPTO_KEY" \
   --location "$GOOGLE_PROJECT_REGION" \
   --keyring "$KMS_KEYRING" \
   --purpose encryption
# 在 ${GOOGLE_PROJECT_ID} 新增 co-signer service account。
gcloud iam service-accounts create "fr-safeheron-apicosigner-sa" \
   --display-name "Safeheron Co-Signer 執行服務帳號"
# 授權 VM service account 使用 ${GOOGLE_PROJECT_ID} 的 KMS crypto key 加解密，修改 key IAM policy。
gcloud kms keys add-iam-policy-binding "$KMS_CRYPTO_KEY" \
   --location "$GOOGLE_PROJECT_REGION" \
   --keyring "$KMS_KEYRING" \
   --member "serviceAccount:$VM_SERVICE_ACCOUNT_EMAIL" \
   --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"
