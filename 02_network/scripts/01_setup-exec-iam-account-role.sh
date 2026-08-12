#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"
ROLE_ID="NetworkProvisioningOperator"
ROLE_TITLE="Network Provisioning Operator"
ROLE_DESCRIPTION="Permissions required to provision the main application network"
ROLE_PERMISSIONS="compute.addresses.create,compute.addresses.createInternal,compute.addresses.get,compute.addresses.list,compute.addresses.use,compute.globalAddresses.create,compute.globalAddresses.createInternal,compute.globalAddresses.get,compute.globalAddresses.list,compute.networks.create,compute.networks.get,compute.networks.list,compute.networks.use,compute.networks.update,compute.networks.updatePolicy,compute.routers.create,compute.routers.get,compute.routers.list,compute.routers.update,compute.subnetworks.create,compute.subnetworks.get,compute.subnetworks.list,compute.subnetworks.update,compute.subnetworks.use,compute.routes.list,servicenetworking.services.addPeering,servicenetworking.services.get,serviceusage.services.enable,serviceusage.services.list,resourcemanager.projects.get"
if gcloud iam roles describe "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam roles update "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
else
  gcloud iam roles create "${ROLE_ID}" --project="${GOOGLE_PROJECT_ID}" --title="${ROLE_TITLE}" --description="${ROLE_DESCRIPTION}" --stage="GA" --permissions="${ROLE_PERMISSIONS}"
fi
gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" --member="user:${EXEC_IAM_ACCOUNT}" --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"
