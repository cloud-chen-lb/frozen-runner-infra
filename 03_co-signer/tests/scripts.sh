#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

test_script_layout_and_safety() {
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/00_env.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh" ]]
  [[ -x "${ROOT_DIR}/03_co-signer/scripts/02_create-cosigner-subnet.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/03_create-mysql-instance.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/04_create-cloud-kms-keyring.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/06_create-mysql-database-user.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/07_print-merchant-co-signer-env.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/08_create-vm.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/09_add-vm-ssh-key.sh" ]]
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/00_mysql_env.sh" ]]
  [[ ! -e "${ROOT_DIR}/03_co-signer/scripts/02_create-cloud-kms.sh" ]]
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
  [[ "${VM_SSH_SOURCE_CIDR}" == "203.0.113.0/24" ]]
  [[ "${VM_SSH_SOURCE_CIDR}" != "0.0.0.0/0" ]]
  ! grep -Eiq 'PAIRING_TOKEN|MYSQL_PASSWORD|PRIVATE KEY' \
    "${ROOT_DIR}/03_co-signer/scripts/env"/* 2>/dev/null
}

test_merchant_argument_and_env_validation() {
  local output
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh" </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"Usage:"* ]]
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh" Bad </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"valid merchant slug"* ]]
  if output="$(bash "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh" missing </dev/null 2>&1)"; then
    return 1
  fi
  [[ "${output}" == *"env-merchant-missing.sh"* ]]
  for script in 06_create-mysql-database-user.sh 07_print-merchant-co-signer-env.sh 08_create-vm.sh \
    09_add-vm-ssh-key.sh 10_remove-vm-ssh-key.sh; do
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

test_vm_ssh_key_is_instance_scoped_and_non_destructive() {
  local temp_dir log ssh_username
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  ssh_username="$(id -un)"
  trap 'rm -rf "$temp_dir"' RETURN
  mkdir -p "${temp_dir}/home/.ssh"
  printf 'ssh-rsa AAAAoperator operator@host\n' >"${temp_dir}/home/.ssh/id_rsa.pub"
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
for argument in "$@"; do
  if [[ "${argument}" == --metadata-from-file=ssh-keys=* ]]; then
    printf 'metadata=%s\n' "$(<"${argument##*=}")" >>"${GCLOUD_LOG}"
  fi
done
if [[ "$*" == *"instances describe"* ]]; then
  printf '%s\n' "${GCLOUD_METADATA}"
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" \
    GCLOUD_METADATA=$'ssh-rsa AAAAother other@host\nssh-rsa AAAAoperator operator@host' PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/09_add-vm-ssh-key.sh" echox
  grep -F -- 'compute instances describe frozen-runner-echox-cosigner --project=echox-project --zone=asia-east1-a' "${log}"
  grep -F -- 'compute instances add-metadata frozen-runner-echox-cosigner --project=echox-project --zone=asia-east1-a --metadata-from-file=ssh-keys=' "${log}"
  grep -F -- 'metadata=ssh-rsa AAAAother other@host' "${log}"
  grep -F -- "${ssh_username}:ssh-rsa AAAAoperator operator@host" "${log}"
  ! grep -Fx -- 'metadata=ssh-rsa AAAAoperator operator@host' "${log}"
  ! grep -F -- 'projects add-metadata' "${log}"

  : >"${log}"
  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" \
    GCLOUD_METADATA=$'ssh-rsa AAAAother other@host\nssh-rsa AAAAoperator operator@host\n'"${ssh_username}"':ssh-rsa AAAAoperator operator@host' \
    PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" echox
  grep -F -- 'compute instances add-metadata frozen-runner-echox-cosigner --project=echox-project --zone=asia-east1-a --metadata-from-file=ssh-keys=' "${log}"
  grep -F -- 'metadata=ssh-rsa AAAAother other@host' "${log}"
  ! grep -F -- "metadata=${ssh_username}:ssh-rsa AAAAoperator operator@host" "${log}"
  ! grep -Fx -- 'metadata=ssh-rsa AAAAoperator operator@host' "${log}"
  ! grep -F -- 'compute instances remove-metadata' "${log}"
  ! grep -F -- 'frozen-runner-other' "${log}"
}

test_vm_ssh_key_removal_clears_only_key() {
  local temp_dir log ssh_username
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  ssh_username="$(id -un)"
  trap 'rm -rf "$temp_dir"' RETURN
  mkdir -p "${temp_dir}/home/.ssh"
  printf 'ssh-rsa AAAAoperator operator@host\n' >"${temp_dir}/home/.ssh/id_rsa.pub"
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$*" == *"instances describe"* ]]; then
  printf '%s\n' "${GCLOUD_METADATA}"
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" \
    GCLOUD_METADATA="${ssh_username}:ssh-rsa AAAAoperator operator@host" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" echox
  grep -F -- 'compute instances remove-metadata frozen-runner-echox-cosigner --project=echox-project --zone=asia-east1-a --keys=ssh-keys' "${log}"
  ! grep -F -- 'compute instances add-metadata' "${log}"
}

test_vm_ssh_firewall_is_scoped_and_idempotent() {
  local temp_dir log ssh_source_cidr ssh_username
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  source "${ROOT_DIR}/03_co-signer/scripts/env/env-merchant-echox.sh"
  ssh_source_cidr="${VM_SSH_SOURCE_CIDR}"
  ssh_username="$(id -un)"
  trap 'rm -rf "$temp_dir"' RETURN
  mkdir -p "${temp_dir}/home/.ssh"
  printf 'ssh-rsa AAAAoperator operator@host\n' >"${temp_dir}/home/.ssh/id_rsa.pub"
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$*" == *"instances describe"* ]]; then
  printf '%s\n' "${GCLOUD_METADATA}"
elif [[ "$*" == *"firewall-rules describe"* ]]; then
  [[ "${GCLOUD_FIREWALL_STATE}" == "present" ]]
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" \
    GCLOUD_METADATA="${ssh_username}:ssh-rsa AAAAoperator operator@host" \
    GCLOUD_FIREWALL_STATE=absent PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/09_add-vm-ssh-key.sh" echox
  grep -F -- "compute firewall-rules create frozen-runner-echox-ssh-ingress --project=echox-project --network=frozen-runner-vpc --direction=INGRESS --action=ALLOW --rules=tcp:22 --source-ranges=${ssh_source_cidr} --target-service-accounts=echox-cosigner-sa@echox-project.iam.gserviceaccount.com --description=Temporarily allows SSH TCP/22 to the merchant Co-Signer VM from the configured operator CIDR and is removed by 10_remove-vm-ssh-key.sh." "${log}"
  ! grep -F -- 'compute instances add-metadata' "${log}"

  : >"${log}"
  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" GCLOUD_METADATA='' \
    GCLOUD_FIREWALL_STATE=present PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/09_add-vm-ssh-key.sh" echox
  ! grep -F -- 'compute firewall-rules create' "${log}"
  grep -F -- 'compute instances add-metadata' "${log}"
}

test_vm_ssh_firewall_is_removed_idempotently() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  mkdir -p "${temp_dir}/home/.ssh"
  printf 'ssh-rsa AAAAoperator operator@host\n' >"${temp_dir}/home/.ssh/id_rsa.pub"
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$*" == *"instances describe"* ]]; then
  printf '%s\n' "${GCLOUD_METADATA}"
elif [[ "$*" == *"firewall-rules describe"* && "${GCLOUD_FIREWALL_STATE}" != "present" ]]; then
  exit 1
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" GCLOUD_METADATA='' \
    GCLOUD_FIREWALL_STATE=present PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" echox
  grep -F -- 'compute firewall-rules delete frozen-runner-echox-ssh-ingress --project=echox-project' "${log}"

  : >"${log}"
  HOME="${temp_dir}/home" GCLOUD_LOG="${log}" GCLOUD_METADATA='' \
    GCLOUD_FIREWALL_STATE=absent PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" echox
  ! grep -F -- 'compute firewall-rules delete' "${log}"
}

test_vm_ssh_firewall_rejects_ipv6_wildcard() {
  local temp_dir output script
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  mkdir -p "${temp_dir}/scripts/env"
  cp "${ROOT_DIR}/03_co-signer/scripts/00_env.sh" "${temp_dir}/scripts/00_env.sh"
  cp "${ROOT_DIR}/03_co-signer/scripts/env/env.sh" "${temp_dir}/scripts/env/env.sh"
  cp "${ROOT_DIR}/03_co-signer/scripts/env/env-merchant-echox.sh" \
    "${temp_dir}/scripts/env/env-merchant-echox.sh"
  cp "${ROOT_DIR}/03_co-signer/scripts/09_add-vm-ssh-key.sh" "${temp_dir}/scripts/09_add-vm-ssh-key.sh"
  cp "${ROOT_DIR}/03_co-signer/scripts/10_remove-vm-ssh-key.sh" "${temp_dir}/scripts/10_remove-vm-ssh-key.sh"
  perl -0pi -e 's/VM_SSH_SOURCE_CIDR="[^"]+"/VM_SSH_SOURCE_CIDR="::\/0"/' \
    "${temp_dir}/scripts/env/env-merchant-echox.sh"

  for script in 09_add-vm-ssh-key.sh 10_remove-vm-ssh-key.sh; do
    if output="$(GLOBAL_ENV_FILE="${ROOT_DIR}/global-env/env.sh" \
      MODULE_ENV_FILE="${temp_dir}/scripts/env/env.sh" \
      bash "${temp_dir}/scripts/${script}" echox 2>&1)"; then
      return 1
    fi
    [[ "${output}" == *"must not allow SSH from everywhere"* ]]
  done
}

test_cosigner_subnet_is_created_verified_and_rejects_drift() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3 \$4" == "compute networks subnets describe" ]]; then
  case "\${SUBNET_STATE:-absent}" in
    absent) exit 1 ;;
    matching)
      printf 'ipCidrRange: 10.40.0.0/24\nnetwork: projects/echox-project/global/networks/frozen-runner-vpc\nregion: projects/echox-project/regions/asia-east1\n'
      ;;
    drift)
      printf 'ipCidrRange: \${DRIFT_CIDR}\nnetwork: projects/echox-project/global/networks/\${DRIFT_NETWORK}\nregion: projects/echox-project/regions/\${DRIFT_REGION}\n'
      ;;
  esac
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/02_create-cosigner-subnet.sh"
  grep -F 'compute networks subnets create frozen-runner-cosigner-subnet' "${log}"

  : >"${log}"
  SUBNET_STATE=matching PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/02_create-cosigner-subnet.sh"
  ! grep -F 'compute networks subnets create' "${log}"

  for drift in cidr network region; do
    : >"${log}"
    case "${drift}" in
      cidr) DRIFT_CIDR=10.41.0.0/24 DRIFT_NETWORK=frozen-runner-vpc DRIFT_REGION=asia-east1 ;;
      network) DRIFT_CIDR=10.40.0.0/24 DRIFT_NETWORK=wrong-vpc DRIFT_REGION=asia-east1 ;;
      region) DRIFT_CIDR=10.40.0.0/24 DRIFT_NETWORK=frozen-runner-vpc DRIFT_REGION=us-central1 ;;
    esac
    if SUBNET_STATE=drift DRIFT_CIDR="${DRIFT_CIDR}" DRIFT_NETWORK="${DRIFT_NETWORK}" \
      DRIFT_REGION="${DRIFT_REGION}" PATH="${temp_dir}:${PATH}" \
      bash "${ROOT_DIR}/03_co-signer/scripts/02_create-cosigner-subnet.sh"; then
      printf 'Expected Co-Signer subnet %s drift to fail\n' "${drift}" >&2
      return 1
    fi
    ! grep -F 'compute networks subnets create' "${log}"
    unset DRIFT_CIDR DRIFT_NETWORK DRIFT_REGION
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

  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh" echox
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
  grep -F -- 'compute.firewalls.create' "${log}"
  grep -F -- 'compute.firewalls.delete' "${log}"
  grep -F -- 'compute.firewalls.get' "${log}"
  [[ "$(grep -o 'compute\.firewalls\.[a-z]*' "${log}" | sort -u | wc -l | tr -d ' ')" == 3 ]]
  for permission in compute.subnetworks.create compute.subnetworks.get compute.subnetworks.list \
    compute.subnetworks.use compute.subnetworks.useExternalIp; do
    grep -F -- "${permission}" "${log}"
  done
}

test_mysql_backup_flags_match_mysql_api() {
  ! grep -F -- '--enable-point-in-time-recovery' \
    "${ROOT_DIR}/03_co-signer/scripts/03_create-mysql-instance.sh"
  grep -F -- '--enable-bin-log' \
    "${ROOT_DIR}/03_co-signer/scripts/03_create-mysql-instance.sh"
}

test_merchant_kms_is_rerunnable_after_account_creation() {
  grep -F -- 'iam service-accounts describe' \
    "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh"
  grep -F -- 'kms keys describe' \
    "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh"
  grep -F -- 'Timed out waiting for service account propagation' \
    "${ROOT_DIR}/03_co-signer/scripts/05_create-merchant-cloud-kms.sh"
}

test_vm_is_rerunnable_after_ip_creation() {
  grep -F -- 'compute addresses describe' \
    "${ROOT_DIR}/03_co-signer/scripts/08_create-vm.sh"
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

  output="$(PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/07_print-merchant-co-signer-env.sh" echox)"
  [[ "${output}" == $'PAIRING_TOKEN="{PAIRING-TOKEN}"\nCONFIG_MODE="LOCAL_FILE"\nMYSQL_URL="jdbc:mysql://10.0.0.5:3306/cosigner_echox?useUnicode=true&characterEncoding=utf-8&serverTimezone=UTC&useSSL=true&allowPublicKeyRetrieval=true"\nMYSQL_USER="cosigner_echox_user"\nMYSQL_PASSWORD="{MYSQL-PASSWORD}"\nKMS_TYPE="GCPKMS"\nGOOGLE_PROJECT="echox-project"\nGOOGLE_REGION="asia-east1"\nGOOGLE_KEYRING="frozen-runner-kms"\nGOOGLE_CRYPTO_KEY="frozen-runner-echox-cosigner-kms-key"\nCALLBACK_VERSION="v3"' ]]
}

test_script_layout_and_safety
test_merchant_argument_and_env_validation
test_vm_ssh_key_is_instance_scoped_and_non_destructive
test_vm_ssh_key_removal_clears_only_key
test_vm_ssh_firewall_is_scoped_and_idempotent
test_vm_ssh_firewall_is_removed_idempotently
test_vm_ssh_firewall_rejects_ipv6_wildcard
test_cosigner_subnet_is_created_verified_and_rejects_drift
test_merchant_kms_is_scoped_to_merchant
test_role_removal_uses_shared_env
test_iam_permissions_have_no_leading_whitespace
test_mysql_backup_flags_match_mysql_api
test_merchant_kms_is_rerunnable_after_account_creation
test_vm_is_rerunnable_after_ip_creation
test_merchant_database_info_outputs_expected_values
printf 'co-signer scripts tests passed\n'
