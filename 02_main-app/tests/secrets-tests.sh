#!/usr/bin/env bash
# 用途：驗證 Secret Manager mapping、service account、IAM lifecycle 與輸入拒絕行為。
# 流程：以暫存 env/mock gcloud 執行 invalid/valid mapping、drift、重複 key/name 與權限測試。
# 重要變數：ROOT_DIR、LOADER、PATH、APP_SECRET_MAPPING/MIGRATION_SECRET_MAPPING；資源影響：只建立暫存檔與 mock log。
# 安全/驗證限制：不建立真實 secret、不寫入 secret version，命令檢查無法取代 GCP IAM 實際驗證。
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOADER="${ROOT_DIR}/02_main-app/scripts/00_env.sh"

test_invalid_env_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN

  cat >"${temp_dir}/global-env.sh" <<'EOF'
PROJECT_NAME=frozen-runner
GOOGLE_PROJECT_ID=echox-project
GOOGLE_PROJECT_REGION=asia-east1
EXEC_IAM_ACCOUNT=cloud.chen@getoken.io
EOF
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING=APP_SECRET=bad:latest
MIGRATION_SECRET_MAPPING=APP_DATABASE_URL=frozen-runner-migration-database-url:latest
POSTGRES_DATABASE_NAME=frozen_runner
POSTGRES_APP_USER=frozen_runner_app
POSTGRES_MIGRATION_USER=frozen_runner_migration
POSTGRES_VERSION=POSTGRES_16
POSTGRES_EDITION=ENTERPRISE
POSTGRES_CPU=1
POSTGRES_MEMORY_MB=3840
POSTGRES_STORAGE_GB=20
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"

  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
    MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected invalid main-app env to fail\n' >&2
    return 1
  fi
  [[ ! -s "${gcloud_calls}" ]]
}

test_missing_accessor_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_SECRET=bad:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-migration-database-url:latest'
POSTGRES_DATABASE_NAME=frozen_runner
POSTGRES_APP_USER=frozen_runner_app
POSTGRES_MIGRATION_USER=frozen_runner_migration
POSTGRES_VERSION=POSTGRES_16
POSTGRES_EDITION=ENTERPRISE
POSTGRES_CPU=1
POSTGRES_MEMORY_MB=3840
POSTGRES_STORAGE_GB=20
POSTGRES_NETWORK_NAME=frozen-runner-vpc
POSTGRES_INSTANCE_NAME=frozen-runner-main-app-postgres
APP_SERVICE_ACCOUNT_NAME=bad_name
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" MODULE_ENV_FILE="${temp_dir}/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected missing accessor to fail\n' >&2
    return 1
  fi
  [[ ! -s "${gcloud_calls}" ]]
}

test_invalid_accessor_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_SECRET=bad:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-migration-database-url:latest'
POSTGRES_DATABASE_NAME=frozen_runner
POSTGRES_APP_USER=frozen_runner_app
POSTGRES_MIGRATION_USER=frozen_runner_migration
POSTGRES_VERSION=POSTGRES_16
POSTGRES_EDITION=ENTERPRISE
POSTGRES_CPU=1
POSTGRES_MEMORY_MB=3840
POSTGRES_STORAGE_GB=20
POSTGRES_NETWORK_NAME=frozen-runner-vpc
POSTGRES_INSTANCE_NAME=frozen-runner-main-app-postgres
APP_SERVICE_ACCOUNT_NAME='cb-frozen-runner-mini@echox-project.iam.gserviceaccount.com'
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" MODULE_ENV_FILE="${temp_dir}/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected invalid accessor to fail\n' >&2
    return 1
  fi
  [[ ! -s "${gcloud_calls}" ]]
}

test_valid_env_loads() {
  bash "${LOADER}" >/dev/null
}

test_valid_env_can_be_sourced() {
  (
    source "${LOADER}"
    [[ -n "${APP_SECRET_MAPPING:-}" ]]
  )
}

test_secret_mapping_contract() {
  source "${LOADER}"
  [[ "${APP_SECRET_MAPPING}" == *'APP_INTERNAL_ADMIN_PASSWORD='* ]]
  [[ "${APP_SECRET_MAPPING}" == *'APP_ALERT_API_BEARER_TOKEN='* ]]
  [[ "${APP_SECRET_MAPPING}" == *'APP_DATA_ENCRYPTION_SECRET='* ]]
  [[ "${APP_SECRET_MAPPING}" == *'APP_DATABASE_URL='* ]]
  [[ "${APP_SECRET_MAPPING}" == *'APP_MAILGUN_API_KEY='* ]]
  [[ "${APP_SECRET_MAPPING}" != *'APP_SECRET='* ]]
  [[ "${MIGRATION_SECRET_MAPPING}" == "APP_DATABASE_URL=frozen-runner-migration-database-url:latest" ]]
  [[ "${MIGRATION_SECRET_MAPPING}" != 'DATABASE_URL='* ]]
  [[ "${MIGRATION_SECRET_MAPPING}" != *',DATABASE_URL='* ]]
  [[ "${MIGRATION_SECRET_MAPPING}" != 'DATABASE_USER='* ]]
  [[ "${MIGRATION_SECRET_MAPPING}" != *',DATABASE_USER='* ]]
  [[ "${APP_SECRET_MAPPING}" != *'frozen-runner-migration-database-url'* ]]
}

test_dynamic_secret_mapping_is_created() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_INTERNAL_ADMIN_PASSWORD=frozen-runner-app-internal-admin-password:latest,APP_NEW_RUNTIME_SECRET=frozen-runner-app-new-runtime-secret:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-migration-database-url:latest'
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2" == "secrets describe" ]]; then exit 1; fi
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" MODULE_ENV_FILE="${temp_dir}/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected secret setup to succeed\n' >&2
    return 1
  fi
  grep -F 'secrets create frozen-runner-app-new-runtime-secret --replication-policy=automatic' "${log}"
  grep -F 'secrets add-iam-policy-binding frozen-runner-app-new-runtime-secret --member=serviceAccount:cb-frozen-runner-mini@echox-project.iam.gserviceaccount.com' "${log}"
}

test_cross_mapping_secret_name_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_FIRST_SECRET=frozen-runner-duplicate-secret:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-duplicate-secret:latest'
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH=":${PATH}" GLOBAL_ENV_FILE="/global-env.sh" MODULE_ENV_FILE="/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected app/migration secret name reuse to fail\n' >&2
    return 1
  fi
  [[ ! -s "${gcloud_calls}" ]]
}

test_duplicate_key_mapping_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_DUPLICATE_SECRET=frozen-runner-first-secret:latest,APP_DUPLICATE_SECRET=frozen-runner-second-secret:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-migration-database-url:latest'
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH=":${PATH}" GLOBAL_ENV_FILE="/global-env.sh" MODULE_ENV_FILE="/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected duplicate secret key to fail\n' >&2
    return 1
  fi
  [[ ! -s "${gcloud_calls}" ]]
}

test_role_lifecycle_arguments() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "iam roles describe" && -z "\${ROLE_EXISTS:-}" ]]; then exit 1; fi
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create SecretManagerProvisioningOperator' "${log}")"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update SecretManagerProvisioningOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/99_remove-exec-iam-account-role.sh"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  [[ "${create_permissions}" == *'secretmanager.versions.add'* ]]
  [[ "${create_permissions}" != *'secretmanager.versions.access'* ]]
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/SecretManagerProvisioningOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/SecretManagerProvisioningOperator' "${log}"
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY' "${log}"
}

test_service_accounts_and_deploy_iam() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "iam service-accounts describe" ]]; then exit 1; fi
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/17_setup-service-accounts.sh"
  grep -F 'iam service-accounts create cb-frozen-runner-mini' "${log}"
  grep -F 'iam service-accounts create cb-frozen-runner-migration' "${log}"
  grep -F 'iam service-accounts create cb-frozen-runner-deploy' "${log}"
  grep -F 'iam service-accounts create cb-frozen-runner-deploy --display-name=frozen-runner production deploy' "${log}"
  ! grep -F 'cb-frozen-runner-deploy --display-name=frozen-runner 正式環境部署' "${log}"
  grep -F 'projects add-iam-policy-binding echox-project --member=serviceAccount:cb-frozen-runner-deploy@echox-project.iam.gserviceaccount.com --role=roles/run.admin' "${log}"
  grep -F 'projects add-iam-policy-binding echox-project --member=serviceAccount:cb-frozen-runner-deploy@echox-project.iam.gserviceaccount.com --role=roles/artifactregistry.reader' "${log}"
  grep -F 'iam service-accounts add-iam-policy-binding cb-frozen-runner-mini@echox-project.iam.gserviceaccount.com --member=serviceAccount:cb-frozen-runner-deploy@echox-project.iam.gserviceaccount.com --role=roles/iam.serviceAccountUser' "${log}"
  grep -F 'iam service-accounts add-iam-policy-binding cb-frozen-runner-migration@echox-project.iam.gserviceaccount.com --member=serviceAccount:cb-frozen-runner-deploy@echox-project.iam.gserviceaccount.com --role=roles/iam.serviceAccountUser' "${log}"
  ! grep -Eiq 'secretmanager.*admin|owner|editor|iam.serviceAccountKey|create.*key|\.json|password=|secret-value' "${log}"
}

test_service_account_display_name_is_not_contract() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2 $3" == "iam service-accounts describe" ]]; then
  printf 'wrong-display-name\n'
fi
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/17_setup-service-accounts.sh"
}

test_secrets_metadata_and_scoped_accessors() {
  local temp_dir log item key secret_name
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2" == "secrets describe" ]]; then exit 1; fi
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"
  IFS=',' read -r -a app_items <<<"${APP_SECRET_MAPPING}"
  for item in "${app_items[@]}"; do
    secret_name="${item#*=}"
    secret_name="${secret_name%:*}"
    grep -F "secrets create ${secret_name} --replication-policy=automatic" "${log}"
    grep -F "secrets add-iam-policy-binding ${secret_name} --member=serviceAccount:cb-frozen-runner-mini@echox-project.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor" "${log}"
  done
  secret_name="${MIGRATION_SECRET_MAPPING#*=}"
  secret_name="${secret_name%:*}"
  grep -F "secrets create ${secret_name} --replication-policy=automatic" "${log}"
  grep -F "secrets add-iam-policy-binding ${secret_name} --member=serviceAccount:cb-frozen-runner-migration@echox-project.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor" "${log}"
  ! grep -Eiq 'versions add|secret-value|password|private[_-]?key|\.json' "${log}"
}

test_secret_drift_fails() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "secrets describe" ]]; then
  printf 'False\n'
  exit 0
fi
printf 'gcloud must not be called after secret drift\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected secret replication drift to fail\n' >&2
    return 1
  fi
}

test_invalid_secret_mapping_fails_before_gcloud() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
cat >"${temp_dir}/module-env.sh" <<'EOF'
APP_SECRET_MAPPING='APP_SECRET=bad value:latest'
MIGRATION_SECRET_MAPPING='APP_DATABASE_URL=frozen-runner-migration-database-url:latest'
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf 'gcloud must not be called\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  GLOBAL_ENV_FILE="${temp_dir}/global-env.sh"
  MODULE_ENV_FILE="${temp_dir}/module-env.sh"
  if PATH=":${PATH}" GLOBAL_ENV_FILE="/global-env.sh" MODULE_ENV_FILE="/module-env.sh" \
    bash "${ROOT_DIR}/02_main-app/scripts/18_setup-secrets.sh"; then
    printf 'Expected invalid secret mapping to fail\n' >&2
    return 1
  fi
}

test_invalid_env_fails_before_gcloud
test_missing_accessor_fails_before_gcloud
test_invalid_accessor_fails_before_gcloud
test_valid_env_loads
test_valid_env_can_be_sourced
test_secret_mapping_contract
test_dynamic_secret_mapping_is_created
test_role_lifecycle_arguments
test_service_accounts_and_deploy_iam
test_service_account_display_name_is_not_contract
test_secrets_metadata_and_scoped_accessors
test_secret_drift_fails
test_invalid_secret_mapping_fails_before_gcloud
test_cross_mapping_secret_name_fails_before_gcloud
test_duplicate_key_mapping_fails_before_gcloud
printf 'secrets scripts tests passed\n'
