#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

gcloud compute addresses create "$VM_STATIC_IP_NAME" \
    --project "$GOOGLE_PROJECT_ID" \
    --region "$GOOGLE_PROJECT_REGION" \
    --network-tier PREMIUM

gcloud compute instances create "$VM_NAME" \
    --project "$GOOGLE_PROJECT_ID" \
    --zone "$VM_ZONE" \
    --machine-type "$VM_MACHINE_TYPE" \
    --service-account "$VM_SERVICE_ACCOUNT_EMAIL" \
    --scopes "https://www.googleapis.com/auth/cloud-platform" \
    --image-family "ubuntu-2404-lts-amd64" \
    --image-project "ubuntu-os-cloud" \
    --network-interface="address=${VM_STATIC_IP_NAME},network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=${VM_VPC_NETWORK}" \
    --boot-disk-size 100G
