# PostgreSQL configuration. Passwords are supplied outside repository files.
POSTGRES_DATABASE_NAME="frozen_runner"
POSTGRES_APP_USER="frozen_runner_app"
POSTGRES_MIGRATION_USER="frozen_runner_migration"
POSTGRES_VERSION="POSTGRES_16"
POSTGRES_TIER="db-custom-2-7680"
POSTGRES_STORAGE_GB="20"

POSTGRES_NETWORK_NAME="${PROJECT_NAME}-vpc"
POSTGRES_INSTANCE_NAME="${PROJECT_NAME}-main-app-postgres"
