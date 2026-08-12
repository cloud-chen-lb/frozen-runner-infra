#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOADER="${ROOT_DIR}/01_cloudbuild/base/scripts/00_env.sh"

test_global_env_wins_and_cloud_build_metadata_loads() {
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  mkdir -p "${temp_dir}/01_cloudbuild/base/scripts/env" "${temp_dir}/global-env"
  cp "${LOADER}" "${temp_dir}/01_cloudbuild/base/scripts/00_env.sh"

  cat >"${temp_dir}/global-env/env.sh" <<'EOF'
PROJECT_NAME=global-project
GOOGLE_PROJECT_ID=global-project-id
GOOGLE_PROJECT_REGION=global-region
EXEC_IAM_ACCOUNT=global@example.com
EOF
  cat >"${temp_dir}/01_cloudbuild/base/scripts/env/env.sh" <<'EOF'
PROJECT_NAME=base-project
GOOGLE_PROJECT_ID=base-project-id
GOOGLE_PROJECT_REGION=base-region
EXEC_IAM_ACCOUNT=base@example.com
CLOUD_BUILD_CONNECTION_NAME=Github_Connect
CLOUD_BUILD_REPOSITORY_NAME=echox-project-frozen-runner
EOF

  bash "${temp_dir}/01_cloudbuild/base/scripts/00_env.sh"
  (
    source "${temp_dir}/01_cloudbuild/base/scripts/00_env.sh"
    [[ "${PROJECT_NAME}" == global-project ]]
    [[ "${GOOGLE_PROJECT_ID}" == global-project-id ]]
    [[ "${GOOGLE_PROJECT_REGION}" == global-region ]]
    [[ "${EXEC_IAM_ACCOUNT}" == global@example.com ]]
    [[ "${CLOUD_BUILD_CONNECTION_NAME}" == Github_Connect ]]
    [[ "${CLOUD_BUILD_REPOSITORY_NAME}" == echox-project-frozen-runner ]]
  )
}

test_global_env_wins_and_cloud_build_metadata_loads

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
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh"
  create_permissions="$(grep -F 'iam roles create CloudBuildSetupOperator' "${log}")"
  PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh"
  grep -F 'projects add-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudBuildSetupOperator' "${log}"
  grep -F 'projects remove-iam-policy-binding echox-project --member=user:cloud.chen@getoken.io --role=projects/echox-project/roles/CloudBuildSetupOperator' "${log}"
  ROLE_EXISTS=1 PATH="${temp_dir}:${PATH}" bash "${ROOT_DIR}/01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh"
  update_permissions="$(grep -F 'iam roles update CloudBuildSetupOperator' "${log}")"
  [[ "${create_permissions#*--permissions=}" == "${update_permissions#*--permissions=}" ]]
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY' "${log}"
}

test_role_lifecycle_arguments
printf 'cloudbuild base scripts tests passed\n'
