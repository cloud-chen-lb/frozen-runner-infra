# Co-Signer API 啟用腳本實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Co-Signer 資源建立前自動啟用該模組所需的 GCP API，避免 gcloud 停在互動式 API 啟用提示。

**Architecture:** 新增 `00_enable-apis.sh`，沿用 `02_main-app` 逐項查詢並啟用 API 的方式。以 mock gcloud 測試 API 缺漏與已啟用流程，並更新 README 執行順序。

**Tech Stack:** Bash、gcloud CLI、現有 `03_co-signer/tests/scripts.sh`。

## Global Constraints

- 所需 API：`cloudkms.googleapis.com`、`compute.googleapis.com`、`iam.googleapis.com`、`sqladmin.googleapis.com`。
- 已啟用的 API 不重複啟用。
- 不執行實際 GCP API 啟用操作。
- 文件與註解使用台灣繁體中文。
- 不建立 worktree、不提交變更，除非開發者另行明確要求。

---

### Task 1: 新增 API 啟用腳本與測試

**Files:**
- Create: `03_co-signer/scripts/00_enable-apis.sh`
- Modify: `03_co-signer/tests/scripts.sh`

**Interfaces:**
- Consumes: `03_co-signer/scripts/00_env.sh` 載入的 `GOOGLE_PROJECT_ID`。
- Produces: 確認並啟用上述四個 API；輸出各 API 已啟用或剛啟用的狀態。

- [x] **Step 1: 寫 mock gcloud 測試**

  在測試檔新增測試函式與暫存 `gcloud`：`services list` 根據 `API_STATE` 回傳已啟用 API；`services enable` 將呼叫記錄至 log。測試缺少 API 時確認對四個指定 API 各執行一次 enable，測試全部已啟用時確認沒有 enable 呼叫，並確認腳本輸出狀態。將測試函式加入檔案末尾的測試呼叫清單。

- [x] **Step 2: 執行新測試確認失敗**

  執行新測試函式；目前因腳本尚不存在而失敗，確認測試確實要求 `00_enable-apis.sh` 的行為。

- [x] **Step 3: 實作 API 啟用腳本**

  沿用 `02_main-app/scripts/02_enable-apis.sh`：啟用 `set -euo pipefail`、載入同目錄的 `00_env.sh`，對四個 API 逐一執行 `gcloud services list --enabled --project="$GOOGLE_PROJECT_ID" --filter="config.name=$api" --format='value(config.name)'`；輸出已啟用 API 的狀態，否則執行 `gcloud services enable "$api" --project="$GOOGLE_PROJECT_ID"` 並回報啟用結果。設為可執行，與同目錄腳本慣例一致。

- [x] **Step 4: 執行新測試確認通過**

  重跑新增測試函式，確認既有 API 不重複啟用，缺少 API 會逐一啟用。

### Task 2: 更新 Co-Signer 執行文件

**Files:**
- Modify: `03_co-signer/README.md`

**Interfaces:**
- Consumes: Task 1 新增的 `03_co-signer/scripts/00_enable-apis.sh`。
- Produces: 建立流程指示先啟用 API，再執行 IAM、Subnet、Cloud SQL 與 KMS 建立腳本。

- [x] **Step 1: 將 `00_enable-apis.sh` 加入 README 建立流程首行**

- [x] **Step 2: 驗證**

  新增測試、`bash -n 03_co-signer/scripts/*.sh 03_co-signer/tests/scripts.sh` 與 `git diff --check` 通過。完整 `bash 03_co-signer/tests/scripts.sh` 在既有 VM SSH 測試失敗：測試預期 gcloud 呼叫使用 `echox-project`，但目前測試環境使用 `frozen-runner-production`；失敗發生在新增 API 測試之前。新增 API 測試已獨立通過。
