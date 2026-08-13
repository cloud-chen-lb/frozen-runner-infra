
# Cloud Build Image

這裡負責建立並執行 CI 與 release image build pipeline：

1. 建立 Artifact Registry Docker repository。
2. 建立從 Cloud Build repository 讀取 source 的 CI 與 release trigger。
3. 使用 Git tag 自動觸發，或手動指定 release tag，建立並 push app/migration image。
4. 驗證兩個 image 是否已經存在於 GAR。

這裡不負責建立 GitHub connection、Cloud Build repository 或 Cloud Run deploy。

## 前置條件

### 1. 安裝並登入 gcloud

```bash
gcloud auth login
gcloud auth application-default login
```

執行者需要有建立 GAR、Cloud Build trigger、IAM 綁定與執行 build 的權限。

### 2. 完成 base 資源

先依照 [`../base/README.md`](../base/README.md) 完成：

- 必要 API 啟用。
- `cb-share-build` service account 與 IAM。
- Cloud Build GitHub connection/repository。

若 connection/repository 是由其他負責人建立，至少要取得以下兩個名稱：

```text
CLOUD_BUILD_CONNECTION_NAME
CLOUD_BUILD_REPOSITORY_NAME
```

### 3. 設定環境檔

確認目前環境檔已填入 project 設定：

```text
global-env/env.sh
```

至少需要：

```bash
PROJECT_NAME="frozen-runner"
GOOGLE_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GOOGLE_PROJECT_REGION="YOUR_CLOUD_BUILD_REGION"
```

再將 Cloud Build connection/repository 名稱填入 Cloud Build 專用環境檔：

```text
02_main-app/scripts/env/env.sh
```

例如：

```bash
CLOUD_BUILD_CONNECTION_NAME="my-github-connection"
CLOUD_BUILD_REPOSITORY_NAME="frozen-runner-source"
```

只填名稱，不要填完整的 `projects/...` resource path。腳本會依 project、region 與名稱自動組合完整路徑。

切換 dev 或 prod 時，直接修改 `global-env/env.sh` 的 project 設定；Cloud Build connection/repository 則維持在 `02_main-app/scripts/env/env.sh`。

## 執行流程

以下指令不需要傳入環境參數；執行前請確認 `global-env/env.sh` 指向正確的 project。

### 1. 建立或確認 GAR

```bash
bash 02_main-app/scripts/06_create-artifact-registry.sh
```

腳本會建立或確認：

```text
${GOOGLE_PROJECT_REGION}-docker.pkg.dev/${GOOGLE_PROJECT_ID}/${PROJECT_NAME}-container-repository
```

### 2. 建立或確認 CI trigger

CI trigger 由 Pull Request 觸發，預設只接受 target branch `master`：

```bash
bash 02_main-app/scripts/05_create-ci-trigger.sh
```

trigger 會使用 `cb-share-build` service account、Cloud Build v2 repository resource
與 `cicd/prod/cloudbuild-ci.yaml`。若同名 trigger 已存在，腳本會檢查 repository、PR
pattern、build config、service account 與 region；設定不一致時會停止並回報 drift。

### 3. 建立或確認 release trigger

```bash
bash 02_main-app/scripts/07_create-release-trigger.sh
```

trigger 設定如下：

- Trigger name：`${PROJECT_NAME}-release-build-trigger`
- Tag pattern：`^v.*$`
- Build config：`cicd/prod/cloudbuild-release.yaml`
- Service account：`cb-share-build`
- Source：已設定的 Cloud Build repository
- Images：`${PROJECT_NAME}-app`、`${PROJECT_NAME}-migration`

如果同名 trigger 已存在，腳本會檢查 repository、tag pattern、build config、service account 與 substitutions。設定不一致時會停止並回報 drift，不會自動覆蓋既有 trigger。

### 4. 觸發 image build

automatic release trigger 的 tag 必須符合 `v*`，例如：

```bash
git tag v1.2.3
git push origin v1.2.3
```

也可以手動執行既有的 automatic trigger。這仍然使用 Git tag 事件：

```bash
bash 02_main-app/scripts/08_run-release-trigger.sh v1.2.3
```

Cloud Build 會依 source repository 的 `cicd/prod/cloudbuild-release.yaml` 建立並 push：

```text
${REGION}-docker.pkg.dev/${PROJECT_ID}/${PROJECT_NAME}-container-repository/${PROJECT_NAME}-app:v1.2.3
${REGION}-docker.pkg.dev/${PROJECT_ID}/${PROJECT_NAME}-container-repository/${PROJECT_NAME}-migration:v1.2.3
```

### 5. 建立純手動 release trigger

純手動 trigger 使用同一個 Cloud Build repository、CI service account、GAR repository/image names 與 `cicd/prod/cloudbuild-release.yaml`，但不會因為 Git tag 自動執行：

```bash
bash 02_main-app/scripts/10_create-manual-release-trigger.sh
```

預設 source branch 是 `master`。如需其他 branch，建立與執行時都可用不含 secret 的環境變數設定：

```bash
CLOUD_BUILD_SOURCE_BRANCH=release bash 02_main-app/scripts/10_create-manual-release-trigger.sh
```

### 6. 執行純手動 release trigger

手動 release tag 必須符合 `v<release>`，例如 `v0.1.0-pre`：

```bash
bash 02_main-app/scripts/11_run-manual-release-trigger.sh v0.1.0-pre master
```

這會將指定 branch 與 tag 傳入 trigger，並將 tag 傳入 `_IMAGE_TAG`。build config 有 `_IMAGE_TAG` 時使用它，否則 automatic `v*` trigger 使用 Cloud Build 的 `TAG_NAME`。

### 7. 驗證 image

確認 Cloud Build 完成後執行：

```bash
bash 02_main-app/scripts/09_verify-images.sh v0.1.0-pre
```

兩個 image 都成功輸出 digest 才代表 image 已存在於 GAR。

## 本地腳本檢查

此目錄目前沒有 dedicated local test script；可檢查所有 shell script 語法：

```bash
bash -n 02_main-app/scripts/*.sh 02_main-app/scripts/*.sh
```

## 注意事項

- 不要將 GitHub token、service-account JSON key 或任何 secret 寫入環境檔或 substitutions。
- `05_create-ci-trigger.sh` 只建立或確認 CI trigger；預設 PR target branch 是 `master`，可用 `CLOUD_BUILD_SOURCE_BRANCH` 覆寫。
- `08_run-release-trigger.sh` 只會觸發既有 automatic trigger，不會建立 trigger；首次使用前必須先執行 `05`、`06` 與 `07`。
- `10_create-manual-release-trigger.sh` 只建立純手動 trigger；`11_run-manual-release-trigger.sh` 只執行既有的純手動 trigger。
- 此流程只建立 image，不會執行 migration，也不會部署 Cloud Run。
