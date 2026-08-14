# Network

本 module 建立主系統使用的 VPC、Private Services Access、Cloud
Router 與 Cloud NAT。所有指令都以 `global-env/env.sh` 的
`GOOGLE_PROJECT_ID` 為 GCP project target；`PROJECT_NAME` 只用於 resource
naming。

## 設定

先確認 repo root 的 `global-env/env.sh` 已設定非機密的
`PROJECT_NAME`、`GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION`、
`EXEC_IAM_ACCOUNT`。再確認 `scripts/env/env.sh` 的非機密設定：

- `PRIVATE_SERVICES_RANGE_CIDR`
- 其餘 `*_NAME` 由 `PROJECT_NAME` 組成，不要改成另一個 project 的名稱。

## 建立

由 repo root 依序執行。每支 script 都會先載入並驗證 env：

```bash
bash 01_share-resources/scripts/01_setup-exec-iam-account-role.sh
bash 01_share-resources/scripts/02_enable-apis.sh
bash 01_share-resources/scripts/03_create-vpc.sh
bash 01_share-resources/scripts/04_create-private-services-access.sh
bash 02_main-app/scripts/13_create-router-nat.sh
```

這些 scripts 會檢查既有資源契約與 drift；不符合時停止，不會直接覆寫。

## 撤銷

完成所有需要 network 權限的操作後，撤銷本 module 給執行者的 custom role：

```bash
bash 01_share-resources/scripts/99_remove-exec-iam-account-role.sh
```

此 script 只移除 `NetworkProvisioningOperator` 對
`EXEC_IAM_ACCOUNT` 的 project binding，不移除 VPC、subnet、NAT 或 runtime
service account。
