#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

gcloud iam roles create "${ROLE_ID}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --title="${ROLE_TITLE}" \
  --description="Build Safeheron Co-Signer service" \
  --stage="GA" \
  --permissions="\
cloudkms.keyRings.create,\
cloudkms.keyRings.get,\
cloudkms.keyRings.list,\
cloudkms.cryptoKeys.create,\
cloudkms.cryptoKeys.get,\
cloudkms.cryptoKeys.list,\
cloudkms.cryptoKeys.getIamPolicy,\
cloudkms.cryptoKeys.setIamPolicy,\
iam.serviceAccounts.create,\
iam.serviceAccounts.actAs,\
iam.serviceAccounts.get,\
iam.serviceAccounts.list,\
compute.instances.create,\
compute.instances.get,\
compute.instances.list,\
compute.instances.setMetadata,\
compute.instances.setServiceAccount,\
compute.disks.create,\
compute.addresses.create,\
compute.addresses.get,\
compute.addresses.use,\
compute.subnetworks.use,\
compute.subnetworks.useExternalIp,\
cloudsql.instances.create,\
cloudsql.instances.get,\
cloudsql.instances.list,\
cloudsql.databases.create,\
cloudsql.databases.get,\
cloudsql.databases.list,\
resourcemanager.projects.get"

gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
  --member="user:${EXEC_IAM_ACCOUNT}" \
  --role="projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID}"

echo "Granted projects/${GOOGLE_PROJECT_ID}/roles/${ROLE_ID} to user:${EXEC_IAM_ACCOUNT}."
