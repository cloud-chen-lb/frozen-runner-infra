# 用途：提供 app/migration Secret Manager metadata mapping 與 accessor 帳號名稱。
# 流程：由 00_env.sh 載入，供 secret 建立、IAM binding 與 production deployment 使用。
# 重要變數：APP_SECRET_MAPPING、MIGRATION_SECRET_MAPPING、APP_SERVICE_ACCOUNT_NAME。
# 資源影響：只定義 mapping，不建立資源或寫入秘密；安全/驗證限制：key/name 由使用腳本驗證。
: "${APP_SECRET_MAPPING:=APP_INTERNAL_ADMIN_PASSWORD=${PROJECT_NAME}-app-internal-admin-password:latest,APP_ALERT_API_BEARER_TOKEN=${PROJECT_NAME}-app-alert-api-bearer-token:latest,APP_DATA_ENCRYPTION_SECRET=${PROJECT_NAME}-app-data-encryption-secret:latest,APP_DATABASE_URL=${PROJECT_NAME}-app-database-url:latest,APP_MAILGUN_API_KEY=${PROJECT_NAME}-app-mailgun-api-key:latest}"
: "${MIGRATION_SECRET_MAPPING:=APP_DATABASE_URL=${PROJECT_NAME}-migration-database-url:latest}"

: "${APP_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-mini}"
: "${MIGRATION_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-migration}"
: "${DEPLOY_SERVICE_ACCOUNT_NAME:=cb-${PROJECT_NAME}-deploy}"
