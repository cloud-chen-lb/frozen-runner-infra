#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="CloudSQLProvisioningOperator"
ROLE_TITLE="Cloud SQL Provisioning Operator"
ROLE_DESCRIPTION="Permissions required to provision the main application PostgreSQL database"
ROLE_PERMISSIONS="cloudsql.instances.create,cloudsql.instances.get,cloudsql.instances.list,cloudsql.instances.update,cloudsql.databases.create,cloudsql.databases.get,cloudsql.databases.list,cloudsql.users.create,cloudsql.users.get,cloudsql.users.list,cloudsql.users.update,servicenetworking.services.get,servicenetworking.services.list,compute.globalAddresses.get,compute.globalAddresses.list,serviceusage.services.enable,serviceusage.services.list,resourcemanager.projects.get"
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
