# 預設值對應 cicd/prod/cloudbuild-deploy.yaml，內容是部署 metadata，不是秘密值。
# 供 production trigger 與部署腳本使用；mapping 只指向 Secret Manager 名稱/version。
# APP_VPC_ARGS、MIGRATION_VPC_ARGS 會選定 Cloud Run 網路；DEPLOY_SMOKE_TEST_URL 留空時不做 HTTP 驗證。
# APP_MIN_INSTANCE/APP_MAX_INSTANCE 控制 autoscaling 範圍；APP_CPU/APP_MEMORY 控制容器資源。
# APP_TIMEOUT/APP_CONCURRENCY 控制 request timeout 與每個 instance 的並行 request 數。
: "${CLOUD_BUILD_SOURCE_BRANCH:=master}"
: "${APP_SECRET_MAPPING:=APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest}"
: "${MIGRATION_SECRET_MAPPING:=APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest}"
: "${APP_RUNTIME_ENV_VARS:=NEXT_PUBLIC_APP_DEFAULT_LOCALE=zh-TW,NEXT_PUBLIC_APP_LOG_LEVEL=log,APP_INTERNAL_ADMIN_USERNAME=product@echox.io,APP_ALERT_API_IP_ALLOWLIST=18.182.103.63,APP_PUBLIC_BASE_URL=https://frozen-runner.echox.io,APP_FROZEN_ALERT_BASE_URL=https://api.frozenalert.com,APP_MAIL_PROVIDER=mailgun,APP_MAILGUN_DOMAIN=mg.echox.app,APP_MAILGUN_API_URL=https://api.mailgun.net,APP_EMAIL_FROM=noreply@mg.echox.app}"
: "${MIGRATION_RUNTIME_ENV_VARS:=}"
: "${APP_MIN_INSTANCE:=}"
: "${APP_MAX_INSTANCE:=}"
: "${APP_CPU:=}"
: "${APP_MEMORY:=}"
: "${APP_TIMEOUT:=}"
: "${APP_CONCURRENCY:=}"
: "${APP_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-mini}"
: "${MIGRATION_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-migration}"
: "${DEPLOY_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-deploy}"
# Non-secret Cloud Run deployment flags.
APP_VPC_ARGS="--network=${PROJECT_NAME}-vpc --subnet=${PROJECT_NAME}-main-app-subnet --vpc-egress=all-traffic"
MIGRATION_VPC_ARGS="--network=${PROJECT_NAME}-vpc --subnet=${PROJECT_NAME}-main-app-subnet --vpc-egress=all-traffic"
# Optional: leave empty until the existing load balancer URL is confirmed.
DEPLOY_SMOKE_TEST_URL=""

PRODUCTION_TRIGGER_NAME="${PROJECT_NAME}-production-deploy-trigger"
PRODUCTION_APP_NAME="${PROJECT_NAME}-main-app"
PRODUCTION_MIGRATION_JOB_NAME="${PROJECT_NAME}-db-migration"
