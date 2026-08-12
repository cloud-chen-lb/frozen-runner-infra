#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOADER="${ROOT_DIR}/01_cloudbuild/deploy/scripts/00_env.sh"

test_invalid_env_fails_before_gcloud() {
  local temp_dir gcloud_calls
  temp_dir="$(mktemp -d)"
  gcloud_calls="${temp_dir}/gcloud.calls"
  trap 'rm -rf "$temp_dir"' RETURN

  cat >"${temp_dir}/global-env.sh" <<'EOF'
PROJECT_NAME=frozen-runner
GOOGLE_PROJECT_ID=echox-project
GOOGLE_PROJECT_REGION=asia-east1
EXEC_IAM_ACCOUNT=
EOF
  cat >"${temp_dir}/module-env.sh" <<'EOF'
CLOUD_BUILD_SOURCE_BRANCH=main
DEPLOY_SMOKE_TEST_URL=https://example.invalid/health
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"

  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
    MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${LOADER}"; then
    printf 'Expected invalid deploy env to fail\n' >&2
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
    [[ -n "${CLOUD_BUILD_SOURCE_BRANCH:-}" ]]
  )
}

test_service_account_ids_reject_non_bare_before_gcloud() {
  local temp_dir log variable value
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/global-env.sh" <<'EOF'
PROJECT_NAME=frozen-runner
GOOGLE_PROJECT_ID=echox-project
GOOGLE_PROJECT_REGION=asia-east1
EXEC_IAM_ACCOUNT=cloud.chen@getoken.io
EOF
  cat >"${temp_dir}/module-env.sh" <<'EOF'
CLOUD_BUILD_SOURCE_BRANCH=main
DEPLOY_SMOKE_TEST_URL=
APP_VPC_ARGS='--network=frozen-runner-vpc --subnet=frozen-runner-main-app-subnet --vpc-egress=all-traffic'
MIGRATION_VPC_ARGS='--network=frozen-runner-vpc --subnet=frozen-runner-main-app-subnet --vpc-egress=all-traffic'
PRODUCTION_TRIGGER_NAME=frozen-runner-production-deploy-trigger
PRODUCTION_APP_NAME=frozen-runner-main-app
PRODUCTION_MIGRATION_JOB_NAME=frozen-runner-db-migration
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${log}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"

  for variable in APP_SERVICE_ACCOUNT_NAME MIGRATION_SERVICE_ACCOUNT_NAME DEPLOY_SERVICE_ACCOUNT_NAME; do
    while IFS= read -r value; do
      cat >"${temp_dir}/main-app-env.sh" <<EOF
APP_SECRET_MAPPING=APP_SECRET=frozen-runner-main-app-secret:latest
MIGRATION_SECRET_MAPPING=DATABASE_URL=frozen-runner-database-url:latest
APP_SERVICE_ACCOUNT_NAME=cb-frozen-runner-mini
MIGRATION_SERVICE_ACCOUNT_NAME=cb-frozen-runner-migration
DEPLOY_SERVICE_ACCOUNT_NAME=cb-frozen-runner-deploy
EOF
      case "${variable}" in
        APP_SERVICE_ACCOUNT_NAME) printf 'APP_SERVICE_ACCOUNT_NAME=%s\n' "${value}" >>"${temp_dir}/main-app-env.sh" ;;
        MIGRATION_SERVICE_ACCOUNT_NAME) printf 'MIGRATION_SERVICE_ACCOUNT_NAME=%s\n' "${value}" >>"${temp_dir}/main-app-env.sh" ;;
        DEPLOY_SERVICE_ACCOUNT_NAME) printf 'DEPLOY_SERVICE_ACCOUNT_NAME=%s\n' "${value}" >>"${temp_dir}/main-app-env.sh" ;;
      esac
      if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
        MODULE_ENV_FILE="${temp_dir}/module-env.sh" MAIN_APP_ENV_FILE="${temp_dir}/main-app-env.sh" \
        bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/04_run-production-deploy.sh" v1.2.3; then
        printf 'Expected invalid %s=%s to fail\n' "${variable}" "${value}" >&2
        return 1
      fi
    done <<'EOF'
cb-frozen-runner-mini@echox-project.iam.gserviceaccount.com
cb-frozen-runner-mini.echox-project
cb-frozen-runner-mini/slash

cb-frozen-runner-mini_bad
EOF
  done
  [[ ! -s "${log}" ]]
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
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create CloudBuildDeployProvisioningOperator' "${log}")"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update CloudBuildDeployProvisioningOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudBuildDeployProvisioningOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudBuildDeployProvisioningOperator' "${log}"
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY' "${log}"
}

test_run_rejects_invalid_tag_before_gcloud() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${log}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/04_run-production-deploy.sh" 'v1;echo pwned'; then
    return 1
  fi
  [[ ! -s "${log}" ]]
}

test_run_rejects_delimiter_in_substitution_before_gcloud() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
CLOUD_BUILD_SOURCE_BRANCH=main
DEPLOY_SMOKE_TEST_URL=
APP_VPC_ARGS='--network=frozen-runner-vpc;touch'
MIGRATION_VPC_ARGS='--network=frozen-runner-vpc --subnet=frozen-runner-main-app-subnet --vpc-egress=all-traffic'
EOF
  cat >"${temp_dir}/global-env.sh" <<'EOF'
PROJECT_NAME=frozen-runner
GOOGLE_PROJECT_ID=echox-project
GOOGLE_PROJECT_REGION=asia-east1
EXEC_IAM_ACCOUNT=cloud.chen@getoken.io
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${log}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
    MODULE_ENV_FILE="${temp_dir}/module-env.sh" \
    bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/04_run-production-deploy.sh" v1.2.3; then
    return 1
  fi
  [[ ! -s "${log}" ]]
}

test_trigger_drift_fails_without_create() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "builds triggers describe" ]]; then
  case "\$*" in
    *"--format=value(repositoryEventConfig.repository)"*) printf 'drift-repository\n' ;;
    *"--format=value(repositoryEventConfig.push.branch)"*) printf 'main\n' ;;
    *"--format=value(filename)"*) printf 'cicd/prod/cloudbuild-deploy.yaml\n' ;;
    *"--format=value(serviceAccount)"*) printf 'drift-account\n' ;;
    *"--format=value(substitutions._REGION)"*) printf 'asia-east1\n' ;;
    *) printf 'frozen-runner-production-deploy-trigger\n' ;;
  esac
  exit 0
fi
printf 'unexpected gcloud command\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/03_create-production-trigger.sh"; then
    return 1
  fi
  ! grep -F 'builds triggers create' "${log}"
}

test_deploy_order_and_substitution_delimiter() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '<%s> ' "\$@" >>"${log}"
printf '\n' >>"${log}"
exit 0
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/04_run-production-deploy.sh" v1.2.3
  run_lines="$(grep -n '<builds> <triggers> <run>' "${log}")"
  [[ -n "${run_lines}" ]]
  grep -F -- '<--region=asia-east1>' "${log}"
  grep -F -- '<--project=echox-project>' "${log}"
  grep -F -- '<--branch=main>' "${log}"
  grep -F -- '<--substitutions=^;^_IMAGE_TAG=v1.2.3;_REGION=asia-east1' "${log}"
  grep -F -- ';_APP_SECRET_MAPPING=APP_SECRET=frozen-runner-main-app-secret:latest' "${log}"
  grep -F -- ';_MIGRATION_SECRET_MAPPING=DATABASE_URL=frozen-runner-database-url:latest,DATABASE_USER=frozen-runner-database-user:latest>' "${log}"
}

test_service_account_contract() {
  local yaml
  yaml="${ROOT_DIR}/../frozen-runner/cicd/prod/cloudbuild-deploy.yaml"
  grep -F 'serviceAccount: projects/${PROJECT_ID}/serviceAccounts/${_DEPLOYER_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com' "${yaml}"
  grep -F 'migration_service_account="${_MIGRATOR_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"' "${yaml}"
  grep -F 'app_service_account="${_APP_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"' "${yaml}"
  ! grep -E '(_DEPLOYER_SERVICE_ACCOUNT|_APP_SERVICE_ACCOUNT|_MIGRATOR_SERVICE_ACCOUNT).*\.iam\.gserviceaccount\.com.*\.iam\.gserviceaccount\.com' "${yaml}"
  ! grep -E 'serviceAccount:.*frozen-runner|docker\.pkg\.dev/frozen-runner' "${yaml}"
}

test_trigger_substitution_contract() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "${temp_dir}"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "builds triggers describe" ]]; then
  exit 1
fi
exit 0
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/03_create-production-trigger.sh"
  grep -F '_DEPLOYER_SERVICE_ACCOUNT=cb-frozen-runner-deploy' "${log}"
  grep -F '_APP_SERVICE_ACCOUNT=cb-frozen-runner-mini' "${log}"
  grep -F '_MIGRATOR_SERVICE_ACCOUNT=cb-frozen-runner-migration' "${log}"
  ! grep -E 'iam\.gserviceaccount\.com.*iam\.gserviceaccount\.com' "${log}"
}

test_deploy_yaml_migrates_before_app() {
  local yaml migration_line app_line
  yaml="${ROOT_DIR}/../frozen-runner/cicd/prod/cloudbuild-deploy.yaml"
  migration_line="$(grep -n 'gcloud run jobs deploy' "${yaml}" | cut -d: -f1)"
  app_line="$(grep -n 'gcloud run deploy' "${yaml}" | cut -d: -f1)"
  [[ -n "${migration_line}" && -n "${app_line}" && ${migration_line} -lt ${app_line} ]]
  grep -F 'gcloud run jobs execute' "${yaml}"
}

test_verify_does_not_smoke_without_explicit_url() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3 \$4" == "run jobs executions list" ]]; then
  printf 'frozen-runner-db-migration-00001\n'
fi
exit 0
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/deploy/scripts/05_verify-deployment.sh" v1.2.3
  ! grep -F 'curl ' "${log}"
  ! grep -F 'password\|private' "${log}"
}

test_invalid_env_fails_before_gcloud
test_valid_env_loads
test_valid_env_can_be_sourced
test_service_account_ids_reject_non_bare_before_gcloud
test_role_lifecycle_arguments
test_run_rejects_invalid_tag_before_gcloud
test_run_rejects_delimiter_in_substitution_before_gcloud
test_trigger_drift_fails_without_create
test_deploy_order_and_substitution_delimiter
test_service_account_contract
test_trigger_substitution_contract
test_deploy_yaml_migrates_before_app
test_verify_does_not_smoke_without_explicit_url
printf 'cloudbuild deploy scripts tests passed\n'
