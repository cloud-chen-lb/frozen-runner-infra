# Safeheron co-singer 安裝

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
  - URL: {BASE_URL}/api/safeheron/co-signer/callback
  - 公鑰: 貼入上面生成的公鑰



sudo ./cosigner start --enable-mysql --config-file=/home/leadbest/safeheron/.env