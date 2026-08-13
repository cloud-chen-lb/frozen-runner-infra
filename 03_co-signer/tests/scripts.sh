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
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/06_create-vm.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/00_mysql_env.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/02_create-cloud-kms.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/03_create-vm.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/04_create-mysql-instance.sh" ]]
  source "${ROOT_DIR}/global-env/env.sh"
  source "${ROOT_DIR}/03_co-signer/scripts/env/env.sh"
  [[ "${KMS_KEYRING}" == "frozen-runner-kms" ]]
  [[ "${MYSQL_INSTANCE_NAME}" == "frozen-runner-cosigner-mysql" ]]
  [[ "${MYSQL_NETWORK_NAME}" == "frozen-runner-vpc" ]]
  [[ "${VM_VPC_NETWORK}" == "frozen-runner-cosigner-subnet" ]]
  ! grep -Eiq 'PAIRING_TOKEN|MYSQL_PASSWORD|PRIVATE KEY' \
    "${ROOT_DIR}/03_co-signer/co-signer.env" \
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
  [[ "${output}" == *"merchant-cosigner-missing.env"* ]]
  for script in 05_create-mysql-database-user.sh 06_create-vm.sh; do
    if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/${script}" Bad </dev/null 2>&1)"; then
      return 1
    fi
    [[ "${output}" == *"valid merchant slug"* ]]
    if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/${script}" missing </dev/null 2>&1)"; then
      return 1
    fi
    [[ "${output}" == *"merchant-cosigner-missing.env"* ]]
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

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/04_create-merchant-cloud-kms.sh" acme
  grep -F 'kms keys add-iam-policy-binding frozen-runner-acme-cosigner-kms-key' "${log}"
  grep -F -- '--member=serviceAccount:frozen-runner-acme-cosigner-sa@echox-project.iam.gserviceaccount.com' "${log}"
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

test_script_layout_and_safety
test_merchant_argument_and_env_validation
test_merchant_kms_is_scoped_to_merchant
test_role_removal_uses_shared_env
printf 'co-signer scripts tests passed\n'
