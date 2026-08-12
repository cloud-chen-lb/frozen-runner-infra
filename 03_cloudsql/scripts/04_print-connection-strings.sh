#!/usr/bin/env bash
# 用途：查詢 private Cloud SQL host 並輸出 app/migration connection strings。
# 流程：唯讀查詢 instance private IP；密碼固定以安全 placeholder 表示。
# 重要變數：POSTGRES_DATABASE_NAME、POSTGRES_APP_USER、POSTGRES_MIGRATION_USER、POSTGRES_INSTANCE_NAME。
# 資源影響：只查詢 Cloud SQL instance，不讀取或修改密碼。
# 安全限制：輸出不包含真實密碼，呼叫者須在使用前替換 <PASSWORD>。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

if ! postgres_host="$(gcloud sql instances describe "${POSTGRES_INSTANCE_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --format='value(ipAddresses[0].ipAddress)')"; then
  printf 'Failed to query Cloud SQL private host for %s\n' "${POSTGRES_INSTANCE_NAME}" >&2
  exit 1
fi

if [[ -z "${postgres_host}" ]]; then
  printf 'Cloud SQL host is empty for %s\n' "${POSTGRES_INSTANCE_NAME}" >&2
  exit 1
fi

printf 'APP_DATABASE_URL=postgresql://%s:<PASSWORD>@%s/%s\n' \
  "${POSTGRES_APP_USER}" "${postgres_host}" "${POSTGRES_DATABASE_NAME}"
printf 'MIGRATION_DATABASE_URL=postgresql://%s:<PASSWORD>@%s/%s\n' \
  "${POSTGRES_MIGRATION_USER}" "${postgres_host}" "${POSTGRES_DATABASE_NAME}"
