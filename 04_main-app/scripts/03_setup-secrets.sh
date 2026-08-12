#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

declare -a SECRET_NAMES=()
declare -a SECRET_ACCESSORS=()

parse_mapping() {
  local mapping="$1" accessor="$2" item key reference secret_name version
  local -a items
  IFS=',' read -r -a items <<<"${mapping}"
  ((${#items[@]} > 0)) || return 1
  for item in "${items[@]}"; do
    [[ "${item}" == *=*:* ]] || return 1
    key="${item%%=*}"
    reference="${item#*=}"
    secret_name="${reference%:*}"
    version="${reference##*:}"
    [[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 1
    [[ "${secret_name}" =~ ^[a-zA-Z0-9_-]{1,255}$ ]] || return 1
    [[ "${version}" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    if ((${#SECRET_NAMES[@]} > 0)); then
      for existing_name in "${SECRET_NAMES[@]}"; do
        [[ "${existing_name}" != "${secret_name}" ]] || return 1
      done
    fi
    SECRET_NAMES+=("${secret_name}")
    SECRET_ACCESSORS+=("${accessor}")
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
    gcloud secrets create "${secret_name}" --replication-policy=automatic \
      --project="${GOOGLE_PROJECT_ID}"
  fi
  gcloud secrets add-iam-policy-binding "${secret_name}" \
    --member="serviceAccount:${accessor_email}" \
    --role="roles/secretmanager.secretAccessor" --project="${GOOGLE_PROJECT_ID}"
done
