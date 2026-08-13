#!/usr/bin/env bash
# 用途：建立指定 merchant 的 MySQL database 與 user。
# 流程：驗證 merchant slug，唯讀檢查 database/user，不存在才建立並以暫存 flags file 傳遞密碼。
# 重要變數：MERCHANT_SLUG、MYSQL_INSTANCE_NAME、database_name、user_name。
# 資源影響：建立 Cloud SQL database/user；安全/驗證限制：拒絕非法名稱、空白或多行密碼，不把密碼放入 argv。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
source "${SCRIPT_DIR}/00_mysql_env.sh"

MERCHANT_SLUG=''
while (($#)); do
  case "$1" in
    --merchant-slug=*) MERCHANT_SLUG="${1#*=}" ;;
    --help) printf 'Usage: %s --merchant-slug=SLUG\n' "$0"; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

[[ "${MERCHANT_SLUG}" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || {
  printf 'A valid --merchant-slug is required\n' >&2
  exit 1
}
database_name="cosigner_${MERCHANT_SLUG//-/_}"
user_name="${database_name}_user"
[[ "${database_name}" =~ ^[a-z][a-z0-9_]{0,62}$ && "${user_name}" =~ ^[a-z][a-z0-9_]{0,62}$ ]] || {
  printf 'Merchant slug produces an invalid MySQL name\n' >&2
  exit 1
}

# 唯讀查詢 MySQL database 是否存在，不修改 Cloud SQL 資源。
if ! gcloud sql databases describe "${database_name}" --instance="${MYSQL_INSTANCE_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  # 在 ${GOOGLE_PROJECT_ID} 的 MySQL instance 新增 merchant database。
  gcloud sql databases create "${database_name}" --instance="${MYSQL_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}"
fi

# 唯讀查詢 MySQL user 是否存在，不修改 Cloud SQL 資源。
if ! gcloud sql users describe "${user_name}" --instance="${MYSQL_INSTANCE_NAME}" \
  --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  password=''
  if [[ -t 0 ]]; then read -r -s -p 'Merchant MySQL password: ' password < /dev/tty; printf '\n' >&2
  else IFS= read -r password || true; fi
  [[ -n "${password}" && "${password}" != *$'\n'* ]] || { printf 'Password input is required\n' >&2; exit 1; }
  flags_file="$(mktemp)"
  chmod 600 "${flags_file}"
  trap 'rm -f "${flags_file}"' EXIT
  escaped_password="${password//\'/\'\'}"
  printf -- "--password: '%s'\n" "${escaped_password}" >"${flags_file}"
  # 在 ${GOOGLE_PROJECT_ID} 的 MySQL instance 新增 merchant user。
  gcloud sql users create "${user_name}" --instance="${MYSQL_INSTANCE_NAME}" \
    --project="${GOOGLE_PROJECT_ID}" --flags-file="${flags_file}"
fi
