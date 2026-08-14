#!/usr/bin/env bash
# 用途：取得已建立的 Cloud NAT 固定 public IP。
# 流程：載入網路設定，唯讀查詢固定外部 IP 並輸出 IP 位址。
# 重要變數：EGRESS_IP_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION。
# 資源影響：只讀取既有 address；安全/驗證限制：空結果或不存在的 address 會停止。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# 唯讀查詢 ${GOOGLE_PROJECT_ID} 的 Cloud NAT 固定外部 IP，不修改資源。
public_ip="$(gcloud compute addresses describe "${EGRESS_IP_NAME}" \
  --region="${GOOGLE_PROJECT_REGION}" \
  --project="${GOOGLE_PROJECT_ID}" \
  --format='value(address)')"

if [[ -z "${public_ip}" ]]; then
  printf 'Public IP not found for %s\n' "${EGRESS_IP_NAME}" >&2
  exit 1
fi

printf '%s\n' "${public_ip}"
