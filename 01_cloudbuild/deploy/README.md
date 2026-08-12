# Production Deploy

本 module 負責 production deploy IAM、manual production trigger，以及觸發
既有 Cloud Build deploy pipeline。它不建立 image，也不直接執行 Cloud Run
provisioning。GCP target 為 `global-env/env.sh` 的 `GOOGLE_PROJECT_ID`。

## 設定

共用非機密必填值：`PROJECT_NAME`、`GOOGLE_PROJECT_ID`、
`GOOGLE_PROJECT_REGION`、`EXEC_IAM_ACCOUNT`。`scripts/env/env.sh` 必填：

- `CLOUD_BUILD_SOURCE_BRANCH`
- `APP_VPC_ARGS`
- `MIGRATION_VPC_ARGS`
- `APP_SECRET_MAPPING`
- `MIGRATION_SECRET_MAPPING`
- `APP_RUNTIME_ENV_VARS`
- `MIGRATION_RUNTIME_ENV_VARS`
- `APP_MIN_INSTANCE`, `APP_MAX_INSTANCE`, `APP_CPU`, `APP_MEMORY`, `APP_TIMEOUT`, `APP_CONCURRENCY` (optional; empty uses source YAML/Cloud Run defaults)
- `PRODUCTION_TRIGGER_NAME`
- `PRODUCTION_APP_NAME`
- `PRODUCTION_MIGRATION_JOB_NAME`

`DEPLOY_SMOKE_TEST_URL` 可留空；只有明確設定既有驗證 URL 才會做
smoke test。資源 overrides 留空時由 source repo 的
`cicd/prod/cloudbuild-deploy.yaml` 決定 defaults，
不從 main-app env 載入。mapping 只含 Secret Manager metadata，不含 secret value。

## 建立與執行

在 network、Cloud SQL、main-app 完成後，由 repo root 執行：

```bash
bash 01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh
bash 01_cloudbuild/deploy/scripts/02_setup-deploy-iam.sh
bash 01_cloudbuild/deploy/scripts/03_create-production-trigger.sh
bash 01_cloudbuild/deploy/scripts/04_run-production-deploy.sh v<release>
bash 01_cloudbuild/deploy/scripts/05_verify-deployment.sh v<release>
```

`04_run-production-deploy.sh` 接受 `v` 開頭的 release tag，並可用環境變數或
`--_IMAGE_TAG=...`、`--_APP_RUNTIME_ENV_VARS=...` 等 arguments override
substitutions。`APP_SECRET_MAPPING` 與 `MIGRATION_SECRET_MAPPING` 只能 override
Secret Manager metadata references，格式為 `KEY=secret-name:version`，不可放入
secret literal/value；APP 只允許目前五個 secret keys，migration 只允許
`APP_DATABASE_URL`。runtime env override 也不可包含 newline 或 semicolon。pipeline 順序是 migration deploy、
migration execute/wait、再 app deploy。secret/password 只透過 Secret
Manager metadata/reference 邊界處理，不放入 repo、argv 或 substitutions。

## 撤銷

```bash
bash 01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh
```

這只撤銷 `CloudBuildDeployProvisioningOperator` 的執行者 binding，不刪除
trigger、deploy service account 或 runtime bindings。
