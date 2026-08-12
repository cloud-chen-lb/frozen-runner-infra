# 主應用程式網路設定，值均為非秘密資料。
# 會被 00_env.sh 驗證並供 VPC、subnet、Private Services Access、Router/NAT 腳本使用。
# 這些名稱與 CIDR 會建立或比對 GCP 網路資源；變更既有 CIDR 前須先確認相容性。
MAIN_APP_SUBNET_CIDR="10.20.0.0/24"
PRIVATE_SERVICES_RANGE_CIDR="10.30.0.0/16"

NETWORK_NAME="${PROJECT_NAME}-vpc"
MAIN_APP_SUBNET_NAME="${PROJECT_NAME}-main-app-subnet"
PRIVATE_SERVICES_RANGE_NAME="${PROJECT_NAME}-private-services-range"
ROUTER_NAME="${PROJECT_NAME}-router"
EGRESS_IP_NAME="${PROJECT_NAME}-main-app-egress-ip"
NAT_NAME="${PROJECT_NAME}-main-app-nat"
