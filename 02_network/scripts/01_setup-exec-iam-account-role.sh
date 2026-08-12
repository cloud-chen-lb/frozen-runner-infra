#!/usr/bin/env bash
# 用途：建立或更新 NetworkProvisioningOperator 自訂 role 並授予執行帳號。
# 流程：載入網路設定後配置固定 Compute/VPC/Service Networking 權限。
# 重要變數：ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與專案 IAM policy。
# 安全限制：只授予清單內權限，仍須確認目標專案與操作者權限。
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="NetworkProvisioningOperator"
ROLE_TITLE="網路佈建操作員"
ROLE_DESCRIPTION="佈建主應用程式網路所需的權限"
ROLE_PERMISSIONS="compute.addresses.create,compute.addresses.createInternal,compute.addresses.get,compute.addresses.list,compute.addresses.use,compute.globalAddresses.create,compute.globalAddresses.createInternal,compute.globalAddresses.get,compute.globalAddresses.list,compute.networks.create,compute.networks.get,compute.networks.list,compute.networks.use,compute.networks.update,compute.networks.updatePolicy,compute.routers.create,compute.routers.get,compute.routers.list,compute.routers.update,compute.subnetworks.create,compute.subnetworks.get,compute.subnetworks.list,compute.subnetworks.update,compute.subnetworks.use,compute.routes.list,servicenetworking.services.addPeering,servicenetworking.services.get,serviceusage.services.enable,serviceusage.services.list,resourcemanager.projects.get"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的網路自訂 role 是否存在，不修改資源。
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 更新 ${GOOGLE_PROJECT_ID} 的網路自訂 role。
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增網路自訂 role。
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的網路自訂 role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
