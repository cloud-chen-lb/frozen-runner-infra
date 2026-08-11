#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

gcloud iam roles create CloudBuildSetupOperator \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="Cloud Build Setup Operator" \
  --description="Permissions required to provision and operate the Cloud Build pipeline" \
  --stage="GA" \
  --permissions="\
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

gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/CloudBuildSetupOperator"

printf 'Granted projects/%s/roles/CloudBuildSetupOperator to user:%s.\n' \
  "${GOOGLE_PROJECT_ID}" "${EXEC_IAM_ACCOUNT}"
