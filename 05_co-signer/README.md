

需要提供客戶資訊

- API Public Key 
- frozen runner 服務的固定ip位址
- Co-Signer Public Key
- Co-Signer 的固定ip位址
- Co-Signer Callback URL

1. 先去 frozen-alert 開一組新的商戶 (需要frozen-runner服務對外固定ip 和 hook網址)
2. 去 frozen-runner 建立商戶 並連結到 frozen-alert


# Safeheron co-Signer 安裝

本目錄使用 repo 共用的 `global-env/env.sh`。執行 Co-Signer 建置腳本前，先確認
其中的 `PROJECT_NAME`、`GOOGLE_PROJECT_ID` 與 `GOOGLE_PROJECT_REGION` 已指向
目前要操作的 GCP project；腳本不再接受 `dev` 或 `prod` 參數。

依序執行：

```bash
bash 05_co-signer/scripts/01_setup-exec-iam-account-role.sh
bash 05_co-signer/scripts/02_create-cloud-kms.sh
bash 05_co-signer/scripts/03_create-vm.sh
```

先完成 network 與共用 MySQL instance，再以 `--merchant-slug` 建立商戶 database/user，最後建立該商戶 VM。

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
ip白名單: scripts/scripts/03_create-vm.sh 建立完成以後的 public ip
callback
  - URL: {BASE_URL}/api/safeheron/05_co-signer/callback
  - 公鑰: 貼入上面生成的公鑰



sudo ./cosigner start --enable-mysql --config-file=/home/leadbest/safeheron/.env
