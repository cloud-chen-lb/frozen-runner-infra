# frozen-runner-infra

這個 repo 是 `frozen-runner` 的 GCP infrastructure scripts repository，主要根據
[frozen-runner/cicd/prod/README.md](https://github.com/echox-project/frozen-runner/blob/main/cicd/prod/README.md)
建立與管理 GCP 資源和服務。

## 架構

```text
frozen-runner-infra/
├── global-env/                  # 共用 GCP project 與 region 設定
│   └── env.sh                   # 目前 active environment 設定
├── 01_cloudbuild/               # Cloud Build pipeline 基礎建設
│   ├── base/                    # API、IAM、GitHub connection/repository
│   │   ├── scripts/
│   │   │   ├── env/env.sh       # Cloud Build 專用 metadata
│   │   │   ├── 00_env.sh        # 載入共用與專用設定
│   │   │   ├── 01_setup-exec-iam-account-role.sh
│   │   │   ├── 02_enable-apis.sh
│   │   │   ├── 03_setup-cloud-build-iam.sh
│   │   │   └── 04_setup-github-connection.sh
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
│   │   └── README.md
│   └── deploy/                  # production deploy trigger 與 verification
│       ├── scripts/
│       ├── tests/scripts.sh
│       └── README.md
├── 02_network/                  # VPC、subnet、Private Services Access、NAT
├── 03_cloudsql/                 # private PostgreSQL instance、database、users
├── 04_secrets/                 # runtime/deploy identities 與 secret metadata
├── 05_co-signer/                # Safeheron Co-Signer VM、KMS 與 IAM
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
01_cloudbuild/base/scripts/env/env.sh
```

## 共用建立順序

先確認 `global-env/env.sh` 的 `PROJECT_NAME`、`GOOGLE_PROJECT_ID`、
`GOOGLE_PROJECT_REGION`、`EXEC_IAM_ACCOUNT`。`GOOGLE_PROJECT_ID` 是所有
scripts 的實際 GCP project target；`PROJECT_NAME` 只用於 resource naming。
各 module 的 `scripts/env/env.sh` 只放必填的非機密設定，內容以 module
README 為準。

正式建立順序固定為：

1. [`02_network/README.md`](02_network/README.md)
2. [`03_cloudsql/README.md`](03_cloudsql/README.md)
3. [`04_secrets/README.md`](04_secrets/README.md)
4. [`01_cloudbuild/deploy/README.md`](01_cloudbuild/deploy/README.md)

反向撤銷 custom provisioning role 的順序為 deploy、main-app、Cloud SQL、
network，各執行對應的 `scripts/99_remove-exec-iam-account-role.sh`。這些
script 只移除 `EXEC_IAM_ACCOUNT` 的 provisioning role binding，不刪除
runtime/deploy identities 或已建立的資源；撤銷後可用 IAM policy 檢查確認只
留下 runtime/deploy service-account bindings。

### Cloud Build

先依 [`01_cloudbuild/base/README.md`](01_cloudbuild/base/README.md) 的實際順序執行
`00_env.sh` 載入設定、`01_setup-exec-iam-account-role.sh`、`02_enable-apis.sh`、
`03_setup-cloud-build-iam.sh`，以及需要時的
`04_setup-github-connection.sh`，建立必要 API、Cloud Build service account 與
GitHub connection/repository metadata。再閱讀
[`01_cloudbuild/build-image/README.md`](01_cloudbuild/build-image/README.md)，建立 GAR、
CI trigger、automatic `v*` release trigger，或手動指定如 `v0.1.0-pre` 的 image build
trigger。CI trigger 可用以下命令建立或確認：

```bash
bash 01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh
bash 01_cloudbuild/base/scripts/02_enable-apis.sh
bash 01_cloudbuild/base/scripts/03_setup-cloud-build-iam.sh
bash 01_cloudbuild/base/scripts/04_setup-github-connection.sh \
  CONNECTION_NAME REPOSITORY_NAME \
  https://github.com/GITHUB_OWNER/GITHUB_REPOSITORY.git
bash 01_cloudbuild/build-image/scripts/00_create-ci-trigger.sh
```

Cloud Build image pipeline 只負責建立與 push app/migration image，不負責 Cloud Run
deploy、database migration 或 Co-Signer VM activation。

### Co-Signer

`05_co-signer/` 依 Safeheron 官方流程建立每個 Co-Signer 所需的 IAM、KMS 與 VM。執行
方式請看 [`05_co-signer/README.md`](05_co-signer/README.md)。Pairing Token、`.env`、
Safeheron activation 與 start/setup 不會寫入 Git 或由 Cloud Build 管理。

本計畫不建立或啟用 Co-Signer 資源；既有的
`05_co-signer/scripts/99_remove-exec-iam-account-role.sh` 仍可在需要時執行，
只撤銷既有 Co-Signer provisioning role binding。cleanup 不刪除未知人員的 roles，
也不建立 Co-Signer resource。

### Cleanup

以下只撤銷各 module 的 `EXEC_IAM_ACCOUNT` provisioning role binding，不刪除已建立
資源、不刪除 runtime/deploy service account，也不刪除未知人員的 roles：

```bash
bash 02_network/scripts/99_remove-exec-iam-account-role.sh
bash 03_cloudsql/scripts/99_remove-exec-iam-account-role.sh
bash 04_secrets/scripts/99_remove-exec-iam-account-role.sh
bash 01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh
bash 01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh
bash 05_co-signer/scripts/99_remove-exec-iam-account-role.sh
```

最後一支是 Co-Signer 的 revoke-only cleanup；本 repo 不建立 Co-Signer resource。

### Local verification

這些命令只執行 local tests、shell syntax check、YAML parse 與 diff whitespace check，
不會宣稱或驗證 live GCP resource 已建立：

```bash
bash 02_network/tests/scripts.sh
bash 03_cloudsql/tests/scripts.sh
bash 04_secrets/tests/scripts.sh
bash 01_cloudbuild/base/tests/scripts.sh
bash 01_cloudbuild/deploy/tests/scripts.sh
bash 05_co-signer/tests/scripts.sh
bash -n 02_network/scripts/*.sh 03_cloudsql/scripts/*.sh 04_secrets/scripts/*.sh \
  01_cloudbuild/base/scripts/*.sh 01_cloudbuild/deploy/scripts/*.sh \
  01_cloudbuild/build-image/scripts/*.sh 05_co-signer/scripts/*.sh
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' \
  $(git ls-files '*.yaml' '*.yml')
git diff --check
```

在 sibling `frozen-runner` repo root 執行相同的 YAML parse 與 diff check：

```bash
ruby -e 'require "yaml"; ARGV.each { |path| YAML.load_file(path) }' \
  $(git ls-files '*.yaml' '*.yml')
git diff --check
```

## 安全邊界

- 不將 secret、Pairing Token、`.env` 或 service-account JSON key 寫入 repo。
- Runtime service account 與 Cloud Build service account 分開管理。
- GCP 資源建立前，確認 `global-env/env.sh` 指向正確 project，避免誤操作其他環境。
- Secret values、database passwords 與 secret versions 不提交、不放入 env、
  argv 或 Cloud Build substitutions；依各 module README 使用 stdin 或核准的
  Secret Manager 流程。
- 本 repo 的 local tests 只使用 mock `gcloud`/靜態檢查，不執行 live GCP、OAuth、
  trigger、image build、Cloud Run deploy 或 provisioning。
