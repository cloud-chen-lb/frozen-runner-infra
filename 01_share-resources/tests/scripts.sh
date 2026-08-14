#!/usr/bin/env bash
# 用途：驗證網路模組腳本的輸入檢查與 IAM role lifecycle。
# 流程：以暫存 env/mock gcloud 執行測試，確認網路資源腳本在錯誤設定下停止且 role 權限一致。
# 重要變數：ROOT_DIR、PATH 及模組 CIDR/region 設定；資源影響：只建立暫存測試檔，不修改 GCP。
# 安全/驗證限制：mock 只檢查命令，不代表真實 VPC、peering 或 NAT API 已成功。
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOADER="${ROOT_DIR}/01_share-resources/scripts/00_env.sh"

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
COSIGNER_SUBNET_CIDR=10.40.0.0/24
COSIGNER_SUBNET_CIDR=10.40.0.0/24
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
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create ShareResourcesProvisioningOperator' "${log}")"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update ShareResourcesProvisioningOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/99_remove-exec-iam-account-role.sh"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  [[ "${create_permissions}" == *'compute.networks.updatePolicy'* ]]
  [[ "${create_permissions}" == *'compute.networks.use'* ]]
  [[ "${create_permissions}" == *'compute.globalAddresses.createInternal'* ]]
  [[ "${create_permissions}" == *'compute.subnetworks.update'* ]]
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/ShareResourcesProvisioningOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/ShareResourcesProvisioningOperator' "${log}"
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
COSIGNER_SUBNET_CIDR=10.40.0.0/24
PRIVATE_SERVICES_RANGE_CIDR=10.30.0.0/16
EOF
  cat >"${temp_dir}/gcloud" <<'EOF'
#!/usr/bin/env bash
printf 'gcloud must not be called\n' >&2
exit 99
EOF
  chmod +x "${temp_dir}/gcloud"
  for script in 02_enable-apis.sh 03_create-vpc.sh \
    04_create-private-services-access.sh; do
    if PATH="${temp_dir}:${PATH}" GLOBAL_ENV_FILE="${temp_dir}/global-env.sh" \
      MODULE_ENV_FILE="${temp_dir}/module-env.sh" bash "${ROOT_DIR}/01_share-resources/scripts/${script}"; then
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
  for script in 02_enable-apis.sh 03_create-vpc.sh \
    04_create-private-services-access.sh; do
    PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/${script}"
  done
  grep -F 'compute networks create frozen-runner-vpc' "${log}"
  grep -F 'compute addresses create frozen-runner-private-services-range' "${log}"
  grep -F 'services vpc-peerings connect' "${log}"
  ! grep -Eiq 'mysql|load-balancer|password|private[_-]?key|\.json|BEGIN .*PRIVATE KEY' "${log}"
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
  if PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/03_create-vpc.sh"; then
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
       bash "${ROOT_DIR}/02_main-app/scripts/12_create-main-app-subnet.sh"; then
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
      PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_share-resources/scripts/04_create-private-services-access.sh"; then
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
      PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/02_main-app/scripts/13_create-router-nat.sh"; then
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

  export MAIN_APP_SUBNET_CIDR=10.20.0.0/24
  export NETWORK_NAME=frozen-runner-vpc
  export MAIN_APP_SUBNET_NAME=frozen-runner-main-app-subnet
  export ROUTER_NAME=frozen-runner-router
  export EGRESS_IP_NAME=frozen-runner-main-app-egress-ip
  export NAT_NAME=frozen-runner-main-app-nat

  for drift_case in address-type address-region nat-ip nat-subnet; do
    if DRIFT_CASE="${drift_case}" PATH="${temp_dir}:${PATH}" \
      bash "${ROOT_DIR}/02_main-app/scripts/13_create-router-nat.sh"; then
      printf 'Expected %s drift to fail\n' "${drift_case}" >&2
      return 1
    fi
  done

  if NAT_IP_ALLOCATE_OPTION=AUTO_ONLY PATH="${temp_dir}:${PATH}" \
    bash "${ROOT_DIR}/02_main-app/scripts/13_create-router-nat.sh"; then
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
