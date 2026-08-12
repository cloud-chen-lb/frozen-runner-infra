#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

declare -a SERVICE_ACCOUNT_NAMES=(
  "${APP_SERVICE_ACCOUNT_NAME}"
  "${MIGRATION_SERVICE_ACCOUNT_NAME}"
  "${DEPLOY_SERVICE_ACCOUNT_NAME}"
)
declare -a SERVICE_ACCOUNT_DISPLAY_NAMES=(
  "${PROJECT_NAME} main app runtime"
  "${PROJECT_NAME} database migration runtime"
  "${PROJECT_NAME} production deploy"
)

for service_account_name in "${SERVICE_ACCOUNT_NAMES[@]}"; do
  [[ "${service_account_name}" =~ ^[a-z][a-z0-9-]{5,29}$ ]] || {
    printf 'Invalid service account name: %s\n' "${service_account_name}" >&2
    exit 1
  }
done

for index in "${!SERVICE_ACCOUNT_NAMES[@]}"; do
  service_account_name="${SERVICE_ACCOUNT_NAMES[$index]}"
  expected_display_name="${SERVICE_ACCOUNT_DISPLAY_NAMES[$index]}"
  service_account_email="${service_account_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
  if display_name="$(gcloud iam service-accounts describe "${service_account_email}" \
    --project="${GOOGLE_PROJECT_ID}" --format='value(displayName)' 2>/dev/null)"; then
    [[ "${display_name}" == "${expected_display_name}" ]] || {
      printf 'Drift: %s display name is %s, expected %s\n' \
        "${service_account_name}" "${display_name}" "${expected_display_name}" >&2
      exit 1
    }
  else
    gcloud iam service-accounts create "${service_account_name}" \
      --display-name="${expected_display_name}" --project="${GOOGLE_PROJECT_ID}"
  fi
done

deploy_email="${DEPLOY_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/run.admin"
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/artifactregistry.reader"

for runtime_name in "${APP_SERVICE_ACCOUNT_NAME}" "${MIGRATION_SERVICE_ACCOUNT_NAME}"; do
  runtime_email="${runtime_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
  gcloud iam service-accounts add-iam-policy-binding "${runtime_email}" \
    --member="serviceAccount:${deploy_email}" \
    --role="roles/iam.serviceAccountUser" --project="${GOOGLE_PROJECT_ID}"
done
