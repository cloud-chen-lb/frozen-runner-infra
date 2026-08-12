#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
source "${SCRIPT_DIR}/../../../01_cloudbuild/base/scripts/00_env.sh"

for variable in CLOUD_BUILD_CONNECTION_NAME CLOUD_BUILD_REPOSITORY_NAME APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING APP_VPC_ARGS MIGRATION_VPC_ARGS; do
  [[ -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

repository="projects/${GOOGLE_PROJECT_ID}/locations/${GOOGLE_PROJECT_REGION}/connections/${CLOUD_BUILD_CONNECTION_NAME}/repositories/${CLOUD_BUILD_REPOSITORY_NAME}"
service_account="projects/${GOOGLE_PROJECT_ID}/serviceAccounts/${DEPLOY_SERVICE_ACCOUNT_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
substitution_args="^;^_IMAGE_TAG=;_REGION=${GOOGLE_PROJECT_REGION};_REPOSITORY=${PROJECT_NAME}-container-repository;_APP_IMAGE=${PROJECT_NAME}-app;_MIGRATION_IMAGE=${PROJECT_NAME}-migration;_APP_SERVICE=${PROJECT_NAME}-main-app;_MIGRATION_JOB=${PROJECT_NAME}-db-migration;_DEPLOYER_SERVICE_ACCOUNT=${DEPLOY_SERVICE_ACCOUNT_NAME};_APP_SERVICE_ACCOUNT=${APP_SERVICE_ACCOUNT_NAME};_MIGRATOR_SERVICE_ACCOUNT=${MIGRATION_SERVICE_ACCOUNT_NAME};_APP_VPC_ARGS=${APP_VPC_ARGS};_MIGRATION_VPC_ARGS=${MIGRATION_VPC_ARGS};_APP_SECRET_MAPPING=${APP_SECRET_MAPPING};_MIGRATION_SECRET_MAPPING=${MIGRATION_SECRET_MAPPING}"

if gcloud builds triggers describe "${PRODUCTION_TRIGGER_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  get_trigger_value() {
    gcloud builds triggers describe "${PRODUCTION_TRIGGER_NAME}" \
      --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
      --format="value($1)"
  }
  [[ "$(get_trigger_value repositoryEventConfig.repository)" == "${repository}" ]] || drift=1
  [[ "$(get_trigger_value repositoryEventConfig.push.branch)" == "${CLOUD_BUILD_SOURCE_BRANCH}" ]] || drift=1
  [[ "$(get_trigger_value filename)" == 'cicd/prod/cloudbuild-deploy.yaml' ]] || drift=1
  [[ "$(get_trigger_value serviceAccount)" == "${service_account}" ]] || drift=1
  for key in _IMAGE_TAG _REGION _REPOSITORY _APP_IMAGE _MIGRATION_IMAGE _APP_SERVICE _MIGRATION_JOB \
    _DEPLOYER_SERVICE_ACCOUNT _APP_SERVICE_ACCOUNT _MIGRATOR_SERVICE_ACCOUNT _APP_VPC_ARGS \
    _MIGRATION_VPC_ARGS _APP_SECRET_MAPPING _MIGRATION_SECRET_MAPPING; do
    expected="${key#_}"
    case "${key}" in
      _IMAGE_TAG) expected="";;
      _REGION) expected="${GOOGLE_PROJECT_REGION}";;
      _REPOSITORY) expected="${PROJECT_NAME}-container-repository";;
      _APP_IMAGE) expected="${PROJECT_NAME}-app";;
      _MIGRATION_IMAGE) expected="${PROJECT_NAME}-migration";;
      _APP_SERVICE) expected="${PROJECT_NAME}-main-app";;
      _MIGRATION_JOB) expected="${PROJECT_NAME}-db-migration";;
      _DEPLOYER_SERVICE_ACCOUNT) expected="${DEPLOY_SERVICE_ACCOUNT_NAME}";;
      _APP_SERVICE_ACCOUNT) expected="${APP_SERVICE_ACCOUNT_NAME}";;
      _MIGRATOR_SERVICE_ACCOUNT) expected="${MIGRATION_SERVICE_ACCOUNT_NAME}";;
      _APP_VPC_ARGS) expected="${APP_VPC_ARGS}";;
      _MIGRATION_VPC_ARGS) expected="${MIGRATION_VPC_ARGS}";;
      _APP_SECRET_MAPPING) expected="${APP_SECRET_MAPPING}";;
      _MIGRATION_SECRET_MAPPING) expected="${MIGRATION_SECRET_MAPPING}";;
    esac
    [[ "$(get_trigger_value "substitutions.${key}")" == "${expected}" ]] || drift=1
  done
  if [[ "${drift:-0}" == 1 ]]; then
    printf 'Production trigger drift detected: %s\n' "${PRODUCTION_TRIGGER_NAME}" >&2
    exit 1
  fi
  printf 'Production trigger already matches configuration: %s\n' "${PRODUCTION_TRIGGER_NAME}"
  exit 0
fi

gcloud builds triggers create manual --name="${PRODUCTION_TRIGGER_NAME}" \
  --repository="${repository}" --branch="${CLOUD_BUILD_SOURCE_BRANCH}" \
  --build-config='cicd/prod/cloudbuild-deploy.yaml' --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" --service-account="${service_account}" \
  --substitutions="${substitution_args}"
