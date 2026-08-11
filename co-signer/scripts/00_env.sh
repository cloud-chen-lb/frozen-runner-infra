#!/usr/bin/env bash

# 專案名稱
PROJECT_NAME="frozen-runner"
# GCP 專案 ID，所有建立與綁定資源的腳本共用
GOOGLE_PROJECT_ID="echox-beta"
# GCP 專案資源使用的區域
GOOGLE_PROJECT_REGION="asia-east1"
# 要授予自訂 IAM role 的 Google 帳號
ROLE_IAM_ACCOUNT="cloud.chen@getoken.io"
# 自訂 IAM role 的識別名稱
ROLE_ID="SafeheronCoSignerBuilderRole"
# 自訂 IAM role 在 GCP 顯示的名稱
ROLE_TITLE="Safeheron Co-Signer Builder"

# KMS key ring 名稱
KMS_KEYRING="${PROJECT_NAME}-cosigner-keyring"
# KMS crypto key 名稱
KMS_CRYPTO_KEY="${PROJECT_NAME}-cosigner-key"

# VM 所在的可用區域
VM_ZONE="asia-east1-a"
# VM 使用的機器類型
VM_MACHINE_TYPE="e2-medium"
# VM 使用的 VPC 網路，需與執行服務的 VM 相同
VM_VPC_NETWORK="default"
# 要建立的 VM 名稱
VM_NAME="${PROJECT_NAME}-cosigner"
# VM 靜態外部 IP 的名稱
VM_STATIC_IP_NAME="${VM_NAME}-ip"
# VM 使用的 Google service account email
VM_SERVICE_ACCOUNT_EMAIL="${PROJECT_NAME}-cosigner-sa@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
