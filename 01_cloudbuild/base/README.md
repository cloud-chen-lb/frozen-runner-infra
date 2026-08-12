# Cloud Build Base

這裡負責建立 Cloud Build image pipeline 使用的基礎資源，不包含 GAR image、release trigger 或 Cloud Run deploy。

## 建立順序

所有腳本都使用目前的 `global-env/env.sh`，不接受環境參數。

切換 dev 或 prod 時，直接修改 `global-env/env.sh` 內的 project 設定即可：

```bash
PROJECT_NAME="frozen-runner"
GOOGLE_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GOOGLE_PROJECT_REGION="YOUR_CLOUD_BUILD_REGION"
```

### 1. 載入環境與建立執行人 role

`00_env.sh` 由其他腳本載入目前的共用與 Cloud Build 專用設定；接著先建立執行人
IAM role：

```bash
bash 01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh
```

### 2. 啟用 API

腳本會先檢查 API 是否已啟用，只有尚未啟用的 API 才會執行 enable：

```bash
bash 01_cloudbuild/base/scripts/02_enable-apis.sh
```

### 3. 建立 Cloud Build service account

建立 `cb-share-build`，並授予 Artifact Registry push、Cloud Build 與 Logging 所需權限：

```bash
bash 01_cloudbuild/base/scripts/03_setup-cloud-build-iam.sh
```

### 4. 建立 GitHub connection 與 repository

這一步需要 Cloud Build GitHub App 的互動式 OAuth / installation。若由其他負責人建立，可略過；未來自行負責時執行：

```bash
bash 01_cloudbuild/base/scripts/04_setup-github-connection.sh \
  CONNECTION_NAME \
  REPOSITORY_NAME \
  https://github.com/GITHUB_OWNER/GITHUB_REPOSITORY.git
```

腳本會：

- 建立或確認 Cloud Build GitHub connection。
- 建立或確認 Cloud Build repository。
- 如果既有 repository 的 remote URI 不一致，停止並提示修正，不會自動刪除或覆蓋。
- 最後輸出需要回填的 connection/repository 名稱。

## 回填環境設定

建立 Cloud Build connection/repository 完成後，將輸出的值填入對應環境檔：

```text
01_cloudbuild/base/scripts/env/env.sh
```

例如：

```bash
CLOUD_BUILD_CONNECTION_NAME="my-github-connection"
CLOUD_BUILD_REPOSITORY_NAME="frozen-runner-repository"
```

建立 connection/repository 後，將名稱填入 `01_cloudbuild/base/scripts/env/env.sh`。不要填入完整的 `projects/...` resource path；`build-image` 腳本會依據 `GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION` 與這兩個名稱自動組合完整路徑。

完成回填後，才能執行：

```bash
bash 01_cloudbuild/build-image/scripts/01_create-artifact-registry.sh
bash 01_cloudbuild/build-image/scripts/02_create-release-trigger.sh
```

## 撤銷

```bash
bash 01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh
```

這只撤銷 `CloudBuildSetupOperator` 對 `EXEC_IAM_ACCOUNT` 的 project binding，不刪除
Cloud Build service account、connection、repository 或其他人員的 roles。

## 注意事項

- `global-env/env.sh` 必須先設定 `PROJECT_NAME`、`GOOGLE_PROJECT_ID`、`GOOGLE_PROJECT_REGION`。
- `01_cloudbuild/base/scripts/env/env.sh` 只放 Cloud Build connection/repository metadata。
- 不要把 GitHub token、service-account JSON key 或其他 secret 寫入 env 檔案。
- `04_setup-github-connection.sh` 只處理 connection/repository，不會自動回填 env，避免覆蓋人工設定。
