#!/usr/bin/env bash
# 用途：以 release tag 觸發正式部署，並傳遞網路、秘密映射與執行期環境設定。
# 流程：解析 tag/override，拒絕分隔符與換行，驗證秘密 key 後執行 production trigger。
# 重要參數：v<release>、_IMAGE_TAG、branch、_APP_SECRET_MAPPING、_MIGRATION_SECRET_MAPPING、resource overrides 及 runtime/VPC 變數。
# 資源影響：啟動 Cloud Build，間接建立或更新 Cloud Run service/job；秘密值本身不在腳本中保存。
# 安全/驗證限制：只允許白名單秘密 key、禁止分號/換行；部署結果需另用驗證腳本確認。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

for account in APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME DEPLOY_SERVICE_ACCOUNT_NAME; do
  [[ "${!account}" =~ ^[a-z][a-z0-9-]{5,29}$ ]] || {
    printf '%s must be a bare service account name\n' "${account}" >&2
    exit 1
  }
done

IMAGE_TAG="${_IMAGE_TAG:-}"
BRANCH="${CLOUD_BUILD_SOURCE_BRANCH}"
for argument in "$@"; do
  case "$argument" in
    v[0-9A-Za-z._-]*) [[ -z "$IMAGE_TAG" ]] || { printf 'duplicate image tag\n' >&2; exit 1; }; IMAGE_TAG="$argument";;
    --_IMAGE_TAG=*) IMAGE_TAG="${argument#*=}";;
    --branch=*) BRANCH="${argument#*=}";;
    --_APP_SECRET_MAPPING=*) APP_SECRET_MAPPING="${argument#*=}";;
    --_MIGRATION_SECRET_MAPPING=*) MIGRATION_SECRET_MAPPING="${argument#*=}";;
    --_APP_RUNTIME_ENV_VARS=*) APP_RUNTIME_ENV_VARS="${argument#*=}";;
    --_MIGRATION_RUNTIME_ENV_VARS=*) MIGRATION_RUNTIME_ENV_VARS="${argument#*=}";;
    --_APP_MIN_INSTANCE=*) APP_MIN_INSTANCE="${argument#*=}";;
    --_APP_MAX_INSTANCE=*) APP_MAX_INSTANCE="${argument#*=}";;
    --_APP_CPU=*) APP_CPU="${argument#*=}";;
    --_APP_MEMORY=*) APP_MEMORY="${argument#*=}";;
    --_APP_TIMEOUT=*) APP_TIMEOUT="${argument#*=}";;
    --_APP_CONCURRENCY=*) APP_CONCURRENCY="${argument#*=}";;
    *) printf 'Usage: %s v<release> [--branch=value] [--_KEY=value]\n' "${BASH_SOURCE[0]}" >&2; exit 1;;
  esac
done

validate_secret_mapping() {
  local variable="$1" mapping="$2" item key
  [[ "$mapping" != *,*,,* && "$mapping" != ,* && "$mapping" != *, ]] || {
    printf '%s contains an empty secret mapping item\n' "$variable" >&2
    return 1
  }
  IFS=',' read -r -a items <<<"$mapping"
  for item in "${items[@]}"; do
    [[ "$item" =~ ^([A-Z][A-Z0-9_]*)=[a-zA-Z0-9_-]{1,255}:[a-zA-Z0-9_-]+$ ]] || {
      printf '%s contains an invalid secret mapping\n' "$variable" >&2
      return 1
    }
    key="${BASH_REMATCH[1]}"
    case "$variable:$key" in
      APP_SECRET_MAPPING:APP_INTERNAL_ADMIN_PASSWORD|\
      APP_SECRET_MAPPING:APP_ALERT_API_BEARER_TOKEN|\
      APP_SECRET_MAPPING:APP_DATA_ENCRYPTION_SECRET|\
      APP_SECRET_MAPPING:APP_DATABASE_URL|\
      APP_SECRET_MAPPING:APP_MAILGUN_API_KEY|\
      MIGRATION_SECRET_MAPPING:APP_DATABASE_URL) ;;
      *)
        printf '%s contains an unauthorized secret key\n' "$variable" >&2
        return 1
        ;;
    esac
  done
}

for variable in IMAGE_TAG BRANCH GOOGLE_PROJECT_REGION APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING APP_RUNTIME_ENV_VARS MIGRATION_RUNTIME_ENV_VARS APP_MIN_INSTANCE APP_MAX_INSTANCE \
  APP_CPU APP_MEMORY APP_TIMEOUT APP_CONCURRENCY; do
  case "${variable}" in
    MIGRATION_RUNTIME_ENV_VARS|APP_MIN_INSTANCE|APP_MAX_INSTANCE|APP_CPU|APP_MEMORY|APP_TIMEOUT|APP_CONCURRENCY) ;;
    *) [[ -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; };;
  esac
  [[ "${!variable}" != *';'* ]] || { printf '%s contains forbidden delimiter\n' "${variable}" >&2; exit 1; }
  [[ "${!variable}" != *$'\n'* ]] || { printf '%s contains forbidden newline\n' "${variable}" >&2; exit 1; }
done
validate_secret_mapping APP_SECRET_MAPPING "$APP_SECRET_MAPPING"
validate_secret_mapping MIGRATION_SECRET_MAPPING "$MIGRATION_SECRET_MAPPING"

# 在 ${GOOGLE_PROJECT_ID} 執行 production deployment trigger，啟動 Cloud Run 部署。
gcloud builds triggers run "${PRODUCTION_TRIGGER_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
  --branch="${BRANCH}" \
  --substitutions="^;^_IMAGE_TAG=${IMAGE_TAG};_REGION=${GOOGLE_PROJECT_REGION};_APP_VPC_ARGS=${APP_VPC_ARGS};_MIGRATION_VPC_ARGS=${MIGRATION_VPC_ARGS};_APP_SECRET_MAPPING=${APP_SECRET_MAPPING};_MIGRATION_SECRET_MAPPING=${MIGRATION_SECRET_MAPPING};_APP_RUNTIME_ENV_VARS=${APP_RUNTIME_ENV_VARS};_MIGRATION_RUNTIME_ENV_VARS=${MIGRATION_RUNTIME_ENV_VARS};_APP_MIN_INSTANCE=${APP_MIN_INSTANCE};_APP_MAX_INSTANCE=${APP_MAX_INSTANCE};_APP_CPU=${APP_CPU};_APP_MEMORY=${APP_MEMORY};_APP_TIMEOUT=${APP_TIMEOUT};_APP_CONCURRENCY=${APP_CONCURRENCY}"
