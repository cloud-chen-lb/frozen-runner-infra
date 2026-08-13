#!/usr/bin/env bash
# 用途：確認指定 release tag 的 app 與 migration 映像可由 Artifact Registry 讀取。
# 流程：驗證 tag 後逐一描述兩個 image URI，輸出 digest。
# 重要變數：PROJECT_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION；不建立資源。
# 安全/驗證限制：只驗證映像存在與可描述，不驗證映像內容或部署成功。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 1 || ! "$1" =~ ^v.+$ ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/00_env.sh"
REPOSITORY_NAME="${PROJECT_NAME}-container-repository"

for image in "${PROJECT_NAME}-app" "${PROJECT_NAME}-migration"; do
  IMAGE_URI="${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}/${image}:$1"
  # 唯讀查詢 ${GOOGLE_PROJECT_ID} Artifact Registry 中的映像 digest，不修改資源。
  gcloud artifacts docker images describe "$IMAGE_URI" \
    --project="$GOOGLE_PROJECT_ID" \
    --format='value(image_summary.digest)'
  printf 'Verified image: %s\n' "$IMAGE_URI"
done
