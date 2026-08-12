#!/usr/bin/env bash
# 用途：建立或驗證正式 PostgreSQL Cloud SQL instance。
# 流程：驗證版本、規格、區域與私有網路；既有 instance 逐項比對合約，不存在才建立。
# 重要變數：POSTGRES_VERSION/EDITION/CPU/MEMORY/STORAGE、POSTGRES_NETWORK_NAME、POSTGRES_INSTANCE_NAME。
# 資源影響：建立 Cloud SQL instance，啟用區域 HA、備份、PITR、刪除保護並停用 public IP。
# 安全/驗證限制：設定漂移時停止，不自動修改既有資料庫；建立需要相應 Cloud SQL 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if [[ ! "${POSTGRES_VERSION}" =~ ^POSTGRES_[0-9]+$ ]] ||
  [[ "${POSTGRES_EDITION}" != ENTERPRISE ]] ||
  [[ ! "${POSTGRES_CPU}" =~ ^[0-9]+$ ]] || (( POSTGRES_CPU < 1 )) ||
  [[ ! "${POSTGRES_MEMORY_MB}" =~ ^[0-9]+$ ]] || (( POSTGRES_MEMORY_MB < 3840 )) ||
  [[ ! "${POSTGRES_STORAGE_GB}" =~ ^[0-9]+$ ]] || (( POSTGRES_STORAGE_GB < 10 )) ||
  [[ ! "${GOOGLE_PROJECT_REGION}" =~ ^[a-z][a-z0-9-]*[0-9]$ ]] ||
  [[ ! "${POSTGRES_NETWORK_NAME}" =~ ^[a-z][a-z0-9-]{0,62}$ ]]; then
  printf 'Invalid PostgreSQL instance configuration\n' >&2
  exit 1
fi

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud SQL instance，不修改資源。
if gcloud sql instances describe "${POSTGRES_INSTANCE_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  describe_value() {
    # 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud SQL instance 欄位，不修改資源。
    gcloud sql instances describe "${POSTGRES_INSTANCE_NAME}" \
      --project="${GOOGLE_PROJECT_ID}" --format="value($1)" 2>/dev/null
  }

  check_value() {
    local field="$1" expected="$2" label="$3" actual
    actual="$(describe_value "${field}")"
    if [[ "${actual}" != "${expected}" ]]; then
      printf 'Drift: %s does not match PostgreSQL contract (%s: %s)\n' \
        "${POSTGRES_INSTANCE_NAME}" "${label}" "${expected}" >&2
      exit 1
    fi
  }

  check_value 'databaseVersion' "${POSTGRES_VERSION}" 'databaseVersion'
  check_value 'settings.tier' "db-custom-${POSTGRES_CPU}-${POSTGRES_MEMORY_MB}" 'tier'
  check_value 'settings.dataDiskSizeGb' "${POSTGRES_STORAGE_GB}" 'dataDiskSizeGb'
  check_value 'settings.availabilityType' 'REGIONAL' 'availabilityType'
  check_value 'settings.ipConfiguration.ipv4Enabled' 'False' 'ipv4Enabled'
  check_value 'settings.backupConfiguration.enabled' 'True' 'backupEnabled'
  check_value 'settings.backupConfiguration.pointInTimeRecoveryEnabled' 'True' \
    'pointInTimeRecoveryEnabled'
  check_value 'deletionProtectionEnabled' 'True' 'deletionProtectionEnabled'

  private_network="$(describe_value 'settings.ipConfiguration.privateNetwork')"
  if [[ "${private_network}" != "${POSTGRES_NETWORK_NAME}" &&
    "${private_network}" != "projects/${GOOGLE_PROJECT_ID}/global/networks/${POSTGRES_NETWORK_NAME}" ]]; then
    printf 'Drift: %s does not match PostgreSQL private network\n' "${POSTGRES_INSTANCE_NAME}" >&2
    exit 1
  fi
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 PostgreSQL Cloud SQL instance。
  gcloud sql instances create "${POSTGRES_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" \
    --database-version="${POSTGRES_VERSION}" \
    --edition="${POSTGRES_EDITION}" \
    --cpu="${POSTGRES_CPU}" \
    --memory="${POSTGRES_MEMORY_MB}MB" \
    --storage-size="${POSTGRES_STORAGE_GB}" \
    --region="${GOOGLE_PROJECT_REGION}" \
    --availability-type=REGIONAL \
    --network="${POSTGRES_NETWORK_NAME}" \
    --no-assign-ip \
    --backup-start-time=03:00 \
    --enable-point-in-time-recovery \
    --deletion-protection
fi
