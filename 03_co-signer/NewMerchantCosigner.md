# 建立新Merchant流程

## 設定 FrozenAlert

1. 到 frozen-runner 建立新商戶 取得 <merchant-id>
* 注意 <merchant-id> 不是商戶代碼 進入編輯商戶 複製網址列的 merchant-id 會以 `merchant-` 開頭

2. 請 frozen-alert 開一組新的商戶，提供

- frozen runner 服務的固定ip位址

正式站固定 `34.80.1.28`

- hook url

https://frozen-runner.echox.io/api/alerts/frozenalert/watchlist/<merchant-id>

3. 取得 API Key 和 Hook Secret 後 編輯商戶 FrozenAlert 資訊並測試

## 建立和準備 Co-Signer

1. 建立 `scripts/env/env-merchant-<merchant>.sh`，例如：

```bash
# echox 商戶 Co-Signer VM 的非機密設定；由建立 VM 與 KMS key 的腳本載入。
# VM_ZONE 是 VM 所在的 Compute Engine zone；格式為 zone 名稱，必須與 GOOGLE_PROJECT_REGION 同區域，例如 asia-east1-a。
VM_ZONE="asia-east1-a"
# VM_MACHINE_TYPE 是 VM 機器類型；格式為 Compute Engine machine type 名稱，例如 e2-medium。
VM_MACHINE_TYPE="e2-medium"
# VM_VPC_NETWORK 是 VM 使用的 subnet 名稱；格式為 GCP subnet 資源名稱，應填該商戶 Co-Signer subnet。
VM_VPC_NETWORK="${PROJECT_NAME}-cosigner-subnet"
# VM_SSH_SOURCE_CIDR 限制可以連線到 VM 的來源 IP 範圍；格式為 CIDR
VM_SSH_SOURCE_CIDR="122.116.23.174/32"
```

2. 建立 co-signer 環境

```sh
# 建立KMS
./03_co-signer/scripts/05_create-merchant-cloud-kms.sh <merchant>

# 建立MySQL資料庫使用者，執行以後會問 mysql 使用者密碼
./03_co-signer/scripts/06_create-mysql-database-user.sh <merchant>

# 建立VM
./03_co-signer/scripts/08_create-vm.sh <merchant>

# 將本機的 ssh key 放到 VM 上，用於安裝 co-signer
./03_co-signer/scripts/09_add-vm-ssh-key.sh <merchant>
```

3. 安裝 co-signer

登入 [safeheron console](https://console.safeheron.com/application/api-cosigner)

去GCE看 剛剛建立的VM ip
然後 ssh 進去該VM

`遠端`

```sh
# 這邊的username是本機的 .ssh/id_rsa.pub 出來的 09_add-vm-ssh-key.sh 會把此公鑰上傳到VM上
ssh <username>@<vm ip>

# 建立目錄
mkdir -p ~/safeheron && cd ~/safeheron

# 下載 co-signer，連結在 https://console.safeheron.com/application/api-cosigner 替換掉 {URL}
curl -fo cosigner "{URL}"

# 增加co-signer執行權限
chmod +x cosigner

# 安裝環境
sudo ./cosigner setup
```

先到這邊為主，接下來整理要給對方設定Safeheron的值

** 記得要設定 新co-signer新的ip到逃跑的負載平衡白名單

## 整理要給對方的值

需要:

- API Public Key

```sh
# 產生私鑰
openssl genpkey -out api_private.pem -algorithm RSA -pkeyopt rsa_keygen_bits:4096

# 從私鑰產生公鑰
openssl rsa -in api_private.pem -out api_public.pem -pubout

# 顯示公鑰
cat ./api_public.pem
```

- frozen runner 服務的固定ip位址

正式站固定 `34.80.1.28`

- Co-Signer Public Key

```sh
# 產生私鑰
openssl genpkey -out callback_handler_private.pem -algorithm RSA -pkeyopt rsa_keygen_bits:4096

# 從私鑰產生公鑰
openssl rsa -in callback_handler_private.pem -out callback_handler_public.pem -pubout

# 顯示公鑰
cat ./callback_handler_public.pem
```

- Co-Signer 的固定ip位址

提供 `08_create-vm.sh` 建立的VM IP

- Co-Signer Callback URL

根據一開始獲得的 <merchant-id> 組合成 callback
https://frozen-runner.echox.io/api/safeheron/co-signer/callback/<merchant-id>

## 等待對方提供後 (未完善)

1. 啟動 co-signer

用 script 取得設定檔案

`本地`

```sh
./03_co-signer/scripts/07_print-merchant-co-signer-env.sh <merchant>
```

將 {MYSQL-PASSWORD} 換成 06_create-mysql-database-user.sh 中使用的 MySQL 使用者密碼

`遠端`

```sh
# 建立設定檔案
nano .env
```

```sh
# 取得激活碼
sudo ./cosigner view-activation-code

# 取得簽署公鑰
sudo ./cosigner export-public-key
```

2. 去 frozen-runner 設定商戶 Safeheron 
