# 用途：提供 production Cloud Build/Cloud Run deployment metadata，不含秘密值。
# 流程：由 00_env.sh 載入，供 production trigger、部署與 smoke-test 腳本使用。
# 重要變數：APP_VPC_ARGS、MIGRATION_VPC_ARGS、APP_MIN_INSTANCE、APP_MAX_INSTANCE。
# 資源影響：設定會影響 Cloud Run 網路、autoscaling 與容器規格；安全/驗證限制：mapping 與 override 由部署腳本驗證。
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
