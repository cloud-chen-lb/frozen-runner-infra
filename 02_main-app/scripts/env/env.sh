# 主應用程式模組的所有非機密設定與 mapping。密碼與 secret value 不得放在本檔。
# CLOUD_BUILD_CONNECTION_NAME 是 Cloud Build GitHub connection 名稱；格式為既有 connection 的資源名稱，部署前必須填妥。
CLOUD_BUILD_CONNECTION_NAME="Github_Connect"
# CLOUD_BUILD_REPOSITORY_NAME 是 Cloud Build v2 repository 名稱；格式為既有 repository 資源名稱，部署前必須填妥。
CLOUD_BUILD_REPOSITORY_NAME="echox-project-frozen-runner"

# POSTGRES_IDENTIFIER_PREFIX 是 PostgreSQL 識別字首；由 PROJECT_NAME 將連字號替換為底線產生。
POSTGRES_IDENTIFIER_PREFIX="${PROJECT_NAME//-/_}"
# POSTGRES_DATABASE_NAME 是主應用程式 PostgreSQL database 名稱；格式為資料庫識別字串，由識別字首產生。
POSTGRES_DATABASE_NAME="${POSTGRES_IDENTIFIER_PREFIX}"
# POSTGRES_APP_USER 是主應用程式 runtime database user 名稱；格式為識別字串，由識別字首加 _app 產生。
POSTGRES_APP_USER="${POSTGRES_IDENTIFIER_PREFIX}_app"
# POSTGRES_MIGRATION_USER 是 migration 專用 PostgreSQL user 名稱；格式為識別字串，由識別字首加 _migration 產生。
POSTGRES_MIGRATION_USER="${POSTGRES_IDENTIFIER_PREFIX}_migration"
# POSTGRES_VERSION 是 Cloud SQL PostgreSQL 引擎版本；格式為 gcloud database-version 值，例如 POSTGRES_16。
POSTGRES_VERSION="POSTGRES_16"
# POSTGRES_EDITION 是 Cloud SQL edition；格式為 gcloud edition 值，目前使用 ENTERPRISE。
POSTGRES_EDITION="ENTERPRISE"
# POSTGRES_CPU 是 Cloud SQL vCPU 數量；格式為正整數，單位為 vCPU。
POSTGRES_CPU="1"
# POSTGRES_MEMORY_MB 是 Cloud SQL 記憶體；格式為正整數，單位為 MB，腳本會加上 MB 傳給 gcloud。
POSTGRES_MEMORY_MB="3840"
# POSTGRES_STORAGE_GB 是 Cloud SQL 儲存空間；格式為正整數，單位為 GB。
POSTGRES_STORAGE_GB="20"
# POSTGRES_NETWORK_NAME 是 PostgreSQL Private IP 使用的 VPC 名稱；格式為 GCP VPC 資源名稱。
POSTGRES_NETWORK_NAME="${PROJECT_NAME}-vpc"
# POSTGRES_INSTANCE_NAME 是主應用程式 Cloud SQL instance 名稱；格式為 GCP 資源名稱。
POSTGRES_INSTANCE_NAME="${PROJECT_NAME}-main-app-postgres"

# 以下網路名稱與 CIDR 必須對應 shared resources 的既有 VPC/subnet；CIDR 格式為網路位址/前綴長度。
# NETWORK_NAME 是 Cloud Run 與 migration 使用的 VPC 名稱。
NETWORK_NAME="${PROJECT_NAME}-vpc"
# MAIN_APP_SUBNET_NAME 是主應用程式 subnet 名稱。
MAIN_APP_SUBNET_NAME="${PROJECT_NAME}-main-app-subnet"
# MAIN_APP_SUBNET_CIDR 是主應用程式 subnet 的 IPv4 CIDR，格式例如 10.20.0.0/24。
MAIN_APP_SUBNET_CIDR="10.20.0.0/24"
# ROUTER_NAME 是主應用程式 Cloud Router 名稱。
ROUTER_NAME="${PROJECT_NAME}-router"
# EGRESS_IP_NAME 是主應用程式 Cloud NAT 固定出口 IP 名稱。
EGRESS_IP_NAME="${PROJECT_NAME}-main-app-egress-ip"
# NAT_NAME 是主應用程式 Cloud NAT 名稱。
NAT_NAME="${PROJECT_NAME}-main-app-nat"

# CLOUD_BUILD_SOURCE_BRANCH 是手動 release trigger 使用的來源分支；格式為 Git 分支名稱。
CLOUD_BUILD_SOURCE_BRANCH="master"
# APP_SECRET_MAPPING 是 Cloud Run app 的 secret mapping；格式為逗號分隔的 ENV_VAR=SECRET_NAME:VERSION，值只能是 secret 資源名稱與版本。
APP_SECRET_MAPPING="APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest"
# MIGRATION_SECRET_MAPPING 是 migration job 的 secret mapping；格式同 APP_SECRET_MAPPING，使用逗號分隔 ENV_VAR=SECRET_NAME:VERSION。
MIGRATION_SECRET_MAPPING="APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest"
# APP_RUNTIME_ENV_VARS 是非機密 app runtime 環境變數；格式為逗號分隔的 KEY=VALUE，會傳給 Cloud Run。
APP_RUNTIME_ENV_VARS="NEXT_PUBLIC_APP_DEFAULT_LOCALE=zh-TW,NEXT_PUBLIC_APP_LOG_LEVEL=log,APP_INTERNAL_ADMIN_USERNAME=product@echox.io,APP_ALERT_API_IP_ALLOWLIST=18.182.103.63,APP_PUBLIC_BASE_URL=https://frozen-runner.echox.io,APP_FROZEN_ALERT_BASE_URL=https://api.frozenalert.com,APP_MAIL_PROVIDER=mailgun,APP_MAILGUN_DOMAIN=mg.echox.app,APP_MAILGUN_API_URL=https://api.mailgun.net,APP_EMAIL_FROM=noreply@mg.echox.app"
# MIGRATION_RUNTIME_ENV_VARS 是 migration job 的非機密 runtime 變數；空值代表暫不覆寫平台或腳本預設，若 migration 需要值應在部署時設定。
MIGRATION_RUNTIME_ENV_VARS=""
# 以下 APP_* 空值代表暫不覆寫 Cloud Run 對應設定，使用平台或部署腳本預設；需要自訂資源限制時才填入要求的 gcloud flag 值。
# APP_MIN_INSTANCE 是最小 instance 數；格式為非負整數，單位為 instance 數量。
APP_MIN_INSTANCE=""
# APP_MAX_INSTANCE 是最大 instance 數；格式為非負整數，單位為 instance 數量。
APP_MAX_INSTANCE=""
# APP_CPU 是 Cloud Run container CPU；格式為 gcloud 可接受的 CPU 值，空值代表使用平台或腳本預設。
APP_CPU=""
# APP_MEMORY 是 Cloud Run container 記憶體；格式為 gcloud 記憶體值，例如 512Mi 或 1Gi，空值代表使用平台或腳本預設。
APP_MEMORY=""
# APP_TIMEOUT 是 Cloud Run request timeout；格式為 gcloud duration，例如 300s，空值代表使用平台或腳本預設。
APP_TIMEOUT=""
# APP_CONCURRENCY 是每個 instance 的 request concurrency；格式為非負整數，空值代表使用平台或腳本預設。
APP_CONCURRENCY=""
# APP_SERVICE_ACCOUNT_NAME 是主應用程式 Cloud Run runtime service account 名稱；格式為 GCP service account 名稱。
APP_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-mini"
# MIGRATION_SERVICE_ACCOUNT_NAME 是 migration job runtime service account 名稱；格式為 GCP service account 名稱。
MIGRATION_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-migration"
# DEPLOY_SERVICE_ACCOUNT_NAME 是 production deploy Cloud Build service account 名稱；格式為 GCP service account 名稱。
DEPLOY_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-deploy"

# APP_VPC_ARGS 是 Cloud Run app 的網路 flags；格式為可直接交給 gcloud run 的空白分隔 flag 字串。
APP_VPC_ARGS="--network=${NETWORK_NAME} --subnet=${MAIN_APP_SUBNET_NAME} --vpc-egress=all-traffic"
# MIGRATION_VPC_ARGS 是 migration job 的網路 flags；格式同 APP_VPC_ARGS。
MIGRATION_VPC_ARGS="--network=${NETWORK_NAME} --subnet=${MAIN_APP_SUBNET_NAME} --vpc-egress=all-traffic"
# DEPLOY_SMOKE_TEST_URL 是 production deploy 後 smoke test 的 URL；格式為完整 HTTP(S) URL。
# 空值代表暫不執行此 URL 覆寫，使用平台或腳本預設；若部署流程要求 smoke test，請在部署時填入。
DEPLOY_SMOKE_TEST_URL=""
# PRODUCTION_TRIGGER_NAME 是正式部署 Cloud Build trigger 名稱；格式為 GCP trigger 資源名稱。
PRODUCTION_TRIGGER_NAME="${PROJECT_NAME}-production-deploy-trigger"
# PRODUCTION_APP_NAME 是正式 Cloud Run service 名稱；格式為 GCP service 資源名稱。
PRODUCTION_APP_NAME="${PROJECT_NAME}-main-app"
# PRODUCTION_MIGRATION_JOB_NAME 是正式 migration Cloud Run Job 名稱；格式為 GCP job 資源名稱。
PRODUCTION_MIGRATION_JOB_NAME="${PROJECT_NAME}-db-migration"
