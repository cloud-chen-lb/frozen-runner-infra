#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="CloudBuildDeployProvisioningOperator"
ROLE_TITLE="Cloud Build Deploy Provisioning Operator"
ROLE_DESCRIPTION="Permissions required to provision the production deployment pipeline"
ROLE_PERMISSIONS="cloudbuild.builds.create,cloudbuild.triggers.create,cloudbuild.triggers.get,cloudbuild.triggers.list,cloudbuild.triggers.update,run.services.get,run.services.list,run.services.update,run.jobs.get,run.jobs.list,run.jobs.update,artifactregistry.repositories.get,artifactregistry.repositories.list,artifactregistry.dockerimages.get,artifactregistry.dockerimages.list,iam.serviceAccounts.get,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy"
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
