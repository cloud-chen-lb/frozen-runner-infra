

需要提供客戶資訊

- API Public Key 
- frozen runner 服務的固定ip位址
- Co-Signer Public Key
- Co-Signer 的固定ip位址
- Co-Signer Callback URL

1. 先去 frozen-alert 開一組新的商戶 (需要frozen-runner服務對外固定ip 和 hook網址)
2. 去 frozen-runner 建立商戶 並連結到 frozen-alert


# Safeheron co-Signer 安裝

本目錄使用 repo 共用的 `global-env/env.sh`。執行腳本前，先確認
`PROJECT_NAME`、`GOOGLE_PROJECT_ID` 與 `GOOGLE_PROJECT_REGION` 已指向目前的 GCP project。
每個商戶都必須有 `scripts/env/env-merchant-<merchant>.sh`；檔案可使用 shell 變數，但只放非機密資源設定。
Pairing token、MySQL 密碼與其他 secret 不得放入 Git。

先完成 `01_share-resources` 的 VPC、主系統 subnet、Co-Signer subnet 與 Private Services Access，再建立本 module 的共用資源，最後逐一建立商戶資源：

```bash
# 共用網路（只需執行一次）
bash 01_share-resources/scripts/01_setup-exec-iam-account-role.sh
bash 01_share-resources/scripts/02_enable-apis.sh
bash 01_share-resources/scripts/03_create-vpc.sh
bash 01_share-resources/scripts/04_create-main-app-subnet.sh
bash 01_share-resources/scripts/05_create-cosigner-subnet.sh
bash 01_share-resources/scripts/05_create-private-services-access.sh

# Co-Signer 共用資源（只需執行一次）
bash 03_co-signer/scripts/01_setup-exec-iam-account-role.sh
bash 03_co-signer/scripts/02_create-mysql-instance.sh
bash 03_co-signer/scripts/03_create-cloud-kms-keyring.sh

# 將 acme 替換成 scripts/env/env-merchant-<merchant>.sh 的 merchant slug
bash 03_co-signer/scripts/04_create-merchant-cloud-kms.sh acme
bash 03_co-signer/scripts/05_create-mysql-database-user.sh acme
bash 03_co-signer/scripts/06_create-vm.sh acme
```

`02_create-mysql-instance.sh` 與 `03_create-cloud-kms-keyring.sh` 只需執行一次。
商戶流程建立該商戶專屬的 KMS key、service account、database/user、VM 與 reserved static IP。

## 產生 API Key

```sh
# 產生私鑰
openssl genpkey -out api_private.pem -algorithm RSA -pkeyopt rsa_keygen_bits:4096

# 從私鑰產生公鑰
openssl rsa -in api_private.pem -out api_public.pem -pubout
```

01 ~ 03

產生 callback key

```sh
# 產生私鑰
openssl genpkey -out callback_handler_private.pem -algorithm RSA -pkeyopt rsa_keygen_bits:4096

# 從私鑰產生公鑰
openssl rsa -in callback_handler_private.pem -out callback_handler_public.pem -pubout
```

到 Safeheron 申請API Key

增加API Key

部署 API Co-Signer
名稱: frozen-runner-co-signer-api
ip白名單: `06_create-vm.sh` 建立完成以後的 public ip
callback
  - URL: {BASE_URL}/api/safeheron/03_co-signer/callback
  - 公鑰: 貼入上面生成的公鑰



sudo ./cosigner start --enable-mysql --config-file=/home/leadbest/safeheron/.env
