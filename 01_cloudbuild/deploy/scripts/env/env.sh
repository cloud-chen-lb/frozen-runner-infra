# Defaults mirror cicd/prod/cloudbuild-deploy.yaml. Values are metadata only.
: "${CLOUD_BUILD_SOURCE_BRANCH:=master}"
: "${APP_SECRET_MAPPING:=APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest}"
: "${MIGRATION_SECRET_MAPPING:=APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest}"
: "${APP_RUNTIME_ENV_VARS:=APP_INTERNAL_ADMIN_USERNAME=${PROJECT_NAME}-app-internal-admin-username,APP_ALERT_API_IP_ALLOWLIST=${PROJECT_NAME}-app-alert-api-ip-allowlist,APP_PUBLIC_BASE_URL=${PROJECT_NAME}-app-public-base-url,APP_FROZEN_ALERT_BASE_URL=${PROJECT_NAME}-app-frozen-alert-base-url,APP_MAIL_PROVIDER=${PROJECT_NAME}-app-mail-provider,APP_MAILGUN_DOMAIN=${PROJECT_NAME}-app-mailgun-domain,APP_MAILGUN_API_URL=${PROJECT_NAME}-app-mailgun-api-url,APP_EMAIL_FROM=${PROJECT_NAME}-app-email-from}"
: "${MIGRATION_RUNTIME_ENV_VARS:=}"
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
