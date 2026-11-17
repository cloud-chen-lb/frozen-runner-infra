# Co-Signer KMS Keyring 腳本診斷提示設計

## 目標

讓執行 `03_co-signer/scripts/04_create-cloud-kms-keyring.sh` 的人能看出目前正在查詢或建立 KMS keyring，且不再隱藏查詢失敗原因。

## 設計

- 執行查詢前輸出查詢中的 keyring、專案與位置。
- 查詢成功時輸出 keyring 已存在，不執行建立。
- 僅在錯誤明確表示指定 keyring 不存在時，輸出建立提示並建立 keyring。
- 其他查詢錯誤原樣輸出並以非零狀態結束，避免權限、網路或 API 錯誤被誤當成資源不存在。
- 不新增逾時或外部工具相依；若 gcloud 呼叫本身持續等待，狀態提示可指出目前停留的階段，但不會中斷呼叫。

## 驗證

- 以模擬 gcloud 的測試涵蓋 keyring 已存在、不存在需建立、以及其他錯誤中止。
- 執行 Co-Signer 腳本測試；若整體測試受既有環境差異阻擋，另行執行此腳本的對應測試。
