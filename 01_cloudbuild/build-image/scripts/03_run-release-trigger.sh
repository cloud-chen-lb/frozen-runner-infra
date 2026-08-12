#!/usr/bin/env bash
# 用途：以指定的 v<release> tag 手動執行正式映像建置 trigger。
# 流程：驗證單一 tag 參數後，呼叫 gcloud builds triggers run。
# 重要變數：PROJECT_NAME、GOOGLE_PROJECT_REGION、GOOGLE_PROJECT_ID；資源影響：啟動建置，不直接修改部署資源。
# 安全/驗證限制：只接受 v 開頭且非空的 tag，仍依 trigger 既有設定執行。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  printf 'Usage: %s v<release>\n' "${BASH_SOURCE[0]}" >&2
}

if [[ "$#" -ne 1 || ! "$1" =~ ^v.+$ ]]; then
  usage
  exit 1
fi

source "${SCRIPT_DIR}/../../base/scripts/00_env.sh"
TRIGGER_NAME="${PROJECT_NAME}-release-build-trigger"

# 在 ${GOOGLE_PROJECT_ID} 執行 release Cloud Build trigger，啟動映像建置。
gcloud builds triggers run "$TRIGGER_NAME" \
  --region="$GOOGLE_PROJECT_REGION" --project="$GOOGLE_PROJECT_ID" --tag="$1"
