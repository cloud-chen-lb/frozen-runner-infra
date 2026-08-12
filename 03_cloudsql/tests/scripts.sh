#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOADER="${ROOT_DIR}/03_cloudsql/scripts/00_env.sh"

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
POSTGRES_DATABASE_NAME=frozen_runner
POSTGRES_APP_USER=frozen_runner_app
POSTGRES_MIGRATION_USER=frozen_runner_migration
POSTGRES_VERSION=POSTGRES_16
POSTGRES_TIER=db-custom-2-7680
POSTGRES_STORAGE_GB=20
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"

  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
    MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${LOADER}"; then
    printf 'Expected invalid Cloud SQL env to fail\n' >&2
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
    [[ -n "${POSTGRES_DATABASE_NAME:-}" ]]
  )
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
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create CloudSQLProvisioningOperator' "${log}")"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update CloudSQLProvisioningOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/99_remove-exec-iam-account-role.sh"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  ! grep -F 'compute.globalAddresses.create' "${log}"
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudSQLProvisioningOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudSQLProvisioningOperator' "${log}"
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY' "${log}"
}

test_postgres_instance_create_contract() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$1 \$2 \$3" in
  "sql instances describe") exit 1 ;;
esac
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/02_create-postgres-instance.sh"
  grep -F 'sql instances create frozen-runner-main-app-postgres' "${log}"
  grep -F -- '--project=echox-project' "${log}"
  grep -F -- '--database-version=POSTGRES_16' "${log}"
  grep -F -- '--tier=db-custom-2-7680' "${log}"
  grep -F -- '--storage-size=20' "${log}"
  grep -F -- '--availability-type=REGIONAL' "${log}"
  grep -F -- '--network=frozen-runner-vpc' "${log}"
  grep -F -- '--no-assign-ip' "${log}"
  grep -F -- '--enable-point-in-time-recovery' "${log}"
  grep -F -- '--deletion-protection' "${log}"
}

test_postgres_instance_drift_fails() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "sql instances describe" ]]; then
  printf 'databaseVersion: POSTGRES_15\n'
  printf 'tier: db-custom-2-7680\n'
  printf 'dataDiskSizeGb: 20\navailabilityType: REGIONAL\n'
  printf 'ipv4Enabled: false\nprivateNetwork: frozen-runner-vpc\n'
  printf 'backupEnabled: true\npointInTimeRecoveryEnabled: true\n'
  printf 'deletionProtectionEnabled: true\n'
  exit 0
fi
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/02_create-postgres-instance.sh"; then
    printf 'Expected PostgreSQL instance drift to fail\n' >&2
    return 1
  fi
  ! grep -F 'sql instances create' "${log}"
}

test_postgres_instance_backup_false_fails() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "sql instances describe" ]]; then
  case "\$*" in
    *'--format=value(databaseVersion)'*) printf 'POSTGRES_16\n'; exit 0 ;;
    *'--format=value(settings.tier)'*) printf 'db-custom-2-7680\n'; exit 0 ;;
    *'--format=value(settings.dataDiskSizeGb)'*) printf '20\n'; exit 0 ;;
    *'--format=value(settings.availabilityType)'*) printf 'REGIONAL\n'; exit 0 ;;
    *'--format=value(settings.ipConfiguration.ipv4Enabled)'*) printf 'False\n'; exit 0 ;;
    *'--format=value(settings.backupConfiguration.enabled)'*) printf 'False\n'; exit 0 ;;
    *'--format=value(settings.backupConfiguration.pointInTimeRecoveryEnabled)'*) printf 'True\n'; exit 0 ;;
    *'--format=value(deletionProtectionEnabled)'*) printf 'True\n'; exit 0 ;;
    *'--format=value(settings.ipConfiguration.privateNetwork)'*) printf 'frozen-runner-vpc\n'; exit 0 ;;
  esac
  printf 'databaseVersion: POSTGRES_16\n'
  printf 'tier: db-custom-2-7680\ndataDiskSizeGb: 20\navailabilityType: REGIONAL\n'
  printf 'ipv4Enabled: false\nprivateNetwork: frozen-runner-vpc\n'
  printf 'backupEnabled: false\nother.enabled: true\n'
  printf 'pointInTimeRecoveryEnabled: true\ndelectionProtectionEnabled: true\n'
  exit 0
fi
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/02_create-postgres-instance.sh"; then
    printf 'Expected disabled PostgreSQL backups to fail\n' >&2
    return 1
  fi
  ! grep -F 'sql instances create' "${log}"
}

test_postgres_instance_ambiguous_backup_output_fails() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "sql instances describe" ]]; then
  case "\$*" in
    *'--format=value(databaseVersion)'*) printf 'POSTGRES_16\n'; exit 0 ;;
    *'--format=value(settings.tier)'*) printf 'db-custom-2-7680\n'; exit 0 ;;
    *'--format=value(settings.dataDiskSizeGb)'*) printf '20\n'; exit 0 ;;
    *'--format=value(settings.availabilityType)'*) printf 'REGIONAL\n'; exit 0 ;;
    *'--format=value(settings.ipConfiguration.ipv4Enabled)'*) printf 'False\n'; exit 0 ;;
    *'--format=value(settings.backupConfiguration.enabled)'*) printf 'True\nFalse\n'; exit 0 ;;
    *'--format=value(settings.backupConfiguration.pointInTimeRecoveryEnabled)'*) printf 'True\n'; exit 0 ;;
    *'--format=value(deletionProtectionEnabled)'*) printf 'True\n'; exit 0 ;;
    *'--format=value(settings.ipConfiguration.privateNetwork)'*) printf 'frozen-runner-vpc\n'; exit 0 ;;
  esac
  printf 'databaseVersion: POSTGRES_16\n'
  printf 'tier: db-custom-2-7680\ndataDiskSizeGb: 20\navailabilityType: REGIONAL\n'
  printf 'ipv4Enabled: false\nprivateNetwork: frozen-runner-vpc\n'
  printf 'backupEnabled: true\nenabled: false\n'
  printf 'pointInTimeRecoveryEnabled: true\ndelectionProtectionEnabled: true\n'
  exit 0
fi
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/02_create-postgres-instance.sh"; then
    printf 'Expected ambiguous PostgreSQL backup output to fail\n' >&2
    return 1
  fi
  ! grep -F 'sql instances create' "${log}"
}

test_postgres_database_and_users_paths() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$1 \$2 \$3" in
  "sql databases describe"|"sql users describe") exit 1 ;;
  "secrets versions access") printf 'secret-value\n' ;;
esac
EOF
  chmod +x "${temp_dir}/gcloud"
  printf 'app-password\nmigration-password\n' | PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_cloudsql/scripts/03_create-postgres-database-users.sh"
  grep -F 'sql databases create frozen_runner' "${log}"
  grep -F 'sql users create frozen_runner_app' "${log}"
  grep -F 'sql users create frozen_runner_migration' "${log}"
  ! grep -F 'app-password' "${log}"
  ! grep -F 'migration-password' "${log}"
  ! grep -F 'secret-value' "${log}"
  ! grep -E -- '--password(=| )' "${log}"
  ! grep -Eiq 'cosigner|mysql|vm|kms|password=|substitution' "${log}"
  [[ "$(grep -n 'sql databases describe' "${log}" | cut -d: -f1)" -lt \
    "$(grep -n 'sql databases create' "${log}" | cut -d: -f1)" ]]
  [[ "$(grep -n 'sql users describe frozen_runner_app' "${log}" | cut -d: -f1)" -lt \
    "$(grep -n 'sql users create frozen_runner_app' "${log}" | cut -d: -f1)" ]]
}

test_postgres_database_and_users_existing_are_reused() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
exit 0
EOF
  chmod +x "${temp_dir}/gcloud"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_cloudsql/scripts/03_create-postgres-database-users.sh" </dev/null
  ! grep -F 'sql databases create' "${log}"
  ! grep -F 'sql users create' "${log}"
}

test_postgres_invalid_config_fails_before_gcloud() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/module-env.sh" <<'EOF'
POSTGRES_DATABASE_NAME=frozen_runner
POSTGRES_APP_USER=frozen_runner_app
POSTGRES_MIGRATION_USER=frozen_runner_migration
POSTGRES_VERSION=POSTGRES_16
POSTGRES_TIER=db-custom-2-7680
POSTGRES_STORAGE_GB=bad
POSTGRES_NETWORK_NAME=frozen-runner-vpc
POSTGRES_INSTANCE_NAME=frozen-runner-main-app-postgres
EOF
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf 'gcloud must not be called\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" MODULE_ENV_FILE="${temp_dir}/module-env.sh" \
    bash "${ROOT_DIR}/03_cloudsql/scripts/02_create-postgres-instance.sh"; then
    printf 'Expected invalid PostgreSQL sizing to fail\n' >&2
    return 1
  fi
}

test_invalid_env_fails_before_gcloud
test_valid_env_loads
test_valid_env_can_be_sourced
test_role_lifecycle_arguments
test_postgres_instance_create_contract
test_postgres_instance_drift_fails
test_postgres_instance_backup_false_fails
test_postgres_instance_ambiguous_backup_output_fails
test_postgres_database_and_users_paths
test_postgres_database_and_users_existing_are_reused
test_postgres_invalid_config_fails_before_gcloud
printf 'cloudsql scripts tests passed\n'
