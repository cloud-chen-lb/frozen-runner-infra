# frozen-runner-infra

這個 repo 是 `frozen-runner` 的 GCP infrastructure scripts repository，主要根據
[frozen-runner/cicd/prod/README.md](https://github.com/echox-project/frozen-runner/blob/main/cicd/prod/README.md)
建立與管理 GCP 資源和服務。

## 架構

```text
frozen-runner-infra/
├── global-env/                  # 共用 GCP project 與 region 設定
│   └── env.sh                   # 目前 active environment 設定
├── cloudbuild/                  # Cloud Build pipeline 基礎建設
│   ├── base/                    # API、IAM、GitHub connection/repository
│   │   ├── scripts/
│   │   │   ├── env/env.sh       # Cloud Build 專用 metadata
│   │   │   ├── 00_env.sh        # 載入共用與專用設定
│   │   │   ├── 01_setup-exec-iam-account-role.sh
│   │   │   ├── 01_enable-apis.sh
│   │   │   ├── 02_setup-cloud-build-iam.sh
│   │   │   └── 03_setup-github-connection.sh
│   │   └── README.md
│   ├── build-image/             # GAR 與 image build triggers
│   │   ├── scripts/
│   │   │   ├── 00_create-ci-trigger.sh
│   │   │   ├── 01_create-artifact-registry.sh
│   │   │   ├── 02_create-release-trigger.sh
│   │   │   ├── 03_run-release-trigger.sh
│   │   │   ├── 04_verify-images.sh
│   │   │   ├── 05_create-manual-release-trigger.sh
│   │   │   └── 06_run-manual-release-trigger.sh
│   │   ├── tests/scripts.sh
│   │   └── README.md
│   └── deploy/                  # 未來放 Cloud Run deploy scripts
├── co-signer/                  # Safeheron Co-Signer VM、KMS 與 IAM
│   ├── scripts/
│   │   ├── 00_env.sh           # 載入共用 active environment
│   │   ├── 01_setup-exec-iam-account-role.sh
│   │   ├── 02_create-cloud-kms.sh
│   │   └── 03_create-vm.sh
│   └── README.md
└── README.md                   # Repo 架構與使用說明
```

### 共用環境設定

所有 infrastructure scripts 使用單一 active 設定檔：

```text
global-env/env.sh
```

至少需要設定：

```bash
PROJECT_NAME="frozen-runner"
GOOGLE_PROJECT_ID="YOUR_GCP_PROJECT_ID"
GOOGLE_PROJECT_REGION="YOUR_GCP_REGION"
```

切換 dev 或 prod 時，直接修改這份檔案中的 project 設定；scripts 不接受
`dev|prod` 參數。Cloud Build 專用的 connection/repository metadata 則放在：

```text
cloudbuild/base/scripts/env/env.sh
```

### Cloud Build

先閱讀 [`cloudbuild/base/README.md`](cloudbuild/base/README.md)，建立必要 API、
Cloud Build service account 與 GitHub connection/repository metadata。再閱讀
[`cloudbuild/build-image/README.md`](cloudbuild/build-image/README.md)，建立 GAR、
CI trigger、automatic `v*` release trigger，或手動指定如 `v0.1.0-pre` 的 image build
trigger。CI trigger 可用以下命令建立或確認：

```bash
bash cloudbuild/build-image/scripts/00_create-ci-trigger.sh
```

Cloud Build image pipeline 只負責建立與 push app/migration image，不負責 Cloud Run
deploy、database migration 或 Co-Signer VM activation。

### Co-Signer

`co-signer/` 依 Safeheron 官方流程建立每個 Co-Signer 所需的 IAM、KMS 與 VM。執行
方式請看 [`co-signer/README.md`](co-signer/README.md)。Pairing Token、`.env`、
Safeheron activation 與 start/setup 不會寫入 Git 或由 Cloud Build 管理。

## 安全邊界

- 不將 secret、Pairing Token、`.env` 或 service-account JSON key 寫入 repo。
- Runtime service account 與 Cloud Build service account 分開管理。
- GCP 資源建立前，確認 `global-env/env.sh` 指向正確 project，避免誤操作其他環境。
