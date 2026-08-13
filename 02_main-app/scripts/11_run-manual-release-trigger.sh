#!/usr/bin/env bash
# 用途：以 v<release> 與指定分支執行手動 release trigger。
# 流程：驗證 tag/分支參數後，帶入 _IMAGE_TAG 呼叫 Cloud Build trigger。
# 重要變數：PROJECT_NAME、GOOGLE_PROJECT_REGION、SOURCE_BRANCH；資源影響：啟動映像建置。
# 安全/驗證限制：不接受空分支或非 v 開頭 tag，實際權限與建置內容由 trigger 控制。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s v<release> BRANCH\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 2 || ! "$1" =~ ^v.+$ || -z "$2" ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/00_env.sh"

TRIGGER_NAME="${PROJECT_NAME}-manual-release-build-trigger"
SOURCE_BRANCH="$2"

# 在 ${GOOGLE_PROJECT_ID} 執行 manual release trigger，啟動映像建置。
gcloud builds triggers run "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" \
  --branch="$SOURCE_BRANCH" --substitutions="_IMAGE_TAG=$1"
