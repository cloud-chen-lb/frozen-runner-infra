# Main App

本 module 建立 Cloud Run runtime/deploy service accounts 與 Secret Manager
metadata/access bindings。GCP target 來自 `global-env/env.sh` 的
`GOOGLE_PROJECT_ID`；`PROJECT_NAME` 只用於命名。

## 設定

共用非機密必填值：`PROJECT_NAME`、`GOOGLE_PROJECT_ID`、
`GOOGLE_PROJECT_REGION`、`EXEC_IAM_ACCOUNT`。`scripts/env/env.sh` 必填：

- `APP_SECRET_MAPPING`
- `MIGRATION_SECRET_MAPPING`
- `APP_SERVICE_ACCOUNT_NAME`
- `MIGRATION_SERVICE_ACCOUNT_NAME`
- `DEPLOY_SERVICE_ACCOUNT_NAME`

mapping 只有 `ENV_KEY=secret-name:version` metadata，不是 secret value。
Secret name/version 與 service-account ID 由 loader 驗證。
`APP_SECRET_MAPPING` 與 `MIGRATION_SECRET_MAPPING` 的 entries 完全由
`scripts/env/env.sh` 的 mapping 定義；setup script 不維護另一份 key whitelist。
其餘 runtime env 由 deploy pipeline 的 `APP_RUNTIME_ENV_VARS` 注入。
`MIGRATION_SECRET_MAPPING` 只使用 `APP_DATABASE_URL`，並指向不同於 app 的
`${PROJECT_NAME}-migration-database-url` secret。兩個 database URL secret 的
versions/values 由操作者依兩個 PostgreSQL users 手動建立，不由這些 scripts 讀寫。

## 建立

在 network、Cloud SQL 完成後，由 repo root 依序執行：

```bash
bash 04_secrets/scripts/01_setup-exec-iam-account-role.sh
bash 04_secrets/scripts/02_setup-service-accounts.sh
bash 04_secrets/scripts/03_setup-secrets.sh
```

`03_setup-secrets.sh` 只建立 Secret Manager secret metadata 與 scoped
`roles/secretmanager.secretAccessor` bindings。secret versions/values 必須
透過核准的 Secret Manager 流程另行寫入，不由本 repo、Cloud Build
substitution 或 deployment script 傳入。

未來新增 secret 時，只需更新 infra repo 的 `scripts/env/env.sh` mapping
並重新執行 setup。由於 deploy source repo 不讀取 infra repo，
`cloudbuild-deploy.yaml` 也必須同步新增對應的 mapping/runtime injection。

## 撤銷

```bash
bash 04_secrets/scripts/99_remove-exec-iam-account-role.sh
```

這只撤銷 `SecretManagerProvisioningOperator` 的執行者 binding，不移除 runtime、
migration、deploy service accounts 或它們的 runtime bindings。
