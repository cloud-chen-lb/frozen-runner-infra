#!/usr/bin/env bash
# 用途：確認移除 co-signer 執行 IAM role 的腳本只移除指定 binding。
# 流程：建立暫存 mock gcloud，執行移除腳本並檢查命令內容未包含建立/更新或秘密相關操作。
# 重要變數：ROOT_DIR、PATH、暫存 log；資源影響：只建立暫存目錄與 mock log，不修改 GCP。
# 安全/驗證限制：只驗證命令文字與不建立資源，未驗證真實 IAM API 回應。
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

test_role_removal_does_not_create_resources() {
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
  ! grep -Eiq '(^|[[:space:]])password=|--password|private[_-]?key|\.json($|[[:space:]])|BEGIN .*PRIVATE KEY|create|update' "${log}"
}

test_role_removal_does_not_create_resources
printf 'co-signer scripts tests passed\n'
