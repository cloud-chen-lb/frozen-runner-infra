# Safeheron Co-Signer

本模組使用 `global-env/env.sh` 的 active GCP project 與 region，建立共用
Cloud SQL、KMS keyring，以及每個商戶專屬的 KMS key、資料庫 user 和 Co-Signer VM。

## 執行前設定

確認 `global-env/env.sh` 至少包含：

```bash
PROJECT_NAME="frozen-runner"
GOOGLE_PROJECT_ID="your-gcp-project"
GOOGLE_PROJECT_REGION="asia-east1"
EXEC_IAM_ACCOUNT="your-account@example.com"
```

每個商戶需要建立 `scripts/env/env-merchant-<merchant>.sh`，例如：

```bash
VM_ZONE="asia-east1-a"
VM_MACHINE_TYPE="e2-medium"
VM_VPC_NETWORK="frozen-runner-cosigner-subnet"
```

`<merchant>` 必須是小寫英數字與連字號組成，且以小寫字母開頭，例如 `echox`。

## 建立流程

先由 `01_share-resources` 準備 shared VPC 與 Private Services Access，再執行本模組
的建立流程。以下資源只需執行一次：

```bash
bash 03_co-signer/scripts/01_setup-exec-iam-account-role.sh
bash 03_co-signer/scripts/02_create-cosigner-subnet.sh
bash 03_co-signer/scripts/03_create-mysql-instance.sh
bash 03_co-signer/scripts/04_create-cloud-kms-keyring.sh
```

接著將 `echox` 替換成實際商戶 slug，逐一執行：

```bash
bash 03_co-signer/scripts/05_create-merchant-cloud-kms.sh echox
bash 03_co-signer/scripts/06_create-mysql-database-user.sh echox
bash 03_co-signer/scripts/07_print-merchant-co-signer-env.sh echox \
  > 03_co-signer/co-signer.env
bash 03_co-signer/scripts/08_create-vm.sh echox
```

`06_create-mysql-database-user.sh` 建立資料庫與 user。若 user 尚未存在，
腳本會從終端機或 stdin 讀取 MySQL password，不會將 password 寫入 Git。

`07_print-merchant-co-signer-env.sh` 會輸出完整的 `co-signer.env` 格式，
自動填入 Cloud SQL private IP、資料庫名稱、user、GCP project、region 與商戶 KMS key。
輸出中的 `PAIRING_TOKEN` 與 `MYSQL_PASSWORD` 會保留佔位符，請手動填入：

```bash
PAIRING_TOKEN="{PAIRING-TOKEN}"
MYSQL_PASSWORD="{MYSQL-PASSWORD}"
```

`08_create-vm.sh` 建立商戶專屬 VM 與 reserved static IP。VM 建立完成後，
可使用該 static public IP 設定 Safeheron 的 IP allowlist。

## 安全注意事項

- `co-signer.env` 是本機產生的 runtime 設定，已加入 `.gitignore`，不可提交。
- Pairing token、MySQL password、private key 與 service-account JSON 不得放入 Git。
- 執行前確認 `global-env/env.sh` 指向正確的 GCP project。
- `scripts/env/env.sh` 與 `scripts/env/env-merchant-<merchant>.sh` 只放非機密資源設定。

## 本地驗證

```bash
bash 03_co-signer/tests/scripts.sh
bash -n 03_co-signer/scripts/*.sh 03_co-signer/tests/scripts.sh
git diff --check
```
