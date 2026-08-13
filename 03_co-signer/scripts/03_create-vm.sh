#!/usr/bin/env bash
# 用途：建立 co-signer VM 使用的區域靜態外部 IP 與 Ubuntu 24.04 VM。
# 流程：先建立保留 IP，再以固定 zone/machine/image/network 參數建立 VM。
# 重要變數：VM_NAME、VM_ZONE、VM_MACHINE_TYPE、VM_VPC_NETWORK、VM_SERVICE_ACCOUNT_EMAIL。
# 資源影響：建立 regional address、Compute Engine VM 與 100G boot disk。
# 安全限制：VM 使用 cloud-platform scope、外部 PREMIUM IP 且未在此腳本做既有資源漂移檢查，執行前須人工確認。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 在 ${GOOGLE_PROJECT_ID} 新增 co-signer VM 的區域固定外部 IP。
gcloud compute addresses create "$VM_STATIC_IP_NAME" \
    --project "$GOOGLE_PROJECT_ID" \
    --region "$GOOGLE_PROJECT_REGION" \
    --description "co-signer VM 使用的固定外部 IP。" \
    --network-tier PREMIUM

# 在 ${GOOGLE_PROJECT_ID} 新增 co-signer Compute Engine VM 及 boot disk。
gcloud compute instances create "$VM_NAME" \
    --project "$GOOGLE_PROJECT_ID" \
    --zone "$VM_ZONE" \
    --machine-type "$VM_MACHINE_TYPE" \
    --service-account "$VM_SERVICE_ACCOUNT_EMAIL" \
    --scopes "https://www.googleapis.com/auth/cloud-platform" \
    --image-family "ubuntu-2404-lts-amd64" \
    --image-project "ubuntu-os-cloud" \
    --network-interface="address=${VM_STATIC_IP_NAME},network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=${VM_VPC_NETWORK}" \
    --description "co-signer 運算執行個體。" \
    --boot-disk-size 100G
