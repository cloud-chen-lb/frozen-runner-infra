# ROLE_ID 是專案自訂 IAM role 的識別字；格式為 IAM role ID，供建立與比對 role 使用。
ROLE_ID="SafeheronCoSignerBuilderRole"
# ROLE_TITLE 是 IAM role 顯示名稱；格式為人類可讀的文字標題。
ROLE_TITLE="Safeheron Co-Signer 建置操作員"
# ROLE_DESCRIPTION 是 IAM role 說明；格式為人類可讀的文字，描述此 role 的用途。
ROLE_DESCRIPTION="建立 Safeheron Co-Signer 服務所需的權限"
# KMS_KEYRING 是 Co-Signer 共用 Cloud KMS keyring 名稱；格式為 GCP 資源名稱，由 PROJECT_NAME 加上 -kms 產生。
KMS_KEYRING="${PROJECT_NAME}-kms"
# MYSQL_VERSION 是 Co-Signer Cloud SQL MySQL 引擎版本；格式為 gcloud database-version 值，例如 MYSQL_8_0。
MYSQL_VERSION="MYSQL_8_0"
# MYSQL_EDITION 是 Co-Signer Cloud SQL edition；格式為 gcloud edition 值，目前使用 ENTERPRISE。
MYSQL_EDITION="ENTERPRISE"
# MYSQL_CPU 是 Co-Signer Cloud SQL vCPU 數量；格式為正整數，單位為 vCPU。
MYSQL_CPU="1"
# MYSQL_MEMORY_MB 是 Co-Signer Cloud SQL 記憶體；格式為正整數，單位為 MB，腳本會加上 MB 傳給 gcloud。
MYSQL_MEMORY_MB="3840"
# MYSQL_STORAGE_GB 是 Co-Signer Cloud SQL 儲存空間；格式為正整數，單位為 GB。
MYSQL_STORAGE_GB="20"
# MYSQL_NETWORK_NAME 是 MySQL Private IP 使用的 VPC 名稱；格式為 GCP VPC 資源名稱。
MYSQL_NETWORK_NAME="${PROJECT_NAME}-vpc"
# MYSQL_INSTANCE_NAME 是 Co-Signer Cloud SQL instance 名稱；格式為 GCP 資源名稱。
MYSQL_INSTANCE_NAME="${PROJECT_NAME}-cosigner-mysql"
# NETWORK_NAME 是 Co-Signer subnet 所屬的 VPC 名稱；格式為 GCP VPC 資源名稱。
NETWORK_NAME="${PROJECT_NAME}-vpc"
# COSIGNER_SUBNET_NAME 是 Co-Signer VM 使用的 subnet 名稱；格式為 GCP subnet 資源名稱。
COSIGNER_SUBNET_NAME="${PROJECT_NAME}-cosigner-subnet"
# COSIGNER_SUBNET_CIDR 是 Co-Signer subnet 的 IPv4 CIDR；格式為網路位址/前綴長度，例如 10.40.0.0/24。
COSIGNER_SUBNET_CIDR="10.40.0.0/24"
