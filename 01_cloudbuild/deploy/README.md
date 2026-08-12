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
- `PRODUCTION_TRIGGER_NAME`
- `PRODUCTION_APP_NAME`
- `PRODUCTION_MIGRATION_JOB_NAME`

`DEPLOY_SMOKE_TEST_URL` 可留空；只有明確設定既有 Load Balancer URL 才會做
smoke test。deploy script 另載入 `04_main-app/scripts/env/env.sh` 的 secret
mapping metadata。

## 建立與執行

在 network、Cloud SQL、main-app 完成後，由 repo root 執行：

```bash
bash 01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh
bash 01_cloudbuild/deploy/scripts/02_setup-deploy-iam.sh
bash 01_cloudbuild/deploy/scripts/03_create-production-trigger.sh
bash 01_cloudbuild/deploy/scripts/04_run-production-deploy.sh v<release>
bash 01_cloudbuild/deploy/scripts/05_verify-deployment.sh v<release>
```

`04_run-production-deploy.sh` 只接受 `v` 開頭的 release tag，並觸發
`cicd/prod/cloudbuild-deploy.yaml`；pipeline 順序是 migration deploy、
migration execute/wait、再 app deploy。secret/password 只透過 Secret
Manager metadata/reference 邊界處理，不放入 repo、argv 或 substitutions。

## 撤銷

```bash
bash 01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh
```

這只撤銷 `CloudBuildDeployProvisioningOperator` 的執行者 binding，不刪除
trigger、deploy service account 或 runtime bindings。
