# CI Trigger ActAs 權限實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cloud Build IAM 設定腳本在 `cb-share-build` 建立或確認後，授予 `EXEC_IAM_ACCOUNT` 對該帳號的 `roles/iam.serviceAccountUser`。

**Architecture:** 在 `02_main-app/scripts/03_setup-cloud-build-iam.sh` 增加 service-account 層級的 IAM binding，成員取自已載入的 `EXEC_IAM_ACCOUNT`。不將 `iam.serviceAccounts.actAs` 加到專案自訂角色，維持只對 `cb-share-build` 授權。

**Tech Stack:** Bash、gcloud CLI、現有 shell mock 測試。

## Global Constraints

- 不讀取或輸出機敏設定值。
- 測試只使用 mock gcloud，不修改真實 GCP IAM。
- 不變更既有的 Cloud Build service agent 權限設定。

---

### Task 1：覆蓋執行者的 service-account 權限綁定

**Files:**
- Modify: `02_main-app/tests/cloudbuild-tests.sh`
- Modify: `02_main-app/scripts/03_setup-cloud-build-iam.sh`

**Interfaces:**
- Consumes: `EXEC_IAM_ACCOUNT`、`CI_SERVICE_ACCOUNT`、`GOOGLE_PROJECT_ID`，由 `00_env.sh` 載入。
- Produces: 在 `cb-share-build` 的 IAM policy 上，以 `user:${EXEC_IAM_ACCOUNT}` 成員授予 `roles/iam.serviceAccountUser`。

- [ ] **Step 1：先新增 mock 測試**

在 `cloudbuild-tests.sh` 補測試，執行 `03_setup-cloud-build-iam.sh` 時記錄 gcloud 呼叫，驗證命令包含 `iam service-accounts add-iam-policy-binding cb-share-build@...`、`--member=user:<EXEC_IAM_ACCOUNT>`、`--role=roles/iam.serviceAccountUser`；並確認既有 service agent binding 仍存在。

- [ ] **Step 2：執行測試確認失敗**

執行 `bash 02_main-app/tests/cloudbuild-tests.sh`，確認新測試因缺少執行者 binding 而失敗，而不是測試環境或 shell 語法錯誤。

- [ ] **Step 3：加入最小實作**

在 `03_setup-cloud-build-iam.sh` 既有 Cloud Build service agent binding 附近，加入對 `CI_SERVICE_ACCOUNT` 的 IAM binding：成員為 `user:${EXEC_IAM_ACCOUNT}`，角色為 `roles/iam.serviceAccountUser`，專案為 `${GOOGLE_PROJECT_ID}`。

- [ ] **Step 4：驗證**

重新執行 `bash 02_main-app/tests/cloudbuild-tests.sh` 與 `bash -n 02_main-app/scripts/03_setup-cloud-build-iam.sh 02_main-app/tests/cloudbuild-tests.sh`；mock 測試須通過，且不得呼叫真實 GCP。
