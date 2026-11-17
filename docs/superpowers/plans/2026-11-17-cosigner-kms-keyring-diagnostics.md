# Co-Signer KMS Keyring 診斷提示實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 keyring 腳本明確顯示查詢或建立階段，並在查詢發生非「資源不存在」錯誤時顯示原因後停止。

**Architecture:** 沿用現有 Bash 腳本與 Co-Signer 測試架構，只修改 keyring provisioning 腳本及其測試。以模擬 `gcloud` 驗證既存、不存在及其他錯誤三種流程。

**Tech Stack:** Bash、gcloud CLI、現有 `03_co-signer/tests/scripts.sh`。

## Global Constraints

- 不新增外部工具或逾時機制。
- 除明確的 keyring NOT_FOUND 外，查詢錯誤不得觸發建立。
- 不執行實際 GCP 資源操作。
- 文件與註解使用台灣繁體中文。

---

### Task 1: 加上 keyring 查詢與建立診斷

**Files:**
- Modify: `03_co-signer/scripts/04_create-cloud-kms-keyring.sh`
- Modify: `03_co-signer/tests/scripts.sh`

**Interfaces:**
- Consumes: `00_env.sh` 提供的 `KMS_KEYRING`、`GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION`。
- Produces: 查詢及建立時顯示清楚階段；只有指定 keyring 明確 NOT_FOUND 時才建立；其他查詢錯誤顯示錯誤並非零結束。

- [x] **Step 1: 新增模擬 gcloud 測試**

  在 `03_co-signer/tests/scripts.sh` 加入測試函式，以暫存目錄中的 `gcloud` 假指令控制結果：
  - `KEYRING_STATE=present` 時，`describe` 成功；斷言輸出有查詢提示與已存在提示，且 log 沒有 `keyrings create`。
  - `KEYRING_STATE=absent` 時，`describe` 輸出包含指定 keyring 的 `NOT_FOUND` 並失敗；`create` 成功；斷言輸出有建立提示且 log 記錄 create。
  - `KEYRING_STATE=error` 時，`describe` 輸出 `permission denied` 並失敗；斷言腳本非零結束、錯誤可見且沒有 create。

- [x] **Step 2: 執行該測試並確認失敗**

  執行新增測試函式，確認目前腳本因缺少階段提示、隱藏查詢錯誤或錯誤時錯誤地建立資源而失敗。

- [x] **Step 3: 修改腳本通過測試**

  在 describe 前印出 keyring、project 與 location。describe 成功時回報 keyring 已存在。describe 失敗時只在輸出包含該 keyring 的明確 `NOT_FOUND` 時進入 create；其他錯誤輸出到 stderr 後退出。create 前印出建立提示，並讓 create 自身的輸出正常顯示。

- [x] **Step 4: 執行驗證**

  新增的 keyring 測試與 Bash 語法檢查通過。完整 `bash 03_co-signer/tests/scripts.sh` 在原有 `test_vm_ssh_key_is_instance_scoped_and_non_destructive` 測試失敗：測試期待的 gcloud 呼叫與目前測試環境的設定不符；失敗發生在 keyring 測試之前。
