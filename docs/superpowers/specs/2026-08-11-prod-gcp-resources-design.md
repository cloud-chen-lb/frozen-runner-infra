# Production GCP Resources Design

## Scope

依據 `/Users/leadbest/Documents/Work/frozen-runner/cicd/prod/README.md`，補齊主系統正式環境資源。此次不處理 Co-Signer 相關資源，也不重做目前已存在的 Cloud Build image pipeline。

### Included

- 主系統 VPC、subnet、Private Services Access、Cloud Router、Cloud NAT 與固定出口 IP
- 主系統 PostgreSQL Cloud SQL instance、database 與 application/migration users
- 主系統 runtime、migration、deploy service accounts 與最小 IAM
- 主系統 Secret Manager secrets 與 accessor bindings
- `frozen-runner-main-app` Cloud Run service
- `frozen-runner-db-migration` Cloud Run Job
- production deploy Cloud Build trigger 與 deploy scripts
- idempotent provisioning scripts、設定檢查與不連線 GCP 的 shell tests

### Excluded

- `05_co-signer/` 目錄及其 VM、KMS、merchant service account、static IP
- `frozen-runner-cosigner-subnet`
- `frozen-runner-cosigner-mysql`、merchant database/user
- 既有 Global Load Balancer、DNS、TLS、serverless backend 與 callback source restriction
- 既有 Cloud Build base、Artifact Registry、CI trigger、release image trigger

## Project Identity

資源命名與 API 目標分開處理：

- `PROJECT_NAME=frozen-runner`：資源名稱前綴
- `GOOGLE_PROJECT_ID=echox-project`：實際執行 GCP API 的 project ID

所有 scripts 從 `global-env/env.sh` 載入這兩個值，不以 `PROJECT_NAME` 推導 project ID，也不在 script 內硬編碼 project。

## Directory Layout

```text
frozen-runner-infra/
├── global-env/
├── 02_network/
│   └── scripts/
├── 03_cloudsql/
│   └── scripts/
├── 04_main-app/
│   └── scripts/
└── 01_cloudbuild/
    └── deploy/
        └── scripts/
```

各目錄只負責同一層資源，腳本以數字前綴表達建立順序。既有 `01_cloudbuild/base` 與 `01_cloudbuild/build-image` 不搬移、不改名。

## Provisioning Order

### 1. Network

建立並確認：

- `frozen-runner-vpc`
- `frozen-runner-main-app-subnet`
- `frozen-runner-private-services-range`
- Private Services Access peering
- `frozen-runner-router`
- `frozen-runner-main-app-egress-ip`
- `frozen-runner-main-app-nat`

Network scripts 必須在建立前檢查既有資源。資源存在但 CIDR、region、network 或 NAT 設定不一致時停止，不自動修改。

### 2. PostgreSQL

建立 `frozen-runner-main-app-postgres` Cloud SQL PostgreSQL instance，設定：

- Private IP only
- Regional HA
- automated backup
- PITR
- deletion protection

建立主系統 database/user 與 migration 專用 DDL user。密碼不進 Git、不放 Cloud Build substitutions；由互動式 stdin 或 Secret Manager version 建立。

Co-Signer MySQL instance 完全留到後續工作，不在本階段建立。

### 3. IAM and Secrets

建立並設定：

- `cb-frozen-runner-mini`
- `cb-frozen-runner-migration`
- `cb-frozen-runner-deploy`

權限限制如下：

- app runtime 只讀取主系統 runtime secrets
- migration runtime 只讀取 PostgreSQL/migration secrets
- deploy identity 只具 Cloud Run deploy、Artifact Registry read，以及對兩個 runtime service account 的 `serviceAccountUser`
- Private IP 直連 PostgreSQL 時，不授予 runtime `roles/cloudsql.client`
- 不建立 service-account JSON key，不授予 Owner、Editor 或 project-wide secret/KMS admin

Secret provisioning 只建立 secret metadata 與 IAM binding；實際 secret value 由操作者另行透過 stdin 建立，並在 deploy 前檢查 required mapping 完整性。

### 3.1 Temporary Provisioning Operator

`EXEC_IAM_ACCOUNT` 是資源建立期間的臨時操作者，不是 runtime identity。新增資源的 provisioning scripts 必須納入其授權流程，讓所有資源完成後可以乾淨撤銷。

既有 `05_co-signer/scripts/01_setup-exec-iam-account-role.sh` 也屬於本 repo 的 provisioning 授權來源，因此必須提供對應的 scoped removal script；本次仍不執行任何 Co-Signer 資源建立。

沿用目前 `01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh` 的模式，但將權限拆成依資源邊界的 project-level custom roles：

- network provisioning operator
- Cloud SQL provisioning operator
- runtime/IAM/Secret Manager provisioning operator
- Cloud Build deploy provisioning operator

每個 role 只包含對應 scripts 實際使用的 permissions。setup script 必須：

1. create 或 update custom role，使重跑不因 role 已存在而失敗。
2. 將 role binding 授予 `user:${EXEC_IAM_ACCOUNT}`。
3. 輸出已授予的 roles 與後續撤銷指令。

新增 `99_revoke-exec-iam-account-roles.sh`，只撤銷本 repo 明確建立的 custom role bindings；成功後可選擇刪除這些 custom roles。不得掃描並刪除 `EXEC_IAM_ACCOUNT` 在 project 上所有未知角色，避免誤刪其他系統或人工授權。

所有 provisioning scripts 都必須要求 `EXEC_IAM_ACCOUNT` 已設定，但不在每個模組重複授權。建議執行流程為：

```text
setup-exec-iam-roles
  -> network
  -> cloudsql
  -> main-app IAM/secrets
  -> Cloud Run
  -> Cloud Build deploy
  -> revoke-exec-iam-roles
```

runtime service accounts 與 `EXEC_IAM_ACCOUNT` 完全分離；撤銷執行人 roles 不得移除 runtime 或 Cloud Build service account 的 bindings。

### 4. Cloud Run

`frozen-runner-db-migration` 使用 migration image、migration service account、Private VPC egress 與 migration secrets。Deploy pipeline 先更新並執行 Job，等待成功後才更新 `frozen-runner-main-app`。

`frozen-runner-main-app` 使用 app image、app runtime service account、Direct VPC egress、runtime secrets，以及 `internal-and-cloud-load-balancing` ingress。

### 5. Cloud Build Deploy

在 `01_cloudbuild/deploy/` 補上：

- deploy service account/IAM setup
- production deploy trigger 的建立與 drift check
- deploy trigger 執行與輸入驗證
- 非 GCP shell tests

同時只做必要的 sibling repo YAML 修正：`cloudbuild-deploy.yaml` 的 project identity 改用 Cloud Build `${PROJECT_ID}`，不改變 migration-before-app 的流程。

## Configuration Contract

新增 scripts 不硬編碼下列部署決策，改由 environment file 提供並在 provisioning 前 fail fast：

- region
- main app subnet CIDR
- Private Services Access CIDR
- PostgreSQL version、tier、storage
- database/user names
- app 與 migration secret mapping
- Cloud Build source repository、branch 與 existing load balancer smoke-test URL

既有 `global-env/env.sh` 保留為 active environment 唯一入口；新增設定集中在各模組的 `scripts/env/env.sh`，不建立 dev/prod 參數分支。

## Safety and Idempotency

所有 provisioning scripts 使用 `set -euo pipefail`、script-relative path、quoted substitutions，並遵循：

1. 先 describe/list。
2. 不存在才 create。
3. 存在但契約不符就失敗並列出 drift。
4. 不刪除、不覆蓋、不自動修正外部既有資源。
5. 不在測試或 dry-run 中呼叫會修改 GCP 的命令。

## Verification

本地驗證包含：

- `bash -n` 檢查所有新增與既有相關 shell scripts
- mock `gcloud` 測試 invalid input 在第一次 GCP 呼叫前失敗
- `git diff --check`
- 對每個已存在資源的 drift check 測試

實際 GCP provisioning 只在操作者確認 project、region、CIDR、database sizing 與 secret mapping 後執行，並按 network → PostgreSQL → IAM/secrets → Cloud Run → deploy trigger 順序進行。

## Open Decisions Before Implementation

以下值尚未由 prod README 定義，實作前必須填入設定檔：

- Cloud Run、Cloud SQL、Cloud NAT、Cloud Build region
- `frozen-runner-main-app-subnet` CIDR
- `frozen-runner-private-services-range` CIDR
- PostgreSQL version、machine tier、storage size
- app/migration 必要 secret 的實際名稱與 version
- Git source branch
- smoke test URL 與檢查項目
- `EXEC_IAM_ACCOUNT` provisioning custom roles 的最終 permission review
- 既有 Co-Signer provisioning role 的撤銷確認
