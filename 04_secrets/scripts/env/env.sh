# Runtime secret mappings only contain Secret Manager metadata, never values.
APP_SECRET_MAPPING="APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest"
MIGRATION_SECRET_MAPPING="APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest"

APP_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-mini"
MIGRATION_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-migration"
DEPLOY_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-deploy"
