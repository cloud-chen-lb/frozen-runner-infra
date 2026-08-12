#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

deploy_name="${DEPLOY_SERVICE_ACCOUNT_NAME}"
deploy_email="${deploy_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
for variable in deploy_name deploy_email; do
  [[ -n "${!variable}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

if display_name="$(gcloud iam service-accounts describe "${deploy_email}" \
  --project="${GOOGLE_PROJECT_ID}" --format='value(displayName)' 2>/dev/null)"; then
  [[ "${display_name}" == "${PROJECT_NAME} production deploy" ]] || {
    printf 'Drift: %s display name is %s\n' "${deploy_name}" "${display_name}" >&2
    exit 1
  }
else
  gcloud iam service-accounts create "${deploy_name}" \
    --display-name="${PROJECT_NAME} production deploy" --project="${GOOGLE_PROJECT_ID}"
fi

gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="serviceAccount:${deploy_email}" --role="roles/run.admin"
gcloud artifacts repositories add-iam-policy-binding "${PROJECT_NAME}-container-repository" \
  --location="${GOOGLE_PROJECT_REGION}" \
  --member="serviceAccount:${deploy_email}" --role="roles/artifactregistry.reader" \
  --project="${GOOGLE_PROJECT_ID}"
for runtime_name in "${APP_SERVICE_ACCOUNT_NAME}" "${MIGRATION_SERVICE_ACCOUNT_NAME}"; do
  gcloud iam service-accounts add-iam-policy-binding \
    "${runtime_name}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
    --member="serviceAccount:${deploy_email}" \
    --role="roles/iam.serviceAccountUser" --project="${GOOGLE_PROJECT_ID}"
done
