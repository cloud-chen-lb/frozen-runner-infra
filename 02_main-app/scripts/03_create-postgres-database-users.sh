#!/usr/bin/env bash
# 用途：建立 PostgreSQL database 與 app/migration 使用者。
# 流程：解析 Secret Manager version 參數或 stdin/終端輸入，建立不存在的 database/user。
# 重要參數：--app-password-secret-version、--migration-password-secret-version；重要變數為資料庫名稱與使用者名稱。
# 資源影響：建立 Cloud SQL database/user，短暫以 0600 flags file 傳遞密碼後刪除。
# 安全限制：不把密碼放入 argv；驗證名稱、秘密參照與非空單行密碼，但呼叫者仍須保護 stdin/Secret Manager 權限。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

APP_PASSWORD_SECRET_VERSION=''
MIGRATION_PASSWORD_SECRET_VERSION=''
while (($#)); do
  case "$1" in
    --app-password-secret-version=*) APP_PASSWORD_SECRET_VERSION="${1#*=}" ;;
    --migration-password-secret-version=*) MIGRATION_PASSWORD_SECRET_VERSION="${1#*=}" ;;
    --help)
      printf 'Passwords come from stdin or Secret Manager version references.\n'
      exit 0
      ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

valid_name() { [[ "$1" =~ ^[a-z][a-z0-9_]{0,62}$ ]]; }
valid_secret_version() {
  [[ "$1" =~ ^projects/[a-z0-9-]+/secrets/[a-zA-Z0-9_-]+/versions/[a-zA-Z0-9_-]+$ ]]
}

if ! valid_name "${POSTGRES_DATABASE_NAME}" ||
  ! valid_name "${POSTGRES_APP_USER}" || ! valid_name "${POSTGRES_MIGRATION_USER}" ||
  [[ "${POSTGRES_APP_USER}" == "${POSTGRES_MIGRATION_USER}" ]] ||
  { [[ -n "${APP_PASSWORD_SECRET_VERSION}" ]] && ! valid_secret_version "${APP_PASSWORD_SECRET_VERSION}"; } ||
  { [[ -n "${MIGRATION_PASSWORD_SECRET_VERSION}" ]] && ! valid_secret_version "${MIGRATION_PASSWORD_SECRET_VERSION}"; }; then
  printf 'Invalid PostgreSQL database, user, or secret reference configuration\n' >&2
  exit 1
fi

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 PostgreSQL database 是否存在，不修改資源。
if ! gcloud sql databases describe "${POSTGRES_DATABASE_NAME}" \
  --instance="${POSTGRES_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 在 ${GOOGLE_PROJECT_ID} 的 Cloud SQL instance 新增 PostgreSQL database。
  gcloud sql databases create "${POSTGRES_DATABASE_NAME}" \
    --instance="${POSTGRES_INSTANCE_NAME}" --project="${GOOGLE_PROJECT_ID}"
fi

read_password() {
  local secret_version="$1" label="$2" password=''
  if [[ -n "${secret_version}" ]]; then
    # 唯讀取得 ${GOOGLE_PROJECT_ID} Secret Manager version 的秘密值，不修改資源。
    password="$(gcloud secrets versions access "${secret_version}" \
      --project="${GOOGLE_PROJECT_ID}")"
  elif [[ -t 0 ]]; then
    read -r -s -p "${label} password: " password < /dev/tty
    printf '\n' >&2
  else
    IFS= read -r password || true
  fi
  [[ -n "${password}" && "${password}" != *$'\n'* ]] || {
    printf '%s password input is required\n' "${label}" >&2
    exit 1
  }
  printf '%s' "${password}"
}

create_user() {
  local user="$1" secret_version="$2" label="$3" password flags_file
  # 唯讀查詢 ${GOOGLE_PROJECT_ID} Cloud SQL instance 的 PostgreSQL user，不修改資源。
  if gcloud sql users describe "${user}" --instance="${POSTGRES_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
    return
  fi
  password="$(read_password "${secret_version}" "${label}")"
  flags_file="$(mktemp)"
  chmod 600 "${flags_file}"
  trap 'rm -f "${flags_file}"' RETURN
  # gcloud receives a descriptor path, not a password-bearing argv value.
  escaped_password="${password//\'/\'\'}"
  printf -- "--password: '%s'\n" "${escaped_password}" >"${flags_file}"
  # 在 ${GOOGLE_PROJECT_ID} Cloud SQL instance 新增 PostgreSQL user。
  gcloud sql users create "${user}" --instance="${POSTGRES_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" \
    --flags-file="${flags_file}"
  rm -f "${flags_file}"
  trap - RETURN
  unset password escaped_password
}

create_user "${POSTGRES_APP_USER}" "${APP_PASSWORD_SECRET_VERSION}" application
create_user "${POSTGRES_MIGRATION_USER}" "${MIGRATION_PASSWORD_SECRET_VERSION}" migration
