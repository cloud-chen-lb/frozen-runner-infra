# Cloud SQL

本 module 建立主系統使用的 private PostgreSQL instance、database 與兩個
database users。GCP target 永遠是 `global-env/env.sh` 的
`GOOGLE_PROJECT_ID`；`PROJECT_NAME` 僅用於 resource naming。

## 設定

共用且非機密的必填值為 `global-env/env.sh` 的
`PROJECT_NAME`、`GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION`、
`EXEC_IAM_ACCOUNT`。`scripts/env/env.sh` 必填非機密值為：

- `POSTGRES_DATABASE_NAME`
- `POSTGRES_APP_USER`
- `POSTGRES_MIGRATION_USER`
- `POSTGRES_VERSION`
- `POSTGRES_TIER`
- `POSTGRES_STORAGE_GB`

`POSTGRES_NETWORK_NAME` 與 `POSTGRES_INSTANCE_NAME` 由
`PROJECT_NAME` 組成。密碼不放在 env 檔或 command substitution。

## 建立

在 network 完成後，由 repo root 依序執行：

```bash
bash 03_cloudsql/scripts/01_setup-exec-iam-account-role.sh
bash 03_cloudsql/scripts/02_create-postgres-instance.sh
bash 03_cloudsql/scripts/03_create-postgres-database-users.sh
bash 03_cloudsql/scripts/02_create-mysql-instance.sh
```

每個商戶在建立 VM 前建立自己的 MySQL database/user：

```bash
printf '%s\n' '<PASSWORD>' | bash 03_cloudsql/scripts/03_create-mysql-database-user.sh --merchant-slug=merchant-a
```

建立完成後，可查詢 private IP 並輸出不含真實密碼的 connection strings：

```bash
bash 03_cloudsql/scripts/04_print-connection-strings.sh
```

輸出中的 `<PASSWORD>` 只是假值；請使用安全的外部 secret 注入方式替換，勿將真實密碼寫入 repo 或 log。

第三支 script 建立 users 時，密碼只能由 stdin 或已核准的 Secret Manager
version reference 取得。互動輸入：

```bash
bash 03_cloudsql/scripts/03_create-postgres-database-users.sh
```

非互動執行可使用完整格式的 Secret Manager reference，例如
`--app-password-secret-version=projects/PROJECT/secrets/NAME/versions/VERSION`，
以及對應的 `--migration-password-secret-version`。不要把密碼放進 argv、
repo、substitution 或 log。

## 撤銷

```bash
bash 03_cloudsql/scripts/99_remove-exec-iam-account-role.sh
```

這只撤銷 `CloudSQLProvisioningOperator` 的執行者 binding，不刪除 instance、
database、users、secrets 或 runtime identities。
