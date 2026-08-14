#!/usr/bin/env bash
# 用途：建立或確認正式環境 Docker Artifact Registry repository。
# 流程：載入環境，以 PROJECT_NAME 組成 repository 名稱並先查詢再建立。
# 重要變數：PROJECT_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION；資源影響：建立容器 registry。
# 安全/驗證限制：只驗證 repository 是否存在，不改變既有 repository 設定。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 0 ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/00_env.sh"

REPOSITORY_NAME="${PROJECT_NAME}-container-repository"
# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Artifact Registry repository，不修改資源。
if gcloud artifacts repositories describe "$REPOSITORY_NAME" \
  --location="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" >/dev/null 2>&1; then
  printf 'Artifact Registry repository already exists: %s\n' \
    "${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}"
else
  # 在 ${GOOGLE_PROJECT_ID} 新增 Docker Artifact Registry repository。
  gcloud artifacts repositories create "$REPOSITORY_NAME" \
    --repository-format=docker \
    --description="正式環境 app 與 migration 容器映像儲存庫。" \
    --location="$GOOGLE_PROJECT_REGION" \
    --project="$GOOGLE_PROJECT_ID"
  printf 'Created Artifact Registry repository: %s\n' \
    "${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${REPOSITORY_NAME}"
fi
