#!/usr/bin/env bash
# 用途：依兩組 mapping 建立 Secret Manager metadata，並授予對應 runtime service account 讀取權。
# 流程：解析並驗證 key/secret/version，拒絕重複名稱或 key，再建立 automatic replication secret 與 accessor binding。
# 重要變數：APP_SECRET_MAPPING、MIGRATION_SECRET_MAPPING、APP/MIGRATION_SERVICE_ACCOUNT_NAME。
# 資源影響：建立 Secret Manager secrets 並修改 secret IAM policy；不建立 secret version、不寫入秘密值。
# 安全限制：mapping 只含 metadata，名稱與 key 受格式限制；需另行安全地建立秘密版本。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

for account in APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME; do
  [[ "${!account}" =~ ^[a-z][a-z0-9-]{5,29}$ ]] || {
    printf '%s must be a bare service account name\n' "${account}" >&2
    exit 1
  }
done

declare -a SECRET_NAMES=()
declare -a SECRET_ACCESSORS=()

parse_mapping() {
  local mapping="$1" accessor="$2"
  local item key secret_name version
  local -a items mapping_keys=()
  IFS=',' read -r -a items <<<"${mapping}"
  ((${#items[@]} > 0)) || return 1
  for item in "${items[@]}"; do
    [[ "${item}" =~ ^([A-Z][A-Z0-9_]*)=([a-zA-Z0-9_-]{1,255}):([a-zA-Z0-9_-]+)$ ]] || return 1
    key="${BASH_REMATCH[1]}"
    secret_name="${BASH_REMATCH[2]}"
    version="${BASH_REMATCH[3]}"
    if ((${#SECRET_NAMES[@]} > 0)); then
      for existing_name in "${SECRET_NAMES[@]}"; do
        [[ "${existing_name}" != "${secret_name}" ]] || return 1
      done
    fi
    if ((${#mapping_keys[@]} > 0)); then
      for existing_key in "${mapping_keys[@]}"; do
        [[ "${existing_key}" != "${key}" ]] || return 1
      done
    fi
    SECRET_NAMES+=("${secret_name}")
    SECRET_ACCESSORS+=("${accessor}")
    mapping_keys+=("${key}")
  done
}

parse_mapping "${APP_SECRET_MAPPING}" "${APP_SERVICE_ACCOUNT_NAME}" || {
  printf 'Invalid APP_SECRET_MAPPING\n' >&2
  exit 1
}
parse_mapping "${MIGRATION_SECRET_MAPPING}" "${MIGRATION_SERVICE_ACCOUNT_NAME}" || {
  printf 'Invalid MIGRATION_SECRET_MAPPING\n' >&2
  exit 1
}

for index in "${!SECRET_NAMES[@]}"; do
  secret_name="${SECRET_NAMES[$index]}"
  accessor_name="${SECRET_ACCESSORS[$index]}"
  accessor_email="${accessor_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
  # 唯讀查詢 ${GOOGLE_PROJECT_ID} Secret Manager secret 的 replication 設定，不修改資源。
  if replication="$(gcloud secrets describe "${secret_name}" --project="${GOOGLE_PROJECT_ID}" \
    --format='value(replication.automatic)' 2>/dev/null)"; then
    case "${replication}" in
      True|true) : ;;
      *)
        printf 'Drift: %s does not use automatic replication\n' "${secret_name}" >&2
        exit 1
        ;;
    esac
  else
    # 在 ${GOOGLE_PROJECT_ID} 新增 automatic replication 的 Secret Manager secret metadata。
    gcloud secrets create "${secret_name}" --replication-policy=automatic \
      --project="${GOOGLE_PROJECT_ID}"
  fi
  # 授權 runtime service account 讀取 ${GOOGLE_PROJECT_ID} 的 secret，修改 secret IAM policy。
  gcloud secrets add-iam-policy-binding "${secret_name}" \
    --member="serviceAccount:${accessor_email}" \
    --role="roles/secretmanager.secretAccessor" --project="${GOOGLE_PROJECT_ID}"
done
