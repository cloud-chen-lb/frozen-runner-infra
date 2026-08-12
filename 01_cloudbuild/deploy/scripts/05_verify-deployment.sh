#!/usr/bin/env bash
# 用途：驗證指定 release 的映像、Cloud Run migration job、最近執行與 app service 狀態。
# 流程：描述兩個映像與 job，找最近 migration execution，再描述 app；設定 URL 時才做 smoke test。
# 重要參數：v<release>、DEPLOY_SMOKE_TEST_URL 及部署環境變數；不建立或修改資源。
# 安全/驗證限制：只做狀態/存在性檢查，smoke test 有 15 秒上限；未設定 URL 不會自行發送請求。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

[[ "$#" -eq 1 && "$1" =~ ^v.+$ ]] || {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
  exit 1
}
for variable in GOOGLE_PROJECT_REGION APP_VPC_ARGS MIGRATION_VPC_ARGS APP_SECRET_MAPPING \
  MIGRATION_SECRET_MAPPING; do
  [[ -n "${!variable:-}" ]] || { printf '%s is required\n' "${variable}" >&2; exit 1; }
done

image_base="${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${PROJECT_NAME}-container-repository"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 app 映像，不修改資源。
gcloud artifacts docker images describe "${image_base}/${PROJECT_NAME}-app:$1" --project="${GOOGLE_PROJECT_ID}"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 migration 映像，不修改資源。
gcloud artifacts docker images describe "${image_base}/${PROJECT_NAME}-migration:$1" --project="${GOOGLE_PROJECT_ID}"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 migration job 設定，不修改資源。
gcloud run jobs describe "${PRODUCTION_MIGRATION_JOB_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" --format='yaml(name,location,template.template.containers[0].image)'
# 唯讀列出 ${GOOGLE_PROJECT_ID} 最近的 migration job execution，不修改資源。
latest_execution="$(gcloud run jobs executions list --job="${PRODUCTION_MIGRATION_JOB_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}" \
  --limit=1 --format='value(name)')"
[[ -n "${latest_execution}" ]] || { printf 'No migration execution found\n' >&2; exit 1; }
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 最近的 migration execution，不修改資源。
gcloud run jobs executions describe "${latest_execution}" \
  --region="${GOOGLE_PROJECT_REGION}" --project="${GOOGLE_PROJECT_ID}"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 production app service 狀態，不修改資源。
gcloud run services describe "${PRODUCTION_APP_NAME}" --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --format='yaml(status.latestReadyRevisionName,status.traffic,spec.template.spec.containers[0].image,metadata.annotations.run.googleapis.com/ingress)'

if [[ -n "${DEPLOY_SMOKE_TEST_URL:-}" ]]; then
  curl --fail --silent --show-error --max-time 15 "${DEPLOY_SMOKE_TEST_URL}" >/dev/null
fi
