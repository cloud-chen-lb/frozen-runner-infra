#!/usr/bin/env bash
# 用途：建立或驗證 co-signer 的 MySQL Cloud SQL instance。
# 流程：驗證固定版本、規格與 VPC，唯讀檢查既有 instance，不存在才建立。
# 重要變數：MYSQL_VERSION、MYSQL_EDITION、MYSQL_CPU、MYSQL_MEMORY_MB、MYSQL_NETWORK_NAME。
# 資源影響：建立區域 HA、備份/PITR、刪除保護且停用 public IP 的 Cloud SQL instance；安全/驗證限制：網路漂移時停止。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
source "${SCRIPT_DIR}/00_mysql_env.sh"

if [[ "${MYSQL_VERSION}" != MYSQL_8_0 || "${MYSQL_EDITION}" != ENTERPRISE ||
  ! "${MYSQL_CPU}" =~ ^[0-9]+$ || ! "${MYSQL_MEMORY_MB}" =~ ^[0-9]+$ ||
  ! "${MYSQL_STORAGE_GB}" =~ ^[0-9]+$ || "${MYSQL_NETWORK_NAME}" != frozen-runner-vpc ]]; then
  printf 'Invalid MySQL instance configuration\n' >&2
  exit 1
fi

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 MySQL Cloud SQL instance 是否存在，不修改資源。
if gcloud sql instances describe "${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 唯讀查詢既有 MySQL instance 的 private network，不修改資源。
  private_network="$(gcloud sql instances describe "${MYSQL_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" --format='value(settings.ipConfiguration.privateNetwork)')"
  [[ "${private_network}" == "${MYSQL_NETWORK_NAME}" ||
    "${private_network}" == "projects/${GOOGLE_PROJECT_ID}/global/networks/${MYSQL_NETWORK_NAME}" ]] || {
    printf 'Drift: %s does not match MySQL private network\n' "${MYSQL_INSTANCE_NAME}" >&2
    exit 1
  }
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 MySQL Cloud SQL instance。
  gcloud sql instances create "${MYSQL_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" \
    --database-version="${MYSQL_VERSION}" --edition="${MYSQL_EDITION}" --cpu="${MYSQL_CPU}" \
    --memory="${MYSQL_MEMORY_MB}MB" --storage-size="${MYSQL_STORAGE_GB}" \
    --region="${GOOGLE_PROJECT_REGION}" --availability-type=REGIONAL \
    --network="${MYSQL_NETWORK_NAME}" --no-assign-ip --backup-start-time=03:00 \
    --enable-point-in-time-recovery --deletion-protection
fi
