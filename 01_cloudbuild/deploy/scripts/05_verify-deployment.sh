#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

[[ "$#" -eq 1 && "$1" =~ ^v.+$ ]] || {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
  exit 1
}
for variable in GOOGLE_PROJECT_REGION APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING; do
  [[ -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

image_base="${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${PROJECT_NAME}-container-repository"
gcloud artifacts docker images describe "${image_base}/${PROJECT_NAME}-app:$1" --project="${GOOGLE_PROJECT_ID}"
gcloud artifacts docker images describe "${image_base}/${PROJECT_NAME}-migration:$1" --project="${GOOGLE_PROJECT_ID}"
gcloud run jobs describe "${PRODUCTION_MIGRATION_JOB_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" --format='yaml(name,location,template.template.containers[0].image)'
latest_execution="$(gcloud run jobs executions list --job="${PRODUCTION_MIGRATION_JOB_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
  --limit=1 --format='value(name)')"
[[ -n "${latest_execution}" ]] || { printf 'No migration execution found\n' >&2; exit 1; }
gcloud run jobs executions describe "${latest_execution}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}"
gcloud run services describe "${PRODUCTION_APP_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --format='yaml(status.latestReadyRevisionName,status.traffic,spec.template.spec.containers[0].image,metadata.annotations.run.googleapis.com/ingress)'

if [[ -n "${DEPLOY_SMOKE_TEST_URL:-}" ]]; then
  curl --fail --silent --show-error --max-time 15 "${DEPLOY_SMOKE_TEST_URL}" >/dev/null
fi
