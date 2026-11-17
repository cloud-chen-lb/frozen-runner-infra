#!/usr/bin/env bash
# 用途：建立 Safeheron co-signer 建置用自訂 IAM role 並授予執行帳號。
# 流程：載入環境，建立 role 後將固定 KMS、Compute、service account 與 Cloud SQL 權限綁定。
# 重要變數：ROLE_ID、ROLE_PERMISSIONS、GOOGLE_PROJECT_ID、EXEC_IAM_ACCOUNT；資源影響：修改 role 與專案 IAM policy。
# 安全限制：只補齊既有 role 缺少的權限，不移除其他權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 固定的 Co-Signer 建置權限。
ROLE_PERMISSIONS="\
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
compute.firewalls.get,\
compute.firewalls.create,\
compute.firewalls.delete,\
compute.networks.updatePolicy,\
compute.disks.create,\
compute.addresses.create,\
compute.addresses.get,\
compute.addresses.use,\
compute.subnetworks.create,\
compute.subnetworks.get,\
compute.subnetworks.list,\
compute.subnetworks.use,\
compute.subnetworks.useExternalIp,\
cloudsql.instances.create,\
cloudsql.instances.get,\
cloudsql.instances.list,\
cloudsql.databases.create,\
cloudsql.databases.get,\
cloudsql.users.create,\
cloudsql.users.get,\
cloudsql.users.list,\
cloudsql.users.update,\
resourcemanager.projects.get"

# 只把明確的 not-found 當作可建立；認證或其他查詢錯誤必須中止。
role_error_file="$(mktemp)"
if role_deleted="$(gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --format="value(deleted)" 2>"${role_error_file}")"; then
  rm -f "${role_error_file}"
  if [[ "${role_deleted}" == "True" ]]; then
    gcloud iam roles undelete "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}"
  fi
  current_permissions="$(gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --format='value[delimiter=";"](includedPermissions)')"
  missing_permissions=()
  IFS=, read -r -a required_permission_list <<<"${ROLE_PERMISSIONS}"
  for required_permission in "${required_permission_list[@]}"; do
    if [[ ! ";${current_permissions};" == *";${required_permission};"* ]]; then
      missing_permissions+=("${required_permission}")
    fi
  done
  if ((${#missing_permissions[@]})); then
    missing_permissions_csv="$(IFS=,; printf '%s' "${missing_permissions[*]}")"
    gcloud iam roles update "${ROLE_ID}" \
      --project="${GOOGLE_PROJECT_ID}" \
      --add-permissions="${missing_permissions_csv}"
  fi
else
  if ! grep -Fq "NOT_FOUND: Resource [projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}] not found." "${role_error_file}" &&
    ! grep -Fq "NOT_FOUND: The role named projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID} was not found." "${role_error_file}"; then
    cat "${role_error_file}" >&2
    rm -f "${role_error_file}"
    exit 1
  fi
  rm -f "${role_error_file}"
  gcloud iam roles create "${ROLE_ID}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="${ROLE_TITLE}" \
  --description="${ROLE_DESCRIPTION}" \
  --stage="GA" \
  --permissions="${ROLE_PERMISSIONS}"
fi

# 授權執行帳號使用 ${GOOGLE_PROJECT_ID} 的 co-signer role，修改專案 IAM policy。
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"

echo "Granted projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID} to user:${EXEC_IAM_ACCOUNT}."
