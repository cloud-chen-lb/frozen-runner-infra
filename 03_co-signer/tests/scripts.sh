#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

test_script_layout_and_safety() {
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/00_env.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/02_create-mysql-instance.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/03_create-cloud-kms-keyring.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/05_create-mysql-database-user.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/06_print-merchant-co-signer-env.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/07_create-vm.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/00_mysql_env.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/02_create-cloud-kms.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/06_create-vm.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/03_create-vm.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/04_create-mysql-instance.sh" ]]
  source "${ROOT_DIR}/global-env/env.sh"
  source "${ROOT_DIR}/03_co-signer/scripts/env/env.sh"
  [[ "${KMS_KEYRING}" == "frozen-runner-kms" ]]
  [[ "${MYSQL_INSTANCE_NAME}" == "frozen-runner-cosigner-mysql" ]]
  [[ "${MYSQL_NETWORK_NAME}" == "frozen-runner-vpc" ]]
  unset VM_ZONE VM_MACHINE_TYPE VM_VPC_NETWORK
  source "${ROOT_DIR}/03_co-signer/scripts/env/env-merchant-echox.sh"
  [[ "${VM_ZONE}" == "asia-east1-a" ]]
  [[ "${VM_MACHINE_TYPE}" == "e2-medium" ]]
  [[ "${VM_VPC_NETWORK}" == "${PROJECT_NAME}-cosigner-subnet" ]]
  ! grep -Eiq 'PAIRING_TOKEN|MYSQL_PASSWORD|PRIVATE KEY' \
    "${ROOT_DIR}/03_co-signer/scripts/env"/* 2>/dev/null
}

test_merchant_argument_and_env_validation() {
  local output
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"Usage:"* ]]
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" Bad </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"valid merchant slug"* ]]
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" missing </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"env-merchant-missing.sh"* ]]
  for script in 05_create-mysql-database-user.sh 06_print-merchant-co-signer-env.sh 07_create-vm.sh; do
    if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/${script}" Bad </dev/null 2>&1)"; then
      return 1
    fi
    [[ "${output}" == *"valid merchant slug"* ]]
    if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/${script}" missing </dev/null 2>&1)"; then
      return 1
    fi
    [[ "${output}" == *"env-merchant-missing.sh"* ]]
  done
}

test_merchant_kms_is_scoped_to_merchant() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
EOF
  chmod +x "${temp_dir}/gcloud"

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" echox
  grep -F 'kms keys add-iam-policy-binding frozen-runner-echox-cosigner-kms-key' "${log}"
  grep -F -- '--member=serviceAccount:echox-cosigner-sa@echox-project.iam.gserviceaccount.com' "${log}"
  ! grep -F 'frozen-runner-other' "${log}"
}

test_role_removal_uses_shared_env() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
EOF
  chmod +x "${temp_dir}/gcloud"

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/99_remove-exec-iam-account-role.sh"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/SafeheronCoSignerBuilderRole' "${log}"
  ! grep -Eiq 'password|private[_-]?key|\.json|BEGIN .*PRIVATE KEY|create|update' "${log}"
}

test_iam_permissions_have_no_leading_whitespace() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "iam roles describe" ]]; then
  exit 1
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"
  ! grep -E -- '--permissions=.*(^|,) ' "${log}"
  grep -F -- 'cloudsql.users.create' "${log}"
  grep -F -- 'cloudsql.instances.create' "${log}"
  grep -F -- 'cloudsql.instances.get' "${log}"
  grep -F -- 'cloudsql.instances.list' "${log}"
  grep -F -- 'cloudsql.databases.create' "${log}"
  grep -F -- 'cloudsql.databases.get' "${log}"
}

test_mysql_backup_flags_match_mysql_api() {
  ! grep -F -- '--enable-point-in-time-recovery' \
    "${ROOT_DIR}/03_co-signer/scripts/02_create-mysql-instance.sh"
  grep -F -- '--enable-bin-log' \
    "${ROOT_DIR}/03_co-signer/scripts/02_create-mysql-instance.sh"
}

test_merchant_kms_is_rerunnable_after_account_creation() {
  grep -F -- 'iam service-accounts describe' \
    "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh"
  grep -F -- 'kms keys describe' \
    "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh"
  grep -F -- 'Timed out waiting for service account propagation' \
    "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh"
}

test_vm_is_rerunnable_after_ip_creation() {
  grep -F -- 'compute addresses describe' \
    "${ROOT_DIR}/03_co-signer/scripts/07_create-vm.sh"
}

test_merchant_database_info_outputs_expected_values() {
  local temp_dir output
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"sql instances describe"* ]]; then
  [[ "$*" == *"--format=value(ipAddresses[0].ipAddress)"* ]] || exit 1
  printf '10.0.0.5\n'
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  output="$(PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/06_print-merchant-co-signer-env.sh" echox)"
  [[ "${output}" == $'PAIRING_TOKEN="{PAIRING-TOKEN}"\nCONFIG_MODE="LOCAL_FILE"\nMYSQL_URL="jdbc:mysql://10.0.0.5:3306/cosigner_echox?useUnicode=true&characterEncoding=utf-8&serverTimezone=UTC&useSSL=true&allowPublicKeyRetrieval=true"\nMYSQL_USER="cosigner_echox_user"\nMYSQL_PASSWORD="{MYSQL-PASSWORD}"\nKMS_TYPE="GCPKMS"\nGOOGLE_PROJECT="echox-project"\nGOOGLE_REGION="asia-east1"\nGOOGLE_KEYRING="frozen-runner-kms"\nGOOGLE_CRYPTO_KEY="frozen-runner-echox-cosigner-kms-key"\nCALLBACK_VERSION="v3"' ]]
}

test_script_layout_and_safety
test_merchant_argument_and_env_validation
test_merchant_kms_is_scoped_to_merchant
test_role_removal_uses_shared_env
test_iam_permissions_have_no_leading_whitespace
test_mysql_backup_flags_match_mysql_api
test_merchant_kms_is_rerunnable_after_account_creation
test_vm_is_rerunnable_after_ip_creation
test_merchant_database_info_outputs_expected_values
printf 'co-signer scripts tests passed\n'
