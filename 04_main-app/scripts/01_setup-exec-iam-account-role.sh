#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="MainAppProvisioningOperator"
ROLE_TITLE="Main Application Provisioning Operator"
ROLE_DESCRIPTION="Permissions required to provision runtime service accounts and secrets"
ROLE_PERMISSIONS="iam.serviceAccounts.create,iam.serviceAccounts.get,iam.serviceAccounts.list,iam.serviceAccounts.getIamPolicy,iam.serviceAccounts.setIamPolicy,secretmanager.secrets.create,secretmanager.secrets.get,secretmanager.secrets.list,secretmanager.secrets.getIamPolicy,secretmanager.secrets.setIamPolicy,run.services.get,run.services.list,run.jobs.get,run.jobs.list,resourcemanager.projects.get,resourcemanager.projects.getIamPolicy,resourcemanager.projects.setIamPolicy,serviceusage.services.enable,serviceusage.services.list"
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
