# 02_main-app：主系統正式環境

本模組管理主系統的 Cloud Build、Artifact Registry、Cloud NAT、PostgreSQL Cloud SQL、service account、Secret Manager 與 Cloud Run 部署。所有腳本都從根目錄的 `global-env/env.sh` 讀取 project、region 與執行帳號；本模組設定集中在 `scripts/env/env.sh`。環境檔只放非機密設定，密碼與 secret value 不得提交 Git、放入 argv、Cloud Build substitutions 或 log。

## 前置設定

1. 安裝並登入 `gcloud`：

   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. 確認 `global-env/env.sh` 的 `PROJECT_NAME`、`GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION` 與 `EXEC_IAM_ACCOUNT` 指向正確正式環境。
3. 確認 `scripts/env/env.sh` 的 Cloud Build connection/repository 名稱、PostgreSQL 規格、subnet CIDR、secret mapping 與 Cloud Run metadata。主系統 subnet 使用 `10.20.0.0/24`，VPC 使用 `${PROJECT_NAME}-vpc`。

## 腳本順序

檔名序號唯一，以下是完整順序。除特別標示外，腳本是可重複執行的合約檢查或 idempotent 建立流程；既有資源設定漂移時會停止，不會自動覆蓋。

| 序號 | 腳本 | 用途 |
| --- | --- | --- |
| 00 | `00_env.sh` | 載入全域與單一模組 env。 |
| 01 | `01_setup-exec-iam-account-role.sh` | 建立/更新執行者自訂 IAM role。 |
| 02 | `02_enable-apis.sh` | 啟用 Cloud Build、GAR、IAM、Logging 等 API。 |
| 03 | `03_setup-cloud-build-iam.sh` | 建立 `cb-share-build` 與建置權限。 |
| 04 | `04_setup-github-connection.sh` | 建立或確認 Cloud Build GitHub connection/repository，需互動式 GitHub 授權。 |
| 05 | `05_create-artifact-registry.sh` | 建立或確認 GAR Docker repository。 |
| 06 | `06_create-ci-trigger.sh` | 建立 PR CI trigger。 |
| 07 | `07_create-release-trigger.sh` | 建立 `v*` release image build trigger。 |
| 08 | `08_run-release-trigger.sh` | 執行既有 release trigger。 |
| 09 | `09_verify-images.sh` | 驗證 app 與 migration image digest。 |
| 10 | `10_create-manual-release-trigger.sh` | 建立選用的純手動 image trigger。 |
| 11 | `11_run-manual-release-trigger.sh` | 執行選用的純手動 image trigger。 |
| 12 | `12_create-main-app-subnet.sh` | 建立或確認主系統 subnet。 |
| 13 | `13_create-router-nat.sh` | 建立或確認固定出口 IP、Cloud Router 與只供主系統 subnet 使用的 Cloud NAT。 |
| 14 | `14_create-postgres-instance.sh` | 建立 private IP、Regional HA、backup、PITR、deletion protection 的 PostgreSQL instance。 |
| 15 | `15_create-postgres-database-users.sh` | 建立 database、app user 與 migration user；密碼只從 stdin 或核准的 Secret Manager version 取得。 |
| 16 | `16_print-connection-strings.sh` | 輸出不含真實密碼的 private connection string 範本。 |
| 17 | `17_setup-service-accounts.sh` | 建立 app、migration、deploy service account 與最小 IAM binding。 |
| 18 | `18_setup-secrets.sh` | 建立 Secret Manager metadata 與 scoped accessor binding，不建立 secret version。 |
| 19 | `19_setup-deploy-iam.sh` | 配置 production deploy service account 的 Cloud Run、GAR 與 runtime impersonation 權限。 |
| 20 | `20_create-production-trigger.sh` | 建立人工 production deploy trigger。 |
| 21 | `21_run-production-deploy.sh` | 以已建置的 release tag 觸發 migration 後 app deploy。 |
| 22 | `22_verify-deployment.sh` | 驗證 image、migration job/execution、Cloud Run revision 與選用 smoke test。 |
| 23 | `23_get-public-ip.sh` | 選用：查詢 Cloud NAT 固定出口 IP。 |
| 99 | `99_remove-exec-iam-account-role.sh` | 選用清理：只撤銷執行者自訂 role binding，不刪除資源。 |

## 一次性基礎設施

依序執行以下腳本建立基礎資源。`04_setup-github-connection.sh` 的三個參數依序為 connection name、repository name、Git remote URI；若 connection/repository 已由既有負責人管理，可略過，但必須把名稱回填 `scripts/env/env.sh`。

```bash
bash 02_main-app/scripts/01_setup-exec-iam-account-role.sh
bash 02_main-app/scripts/02_enable-apis.sh
bash 02_main-app/scripts/03_setup-cloud-build-iam.sh
bash 02_main-app/scripts/04_setup-github-connection.sh CONNECTION_NAME REPOSITORY_NAME https://github.com/OWNER/REPOSITORY.git
bash 02_main-app/scripts/05_create-artifact-registry.sh
bash 02_main-app/scripts/06_create-ci-trigger.sh
bash 02_main-app/scripts/07_create-release-trigger.sh
bash 02_main-app/scripts/12_create-main-app-subnet.sh
bash 02_main-app/scripts/13_create-router-nat.sh
bash 02_main-app/scripts/14_create-postgres-instance.sh
bash 02_main-app/scripts/15_create-postgres-database-users.sh
bash 02_main-app/scripts/16_print-connection-strings.sh
bash 02_main-app/scripts/17_setup-service-accounts.sh
bash 02_main-app/scripts/18_setup-secrets.sh
bash 02_main-app/scripts/19_setup-deploy-iam.sh
bash 02_main-app/scripts/20_create-production-trigger.sh
```

PostgreSQL 使用 private IP 連線至 `${PROJECT_NAME}-main-app-postgres`。資料庫密碼不由這些腳本保存；互動建立時由 stdin/終端輸入，非互動建立時使用完整 Secret Manager version reference，例如 `--app-password-secret-version=projects/PROJECT/secrets/NAME/versions/VERSION`。`16_print-connection-strings.sh` 的 `<PASSWORD>` 只是 placeholder。

`18_setup-secrets.sh` 只建立 secret metadata 與 accessor binding。secret versions/values 必須由核准流程另行寫入。app runtime 只讀取主系統 secrets；migration 使用獨立 `cb-${PROJECT_NAME}-migration`，不授予一般 app runtime migration 權限。

## Cloud Build、GAR 與映像

CI、release image build 與 production deploy 分離：

- PR CI（`06`）執行 type check、lint、unit test 與 build，不推送 production image、不部署、不讀 production secret。
- Release image build（`07`、`08` 或選用 `10`、`11`）以 `v*` tag 建立並推送同一 tag 的 app 與 migration image。兩個 image 都完成後以 `09` 驗證。
- Production deploy 不重新 build，只接受已由 release build 產生且驗證過的 tag。

自動 release 範例：

```bash
git tag v1.2.3
git push origin v1.2.3
bash 02_main-app/scripts/08_run-release-trigger.sh v1.2.3
bash 02_main-app/scripts/09_verify-images.sh v1.2.3
```

若要使用純手動 trigger：

```bash
bash 02_main-app/scripts/10_create-manual-release-trigger.sh
bash 02_main-app/scripts/11_run-manual-release-trigger.sh v1.2.3 master
bash 02_main-app/scripts/09_verify-images.sh v1.2.3
```

## Production deploy

人工選擇已驗證的 release tag 後執行：

```bash
bash 02_main-app/scripts/21_run-production-deploy.sh v1.2.3
bash 02_main-app/scripts/22_verify-deployment.sh v1.2.3
```

deploy pipeline 必須先更新並執行 migration Cloud Run Job，等待 migration 成功後，才以相同 tag 更新 `frozen-runner-main-app`。migration 失敗時 pipeline 失敗並保留現有 app revision；不在 app 容器啟動時執行 migration。必要 runtime secret 缺少時 deploy 必須失敗，不得 fallback 成 literal value。若已確認既有 Global Load Balancer 的驗證 URL，可設定 `DEPLOY_SMOKE_TEST_URL` 後由 `22` 執行 15 秒上限的 smoke test；未設定時不會自行發送請求。

`NEXT_PUBLIC_*` 是 build-time 設定，變更後必須重新建立 image；`APP_*` runtime 值由 Secret Manager 或 env metadata 注入 Cloud Run service/job。Cloud Build 使用受控 connection 與指定 service account，不建立 JSON key。

## 網路與出口

`12` 建立 `${PROJECT_NAME}-main-app-subnet`（`10.20.0.0/24`）。`13` 建立 `${PROJECT_NAME}-router`、`${PROJECT_NAME}-main-app-egress-ip` 與 `${PROJECT_NAME}-main-app-nat`，NAT 僅納管主系統 subnet 且使用手動固定 IP。需要向 Safeheron 登錄主系統出口時，執行：

```bash
bash 02_main-app/scripts/23_get-public-ip.sh
```

Co-Signer VM、MySQL、KMS、Pairing Token、`.env`、activation 與 callback test 不屬於本模組主流程。

## 清理

```bash
bash 02_main-app/scripts/99_remove-exec-iam-account-role.sh
```

此腳本只撤銷 `EXEC_IAM_ACCOUNT` 的自訂 role binding，不刪除 Cloud Build、GAR、Cloud SQL、Secret Manager、service account、trigger 或網路資源。不可用它替代正式資源刪除流程。

## 測試

測試使用 mock `gcloud`，不會建立 live GCP 資源：

```bash
bash -n 02_main-app/scripts/*.sh
bash 02_main-app/tests/cloudbuild-tests.sh
bash 02_main-app/tests/cloudsql-scripts.sh
bash 02_main-app/tests/deploy-tests.sh
bash 02_main-app/tests/secrets-tests.sh
```
