# 主應用程式網路設定，值均為非秘密資料；由 00_env.sh 驗證後供 VPC、subnet、
# Private Services Access、Cloud Router/NAT 腳本使用。CIDR 為「網路位址/前綴長度」，
# 需填入尚未與既有 VPC 資源重疊的私有 IPv4 網段；變更既有 CIDR 前須確認相容性。
# MAIN_APP_SUBNET_CIDR 是主應用程式 subnet 的 IPv4 CIDR，格式為例如 10.20.0.0/24。
MAIN_APP_SUBNET_CIDR="10.20.0.0/24"
# COSIGNER_SUBNET_CIDR 是 Co-Signer VM subnet 的 IPv4 CIDR，格式為例如 10.40.0.0/24。
COSIGNER_SUBNET_CIDR="10.40.0.0/24"
# PRIVATE_SERVICES_RANGE_CIDR 是 Cloud SQL Private Services Access 保留範圍的 IPv4 CIDR，格式為例如 10.30.0.0/16。
PRIVATE_SERVICES_RANGE_CIDR="10.30.0.0/16"

# NETWORK_NAME 是 custom-mode VPC 名稱；格式為 GCP 資源名稱，通常由 PROJECT_NAME 加上 -vpc 產生。
NETWORK_NAME="${PROJECT_NAME}-vpc"
# MAIN_APP_SUBNET_NAME 是主應用程式 subnet 名稱；由 PROJECT_NAME 加上 -main-app-subnet 產生。
MAIN_APP_SUBNET_NAME="${PROJECT_NAME}-main-app-subnet"
# COSIGNER_SUBNET_NAME 是 Co-Signer VM subnet 名稱；由 PROJECT_NAME 加上 -cosigner-subnet 產生。
COSIGNER_SUBNET_NAME="${PROJECT_NAME}-cosigner-subnet"
# PRIVATE_SERVICES_RANGE_NAME 是 Private Services Access 保留範圍名稱；由 PROJECT_NAME 加上 -private-services-range 產生。
PRIVATE_SERVICES_RANGE_NAME="${PROJECT_NAME}-private-services-range"
# ROUTER_NAME 是 Cloud Router 名稱；由 PROJECT_NAME 加上 -router 產生，供主應用程式 Cloud NAT 使用。
ROUTER_NAME="${PROJECT_NAME}-router"
# EGRESS_IP_NAME 是主應用程式 Cloud NAT 固定出口 IP 的保留名稱；由 PROJECT_NAME 加上 -main-app-egress-ip 產生。
EGRESS_IP_NAME="${PROJECT_NAME}-main-app-egress-ip"
# NAT_NAME 是主應用程式 Cloud NAT 名稱；由 PROJECT_NAME 加上 -main-app-nat 產生。
NAT_NAME="${PROJECT_NAME}-main-app-nat"
