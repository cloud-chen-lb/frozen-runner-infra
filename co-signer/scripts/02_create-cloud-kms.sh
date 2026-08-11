#!/usr/bin/env bash

source ./00_env.sh

gcloud kms keyrings create "$KMS_KEYRING" \
   --location "$GOOGLE_PROJECT_REGION"
gcloud kms keys create "$KMS_CRYPTO_KEY" \
   --location "$GOOGLE_PROJECT_REGION" \
   --keyring "$KMS_KEYRING" \
   --purpose encryption
gcloud iam service-accounts create "fr-safeheron-apicosigner-sa"
gcloud kms keys add-iam-policy-binding "$KMS_CRYPTO_KEY" \
   --location "$GOOGLE_PROJECT_REGION" \
   --keyring "$KMS_KEYRING" \
   --member "serviceAccount:$VM_SERVICE_ACCOUNT_EMAIL" \
   --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"
