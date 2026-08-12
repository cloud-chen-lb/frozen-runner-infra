#!/usr/bin/env bash
# 用途：建立 Safeheron co-signer 建置用自訂 IAM role 並授予執行帳號。
# 流程：載入環境，建立 role 後將固定 KMS、Compute、service account 與 Cloud SQL 權限綁定。
# 重要變數：ROLE_ID、ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與專案 IAM policy。
# 安全限制：腳本未做既有 role 的 drift/idempotency 檢查，重跑可能因 role 已存在失敗，需人工確認。

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 在 ${GOOGLE_PROJECT_ID} 新增 co-signer 自訂 IAM role。
gcloud iam roles create "${ROLE_ID}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="${ROLE_TITLE}" \
  --description="${ROLE_DESCRIPTION}" \
  --stage="GA" \
  --permissions="\
cloudkms.keyRings.create,\
cloudkms.keyRings.get,\
cloudkms.keyRings.list,\
cloudkms.cryptoKeys.create,\
cloudkms.cryptoKeys.get,\
cloudkms.cryptoKeys.list,\
cloudkms.cryptoKeys.getIamPolicy,\
cloudkms.cryptoKeys.setIamPolicy,\
iam.serviceAccounts.create,\
iam.serviceAccounts.actAs,\
iam.serviceAccounts.get,\
iam.serviceAccounts.list,\
compute.instances.create,\
compute.instances.get,\
compute.instances.list,\
compute.instances.setMetadata,\
compute.instances.setServiceAccount,\
compute.disks.create,\
compute.addresses.create,\
compute.addresses.get,\
compute.addresses.use,\
compute.subnetworks.use,\
compute.subnetworks.useExternalIp,\
cloudsql.instances.create,\
cloudsql.instances.get,\
cloudsql.instances.list,\
cloudsql.databases.create,\
cloudsql.databases.get,\
cloudsql.databases.list,\
resourcemanager.projects.get"

# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的 co-signer role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"

echo "Granted projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID} to user:${EXEC_IAM_ACCOUNT}."
