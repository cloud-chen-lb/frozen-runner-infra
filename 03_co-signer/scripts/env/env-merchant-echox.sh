# echox 商戶 Co-Signer VM 的非機密設定；由建立 VM 與 KMS key 的腳本載入。
# VM_ZONE 是 VM 所在的 Compute Engine zone；格式為 zone 名稱，必須與 GOOGLE_PROJECT_REGION 同區域，例如 asia-east1-a。
VM_ZONE="asia-east1-a"
# VM_MACHINE_TYPE 是 VM 機器類型；格式為 Compute Engine machine type 名稱，例如 e2-medium。
VM_MACHINE_TYPE="e2-medium"
# VM_VPC_NETWORK 是 VM 使用的 subnet 名稱；格式為 GCP subnet 資源名稱，應填該商戶 Co-Signer subnet。
VM_VPC_NETWORK="${PROJECT_NAME}-cosigner-subnet"
# VM_SSH_SOURCE_CIDR 限制可以連線到 VM 的來源 IP 範圍；格式為 CIDR
VM_SSH_SOURCE_CIDR="122.116.23.174/32"
