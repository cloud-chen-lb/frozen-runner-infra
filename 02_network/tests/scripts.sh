#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOADER="${ROOT_DIR}/02_network/scripts/00_env.sh"

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
MAIN_APP_SUBNET_CIDR=10.20.0.0/24
PRIVATE_SERVICES_RANGE_CIDR=10.30.0.0/16
EOF
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf 'gcloud called\n' >>"${gcloud_calls}"
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"

  if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
    MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${LOADER}"; then
    printf 'Expected invalid network env to fail\n' >&2
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
    [[ -n "${MAIN_APP_SUBNET_CIDR:-}" ]]
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
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create NetworkProvisioningOperator' "${log}")"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update NetworkProvisioningOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/99_remove-exec-iam-account-role.sh"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/NetworkProvisioningOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/NetworkProvisioningOperator' "${log}"
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY' "${log}"
}

test_network_scripts_reject_invalid_input_before_gcloud() {
  local temp_dir script
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/global-env.sh" <<'EOF'
PROJECT_NAME=frozen-runner
GOOGLE_PROJECT_ID=echox-project
GOOGLE_PROJECT_REGION=not_a_region
EXEC_IAM_ACCOUNT=cloud.chen@getoken.io
EOF
  cat >"${temp_dir}/module-env.sh" <<'EOF'
MAIN_APP_SUBNET_CIDR=not-a-cidr
PRIVATE_SERVICES_RANGE_CIDR=10.30.0.0/16
EOF
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf 'gcloud must not be called\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  for script in 02_enable-apis.sh 03_create-vpc.sh 04_create-main-app-subnet.sh \
    05_create-private-services-access.sh 06_create-router-nat.sh; do
    if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
      MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${ROOT_DIR}/02_network/scripts/${script}"; then
      printf 'Expected %s to reject invalid input\n' "${script}" >&2
      return 1
    fi
  done
}

test_network_scripts_create_absent_resources() {
  local temp_dir log script
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$1 \$2 \$3" in
  "services list"*|"services vpc-peerings list"*) exit 0 ;;
esac
case "\$1 \$2 \$3 \$4" in
  "compute networks describe"*|"compute networks subnets describe"*|"compute addresses describe"*|"compute routers describe"*|"compute routers nats describe"*) exit 1 ;;
esac
exit 0
EOF
  chmod +x "${temp_dir}/gcloud"
  for script in 02_enable-apis.sh 03_create-vpc.sh 04_create-main-app-subnet.sh \
    05_create-private-services-access.sh 06_create-router-nat.sh; do
    PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/${script}"
  done
  grep -F 'compute networks create frozen-runner-vpc' "${log}"
  grep -F 'compute networks subnets create frozen-runner-main-app-subnet' "${log}"
  grep -F 'compute addresses create frozen-runner-private-services-range' "${log}"
  grep -F 'services vpc-peerings connect' "${log}"
  grep -F 'compute routers create frozen-runner-router' "${log}"
  grep -F 'compute addresses create frozen-runner-main-app-egress-ip' "${log}"
  grep -F 'compute routers nats create frozen-runner-main-app-nat' "${log}"
  ! grep -Eiq 'cosigner|mysql|vm|load-balancer|password|private[_-]?key|\.json|BEGIN .*PRIVATE KEY' "${log}"
}

test_network_scripts_fail_on_drift() {
  local temp_dir log
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "$temp_dir"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
if [[ "\$1 \$2 \$3" == "compute networks describe" ]]; then
  printf 'subnetMode: LEGACY\n'
  exit 0
fi
exit 1
EOF
  chmod +x "${temp_dir}/gcloud"
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/03_create-vpc.sh"; then
    printf 'Expected VPC drift to fail\n' >&2
    return 1
  fi
  ! grep -F 'compute networks create' "${log}"
}

test_network_resource_contract_drift_fails() {
  local temp_dir drift_case
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' RETURN
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
case "$1 $2 $3" in
  "compute networks subnets describe")
    printf 'ipCidrRange: %s\nnetwork: projects/echox-project/global/networks/%s\nregion: projects/echox-project/regions/%s\n' \
      "${SUBNET_CIDR:-10.20.0.0/24}" "${SUBNET_NETWORK:-frozen-runner-vpc}" "${SUBNET_REGION:-asia-east1}"
    ;;
  "compute addresses describe")
    printf 'address: %s\nprefixLength: %s\npurpose: %s\nnetwork: projects/echox-project/global/networks/%s\n' \
      "${PSA_IP:-10.30.0.0}" "${PSA_PREFIX:-16}" "${PSA_PURPOSE:-VPC_PEERING}" "${PSA_NETWORK:-frozen-runner-vpc}"
    ;;
  "services vpc-peerings list")
    printf 'servicenetworking.googleapis.com %s\n' "${PSA_PEERING_RANGE:-frozen-runner-private-services-range}"
    ;;
  "compute routers describe")
    printf 'network: projects/echox-project/global/networks/%s\nregion: projects/echox-project/regions/%s\n' \
      "${ROUTER_NETWORK:-frozen-runner-vpc}" "${ROUTER_REGION:-asia-east1}"
    ;;
esac
EOF
  chmod +x "${temp_dir}/gcloud"

  for drift_case in cidr network region; do
    case "${drift_case}" in
      cidr) SUBNET_CIDR=10.21.0.0/24 ;;
      network) SUBNET_NETWORK=wrong-vpc ;;
      region) SUBNET_REGION=us-central1 ;;
    esac
    if SUBNET_CIDR="${SUBNET_CIDR:-10.20.0.0/24}" SUBNET_NETWORK="${SUBNET_NETWORK:-frozen-runner-vpc}" \
      SUBNET_REGION="${SUBNET_REGION:-asia-east1}" PATH="${temp_dir}:${PATH}" \
      bash "${ROOT_DIR}/02_network/scripts/04_create-main-app-subnet.sh"; then
      printf 'Expected main subnet %s drift to fail\n' "${drift_case}" >&2
      return 1
    fi
    unset SUBNET_CIDR SUBNET_NETWORK SUBNET_REGION
  done

  for drift_case in range purpose network peering; do
    case "${drift_case}" in
      range) PSA_IP=10.31.0.0 ;;
      purpose) PSA_PURPOSE=PRIVATE_SERVICE_CONNECT ;;
      network) PSA_NETWORK=wrong-vpc ;;
      peering) PSA_PEERING_RANGE=wrong-range ;;
    esac
    if PSA_IP="${PSA_IP:-10.30.0.0}" PSA_PREFIX="${PSA_PREFIX:-16}" PSA_PURPOSE="${PSA_PURPOSE:-VPC_PEERING}" \
      PSA_NETWORK="${PSA_NETWORK:-frozen-runner-vpc}" PSA_PEERING_RANGE="${PSA_PEERING_RANGE:-frozen-runner-private-services-range}" \
      PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/05_create-private-services-access.sh"; then
      printf 'Expected private services access %s drift to fail\n' "${drift_case}" >&2
      return 1
    fi
    unset PSA_IP PSA_PURPOSE PSA_NETWORK PSA_PEERING_RANGE
  done

  for drift_case in region network; do
    case "${drift_case}" in
      region) ROUTER_REGION=us-central1 ;;
      network) ROUTER_NETWORK=wrong-vpc ;;
    esac
    if ROUTER_REGION="${ROUTER_REGION:-asia-east1}" ROUTER_NETWORK="${ROUTER_NETWORK:-frozen-runner-vpc}" \
      PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_network/scripts/06_create-router-nat.sh"; then
      printf 'Expected Cloud Router %s drift to fail\n' "${drift_case}" >&2
      return 1
    fi
    unset ROUTER_REGION ROUTER_NETWORK
  done
}

test_router_nat_scripts_fail_on_contract_drift() {
  local temp_dir log drift_case
  temp_dir="$(mktemp -d)"
  log="${temp_dir}/gcloud.log"
  trap 'rm -rf "${temp_dir}"' RETURN
  cat >"${temp_dir}/gcloud" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$1 \$2 \$3 \$4" in
  "compute routers describe"*)
    printf 'network: projects/echox-project/global/networks/frozen-runner-vpc\nregion: projects/echox-project/regions/asia-east1\n'
    ;;
  "compute addresses describe"*)
    if [[ "\${DRIFT_CASE:-}" == address-type ]]; then
      printf 'addressType: INTERNAL\n'
    elif [[ "\${DRIFT_CASE:-}" == address-region ]]; then
      printf 'addressType: EXTERNAL\nstatus: RESERVED\nregion: projects/echox-project/regions/us-central1\n'
    else
      printf 'addressType: EXTERNAL\nstatus: RESERVED\nregion: projects/echox-project/regions/asia-east1\n'
    fi
    ;;
  "compute routers nats describe"*)
    printf 'natIpAllocateOption: %s\nsourceSubnetworkIpRangesToNat: LIST_OF_SUBNETWORKS\nnatIps:\n- projects/echox-project/regions/asia-east1/addresses/frozen-runner-main-app-egress-ip\nsubnetworks:\n- name: projects/echox-project/regions/asia-east1/subnetworks/frozen-runner-main-app-subnet\n  sourceIpRangesToNat:\n  - ALL\n' \
      "\${NAT_IP_ALLOCATE_OPTION:-MANUAL_ONLY}"
    if [[ "\${DRIFT_CASE:-}" == nat-ip ]]; then
      printf 'natIps:\n- projects/echox-project/regions/asia-east1/addresses/wrong-ip\n'
    elif [[ "\${DRIFT_CASE:-}" == nat-subnet ]]; then
      printf 'subnetworks:\n- name: projects/echox-project/regions/asia-east1/subnetworks/wrong-subnet\n  sourceIpRangesToNat:\n  - ALL\n'
    fi
    ;;
esac
EOF
  chmod +x "${temp_dir}/gcloud"

  for drift_case in address-type address-region nat-ip nat-subnet; do
    if DRIFT_CASE="${drift_case}" PATH="${temp_dir}:${PATH}" \
      bash "${ROOT_DIR}/02_network/scripts/06_create-router-nat.sh"; then
      printf 'Expected %s drift to fail\n' "${drift_case}" >&2
      return 1
    fi
  done

  if NAT_IP_ALLOCATE_OPTION=AUTO_ONLY PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/02_network/scripts/06_create-router-nat.sh"; then
    printf 'Expected NAT allocation option drift to fail\n' >&2
    return 1
  fi
}

test_invalid_env_fails_before_gcloud
test_valid_env_loads
test_valid_env_can_be_sourced
test_role_lifecycle_arguments
test_network_scripts_reject_invalid_input_before_gcloud
test_network_scripts_create_absent_resources
test_network_scripts_fail_on_drift
test_network_resource_contract_drift_fails
test_router_nat_scripts_fail_on_contract_drift
printf 'network scripts tests passed\n'
