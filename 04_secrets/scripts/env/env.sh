# Runtime secret mapping 只包含 Secret Manager metadata，絕不包含秘密值。
# APP/MIGRATION mapping 決定部署時的環境變數 key、secret 名稱與 version；service account 名稱決定 accessor 範圍。
# 這些設定會被 setup-secrets 與部署腳本驗證，變更名稱前須確認既有服務與 IAM 綁定。
APP_SECRET_MAPPING="APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest"
MIGRATION_SECRET_MAPPING="APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest"

APP_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-mini"
MIGRATION_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-migration"
DEPLOY_SERVICE_ACCOUNT_NAME="cb-${PROJECT_NAME}-deploy"
