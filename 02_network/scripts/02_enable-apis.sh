#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

required_services=(
  compute.googleapis.com
  cloudbuild.googleapis.com
  artifactregistry.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  logging.googleapis.com
  run.googleapis.com
  secretmanager.googleapis.com
  servicenetworking.googleapis.com
  sqladmin.googleapis.com
  vpcaccess.googleapis.com
)

enabled_services="$(gcloud services list --enabled --project="${GOOGLE_PROJECT_ID}" --format='value(config.name)')"
for service in "${required_services[@]}"; do
  if ! grep -Fxq "${service}" <<<"${enabled_services}"; then
    gcloud services enable "${service}" --project="${GOOGLE_PROJECT_ID}"
  fi
done
