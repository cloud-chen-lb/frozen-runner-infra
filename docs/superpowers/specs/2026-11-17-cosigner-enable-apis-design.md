# Co-Signer API 啟用腳本設計

## 目標

在 Co-Signer 建立任何資源前確認其所需 GCP API 已啟用，避免 API 未啟用時 gcloud 提示等待互動輸入。

## 設計

- 新增 `03_co-signer/scripts/00_enable-apis.sh`，沿用 `02_main-app/scripts/02_enable-apis.sh` 的逐項查詢與啟用模式。
- 需要的 API 為 `cloudkms.googleapis.com`、`compute.googleapis.com`、`iam.googleapis.com`、`sqladmin.googleapis.com`。
- 已啟用的 API 顯示狀態但不重複啟用；未啟用的 API 使用 `gcloud services enable` 啟用並回報結果。
- README 建立流程將此腳本列為第一步。
- 以 mock gcloud 測試已啟用與缺少 API 的處理，不操作實際 GCP 專案。

## 不在本次範圍

- 不修改既有資源建立腳本或增加 API 啟用逾時。
- 不啟用 Co-Signer 資源以外的 API。
