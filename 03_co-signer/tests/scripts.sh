#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

test_script_layout_and_safety() {
  [[ -f "${ROOT_DIR}/03_co-signer/scripts/00_env.sh" ]]
  [[ -x "${ROOT_DIR}/03_co-signer/scripts/00_enable-apis.sh" ]]
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

test_cosigner_apis_are_enabled_idempotently() {
  local temp_dir log output
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$1 $2" == "services list" ]]; then
  for argument in "$@"; do
    if [[ "${argument}" == --filter=config.name=* ]]; then
      api="${argument#*config.name=}"
      if [[ "${API_STATE:-missing}" == all ]]; then
        printf '%s\n' "${api}"
      fi
      exit 0
    fi
  done
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  output="$(API_STATE=missing GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/00_enable-apis.sh" 2>&1)"
  for api in cloudkms.googleapis.com compute.googleapis.com iam.googleapis.com sqladmin.googleapis.com; do
    [[ "$(grep -Fxc "services enable ${api} --project=frozen-runner-production" "${log}")" == 1 ]]
    [[ "${output}" == *"Enabled API: ${api}"* ]]
  done

  : >"${log}"
  output="$(API_STATE=all GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/00_enable-apis.sh" 2>&1)"
  for api in cloudkms.googleapis.com compute.googleapis.com iam.googleapis.com sqladmin.googleapis.com; do
    [[ "${output}" == *"API already enabled: ${api}"* ]]
  done
  ! grep -F 'services enable' "${log}"
}

test_keyring_creation_reports_status_and_preserves_errors() {
  local temp_dir log output
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$1 $2 $3" == "kms keyrings describe" ]]; then
  case "${KEYRING_STATE:-absent}" in
    present) printf 'keyring exists\n'; exit 0 ;;
    absent)
      printf 'ERROR: (gcloud.kms.keyrings.describe) NOT_FOUND: KeyRing projects/frozen-runner-production/locations/asia-northeast1/keyRings/%s not found.\n' \
        "${EXPECTED_KEYRING}" >&2
      exit 1
      ;;
    error) printf 'ERROR: permission denied\n' >&2; exit 1 ;;
  esac
fi
if [[ "$1 $2 $3" == "kms keyrings create" ]]; then
  printf 'keyring created\n'
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  output="$(KEYRING_STATE=present GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/04_create-cloud-kms-keyring.sh" 2>&1)"
  [[ "${output}" == *"Checking KMS keyring"* ]]
  [[ "${output}" == *"already exists"* ]]
  ! grep -F 'kms keyrings create' "${log}"

  : >"${log}"
  output="$(KEYRING_STATE=absent EXPECTED_KEYRING=frozen-runner-kms GCLOUD_LOG="${log}" \
    PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/03_co-signer/scripts/04_create-cloud-kms-keyring.sh" 2>&1)"
  if [[ "${output}" != *"Checking KMS keyring"* ||
    "${output}" != *"ERROR: (gcloud.kms.keyrings.describe) NOT_FOUND"* ||
    "${output}" != *"Creating KMS keyring"* ]]; then
    printf 'Expected missing-keyring describe error to be visible before creation; output was:\n%s\n' \
      "${output}" >&2
    return 1
  fi
  grep -F 'kms keyrings create frozen-runner-kms' "${log}"

  : >"${log}"
  if output="$(KEYRING_STATE=error GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/04_create-cloud-kms-keyring.sh" 2>&1)"; then
    printf 'Expected keyring describe permission error to fail\n' >&2
    return 1
  fi
  [[ "${output}" == *"permission denied"* ]]
  ! grep -F 'kms keyrings create' "${log}"
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
  printf 'ERROR: (gcloud.iam.roles.describe) NOT_FOUND: The role named projects/echox-project/roles/SafeheronCoSignerBuilderRole was not found.\n' >&2
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
  grep -F -- 'compute.networks.updatePolicy' "${log}"
  [[ "$(grep -o 'compute\.firewalls\.[a-z]*' "${log}" | sort -u | wc -l | tr -d ' ')" == 3 ]]
  for permission in compute.subnetworks.create compute.subnetworks.get compute.subnetworks.list \
    compute.subnetworks.use compute.subnetworks.useExternalIp; do
    grep -F -- "${permission}" "${log}"
  done
}

test_exec_role_adds_only_missing_permissions() {
  local temp_dir log created_permissions missing_permissions extra_permission
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GCLOUD_LOG}"
if [[ "$1 $2 $3" == "iam roles describe" ]]; then
  case "${ROLE_STATE:-absent}" in
    absent) printf 'ERROR: (gcloud.iam.roles.describe) NOT_FOUND: The role named projects/echox-project/roles/SafeheronCoSignerBuilderRole was not found.\n' >&2; exit 1 ;;
    error) printf 'permission denied\n' >&2; exit 7 ;;
    credential-error) printf 'credential file not found\n' >&2; exit 1 ;;
    present)
      if [[ "$*" == *"value(deleted)"* ]]; then
        printf 'False\n'
      elif [[ "$*" == *'value[delimiter=";"](includedPermissions)'* ]]; then
        if [[ "${SECOND_DESCRIBE_FAILS:-false}" == true ]]; then
          printf 'permission denied\n' >&2; exit 7
        fi
        printf '%s\n' "${EXISTING_PERMISSIONS:-$(<"${ROLE_DATA}")}"
      else
        printf 'unexpected permissions format: %s\n' "$*" >&2; exit 9
      fi
      ;;
  esac
fi
if [[ "$1 $2 $3" == "iam roles update" ]]; then
  current_permissions="${EXISTING_PERMISSIONS:-$(<"${ROLE_DATA}")}"
  for argument in "$@"; do
    if [[ "${argument}" == --add-permissions=* ]]; then
      added_permissions="${argument#*=}"
      printf '%s;%s\n' "${current_permissions}" "${added_permissions//,/;}" >"${ROLE_DATA}"
      break
    fi
  done
fi
EOF
  chmod +x "${temp_dir}/gcloud"

  ROLE_DATA="${temp_dir}/role" GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"
  if ! grep -F 'iam roles create SafeheronCoSignerBuilderRole' "${log}" >/dev/null; then
    printf 'Expected absent role to be created\n' >&2; return 1
  fi
  created_permissions="$(sed -n 's/.*--permissions=//p' "${log}")"
  if [[ -z "${created_permissions}" ]]; then
    printf 'Expected role creation to include permissions\n' >&2; return 1
  fi

  missing_permissions="cloudkms.keyRings.get,compute.instances.list,compute.networks.updatePolicy"
  extra_permission='custom.extraPermission'
  local present_permissions
  present_permissions="${created_permissions//cloudkms.keyRings.get,/}"
  present_permissions="${present_permissions//compute.instances.list/}"
  present_permissions="${present_permissions//compute.networks.updatePolicy/}"
  present_permissions="${present_permissions//,/;}"
  present_permissions="${present_permissions%;}"
  : >"${log}"
  ROLE_STATE=present EXISTING_PERMISSIONS="${present_permissions};${extra_permission}" \
    ROLE_DATA="${temp_dir}/role" GCLOUD_LOG="${log}" \
    PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"
  if [[ "$(grep -Fxc "iam roles update SafeheronCoSignerBuilderRole --project=echox-project --add-permissions=${missing_permissions}" "${log}")" != 1 ]]; then
    printf 'Expected update containing only missing permissions\n' >&2; return 1
  fi

  : >"${log}"
  ROLE_STATE=present EXISTING_PERMISSIONS="${created_permissions//,/;};${extra_permission}" \
    ROLE_DATA="${temp_dir}/role" GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"
  if grep -E 'iam roles (update|create|undelete)' "${log}" >/dev/null; then
    printf 'Complete role must not be mutated\n' >&2; return 1
  fi

  : >"${log}"
  ROLE_STATE=present ROLE_DATA="${temp_dir}/role" GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"
  if grep -E 'iam roles (update|create|undelete)' "${log}" >/dev/null; then
    printf 'Second run after update must not mutate the role\n' >&2; return 1
  fi

  : >"${log}"
  if ROLE_STATE=credential-error ROLE_DATA="${temp_dir}/role" GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"; then
    printf 'Expected credential error to fail\n' >&2; return 1
  fi
  if grep -E 'iam roles (update|create|undelete)|projects add-iam-policy-binding' "${log}"; then return 1; fi

  : >"${log}"
  if ROLE_STATE=error GCLOUD_LOG="${log}" PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/03_co-signer/scripts/01_setup-exec-iam-account-role.sh"; then
    printf 'Expected IAM role describe error to fail\n' >&2
    return 1
  fi
  if grep -E 'iam roles (create|update|undelete)|projects add-iam-policy-binding' "${log}"; then return 1; fi
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
test_cosigner_apis_are_enabled_idempotently
test_keyring_creation_reports_status_and_preserves_errors
test_role_removal_uses_shared_env
test_iam_permissions_have_no_leading_whitespace
test_exec_role_adds_only_missing_permissions
test_mysql_backup_flags_match_mysql_api
test_merchant_kms_is_rerunnable_after_account_creation
test_vm_is_rerunnable_after_ip_creation
test_merchant_database_info_outputs_expected_values
printf 'co-signer scripts tests passed\n'
