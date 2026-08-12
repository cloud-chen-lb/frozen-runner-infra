# Runtime secret mappings only contain Secret Manager metadata, never values.
APP_SECRET_MAPPING="APP_SECRET=${PROJECT_NAME}-main-app-secret:latest"
MIGRATION_SECRET_MAPPING="DATABASE_URL=${PROJECT_NAME}-database-url:latest,DATABASE_USER=${PROJECT_NAME}-database-user:latest"

APP_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-mini"
MIGRATION_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-migration"
DEPLOY_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-deploy"
