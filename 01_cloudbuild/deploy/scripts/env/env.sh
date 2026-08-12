# Deployment metadata only. Secret mappings are configured by main-app env.
CLOUD_BUILD_SOURCE_BRANCH="main"
# Non-secret Cloud Run deployment flags.
APP_VPC_ARGS="--network=${PROJECT_NAME}-vpc --subnet=${PROJECT_NAME}-main-app-subnet --vpc-egress=all-traffic"
MIGRATION_VPC_ARGS="--network=${PROJECT_NAME}-vpc --subnet=${PROJECT_NAME}-main-app-subnet --vpc-egress=all-traffic"
# Optional: leave empty until the existing load balancer URL is confirmed.
DEPLOY_SMOKE_TEST_URL=""

PRODUCTION_TRIGGER_NAME="${PROJECT_NAME}-production-deploy-trigger"
PRODUCTION_APP_NAME="${PROJECT_NAME}-main-app"
PRODUCTION_MIGRATION_JOB_NAME="${PROJECT_NAME}-db-migration"
