#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

ROLE_ID="CloudBuildSetupOperator"
ROLE_TITLE="Cloud Build Setup Operator"
ROLE_DESCRIPTION="Permissions required to provision and operate the Cloud Build pipeline"
ROLE_PERMISSIONS="\
 cloudbuild.builds.create,\
 cloudbuild.connections.create,\
 cloudbuild.connections.get,\
 cloudbuild.repositories.create,\
 cloudbuild.repositories.get,\
 artifactregistry.dockerimages.get,\
 artifactregistry.repositories.create,\
 artifactregistry.repositories.get,\
 iam.roles.create,\
 iam.serviceAccounts.create,\
 iam.serviceAccounts.get,\
 iam.serviceAccounts.getIamPolicy,\
 iam.serviceAccounts.setIamPolicy,\
 resourcemanager.projects.get,\
 resourcemanager.projects.getIamPolicy,\
 resourcemanager.projects.setIamPolicy,\
 serviceusage.services.enable,\
 serviceusage.services.list"

if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" \
    --project="${GOOGLE_PROJECT_ID}" \
    --title="${ROLE_TITLE}" \
    --description="${ROLE_DESCRIPTION}" \
    --stage="GA" \
    --permissions="${ROLE_PERMISSIONS}"
else
  gcloud iam roles create "${ROLE_ID}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="${ROLE_TITLE}" \
  --description="${ROLE_DESCRIPTION}" \
  --stage="GA" \
  --permissions="${ROLE_PERMISSIONS}"
fi

gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"

printf 'Granted projects/%s/roles/%s to user:%s.\n' \
  "${GOOGLE_PROJECT_ID}" "${ROLE_ID}" "${EXEC_IAM_ACCOUNT}"
