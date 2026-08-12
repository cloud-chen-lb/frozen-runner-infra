# Main application network configuration. Values are non-secret.
MAIN_APP_SUBNET_CIDR="10.20.0.0/24"
PRIVATE_SERVICES_RANGE_CIDR="10.30.0.0/16"

NETWORK_NAME="${PROJECT_NAME}-vpc"
MAIN_APP_SUBNET_NAME="${PROJECT_NAME}-main-app-subnet"
PRIVATE_SERVICES_RANGE_NAME="${PROJECT_NAME}-private-services-range"
ROUTER_NAME="${PROJECT_NAME}-router"
EGRESS_IP_NAME="${PROJECT_NAME}-main-app-egress-ip"
NAT_NAME="${PROJECT_NAME}-main-app-nat"
