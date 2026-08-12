# Production GCP Resources Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development (recommended) superpowers:executing-plans implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax tracking.

**Goal:** 依照已核准的 production GCP design，建立主系統 network、PostgreSQL、runtime IAM、Secret Manager、Cloud Run 與 production deploy pipeline，並讓 `EXEC_IAM_ACCOUNT` 的 provisioning 權限可按模組授予與撤銷。

**Architecture:** 延續本 repo 的 shell script 與 module-local `env.sh` 架構。每個 provisioning module 從 `global-env/env.sh` 取得 `PROJECT_NAME`、`GOOGLE_PROJECT_ID`、region 與 `EXEC_IAM_ACCOUNT`，再載入自己的非機密設定；每個 module 都有自己的 `setup-exec-iam-account-role.sh` 與 `remove-exec-iam-account-role.sh`。資源依 network → Cloud SQL → main-app IAM/secrets → Cloud Run/deploy 的順序建立，所有已存在但 drift 的資源都停止而不自動覆蓋。

**Tech Stack:** Bash、gcloud CLI、GCP VPC/Cloud NAT/Cloud SQL/Secret Manager/Cloud Run/Cloud Build、mock `gcloud` shell tests。

## Global Constraints

- `PROJECT_NAME=frozen-runner` 僅用於資源命名；`GOOGLE_PROJECT_ID=echox-project` 才是 GCP API target。
- 不建立或修改 Co-Signer VM、KMS、merchant service account、static IP、Co-Signer subnet、MySQL instance/database/user。
- 不建立或修改既有 Global Load Balancer、DNS、TLS、serverless backend 與 callback source restriction。
- 不重做既有 Cloud Build base、Artifact Registry、CI trigger 與 release image trigger。
- 所有 scripts 使用 `set -euo pipefail`、script-relative paths、quoted substitutions，並先 describe 再 create。
- 資源存在但設定不符合 contract 時必須輸出 drift 並失敗，不得自動修改或刪除。
- 不把 secret value、Pairing Token、service-account JSON key 或 password 寫入 repository、image、log 或 Cloud Build substitutions。
- `EXEC_IAM_ACCOUNT` 只取得 provisioning custom roles；完成後只撤銷本 repo 建立的 bindings，不刪除未知的人員授權。
- 自動化驗證不得執行會修改 GCP 的 provisioning、OAuth、trigger creation、release build 或 deploy。

---

## File Map

### Existing files to modify

- `01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh`: 改成可重跑的 Cloud Build provisioning role create/update/bind。
- `01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh`: 新增只撤銷 Cloud Build provisioning role 的清理腳本。
- `05_co-signer/scripts/99_remove-exec-iam-account-role.sh`: 新增只撤銷既有 Co-Signer provisioning role 的清理腳本；本計畫不執行 Co-Signer 資源建立。
- `01_cloudbuild/base/scripts/00_env.sh`: 保持 global/module env loading contract，必要時補上 shared validation。
- `/Users/leadbest/Documents/Work/frozen-runner/cicd/prod/cloudbuild-deploy.yaml`: 將硬編碼 project identity 改成 `${PROJECT_ID}`，保留 migration-before-app 順序。
- `README.md`: 補上 network、Cloud SQL、main-app、deploy module 的執行順序與 revoke 說明。

### New files

- `02_network/scripts/env/env.sh`
- `02_network/scripts/00_env.sh`
- `02_network/scripts/01_setup-exec-iam-account-role.sh`
- `02_network/scripts/02_enable-apis.sh`
- `02_network/scripts/03_create-vpc.sh`
- `02_network/scripts/04_create-main-app-subnet.sh`
- `02_network/scripts/05_create-private-services-access.sh`
- `02_network/scripts/06_create-router-nat.sh`
- `02_network/scripts/99_remove-exec-iam-account-role.sh`
- `02_network/tests/scripts.sh`
- `03_cloudsql/scripts/env/env.sh`
- `03_cloudsql/scripts/00_env.sh`
- `03_cloudsql/scripts/01_setup-exec-iam-account-role.sh`
- `03_cloudsql/scripts/02_create-postgres-instance.sh`
- `03_cloudsql/scripts/03_create-postgres-database-users.sh`
- `03_cloudsql/scripts/99_remove-exec-iam-account-role.sh`
- `03_cloudsql/tests/scripts.sh`
- `04_main-app/scripts/env/env.sh`
- `04_main-app/scripts/00_env.sh`
- `04_main-app/scripts/01_setup-exec-iam-account-role.sh`
- `04_main-app/scripts/02_setup-service-accounts.sh`
- `04_main-app/scripts/03_setup-secrets.sh`
- `04_main-app/scripts/99_remove-exec-iam-account-role.sh`
- `04_main-app/tests/scripts.sh`
- `01_cloudbuild/deploy/scripts/env/env.sh`
- `01_cloudbuild/deploy/scripts/00_env.sh`
- `01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh`
- `01_cloudbuild/deploy/scripts/02_setup-deploy-iam.sh`
- `01_cloudbuild/deploy/scripts/03_create-production-trigger.sh`
- `01_cloudbuild/deploy/scripts/04_run-production-deploy.sh`
- `01_cloudbuild/deploy/scripts/05_verify-deployment.sh`
- `01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh`
- `01_cloudbuild/deploy/tests/scripts.sh`
- `01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh`
- `05_co-signer/scripts/99_remove-exec-iam-account-role.sh`

---

## Task 1: Establish module environment and operator-role conventions

**Files:**

- Create: `02_network/scripts/env/env.sh`, `02_network/scripts/00_env.sh`
- Create: `03_cloudsql/scripts/env/env.sh`, `03_cloudsql/scripts/00_env.sh`
- Create: `04_main-app/scripts/env/env.sh`, `04_main-app/scripts/00_env.sh`
- Create: `01_cloudbuild/deploy/scripts/env/env.sh`, `01_cloudbuild/deploy/scripts/00_env.sh`
- Modify: `01_cloudbuild/base/scripts/00_env.sh`
- Test: `02_network/tests/scripts.sh`, `03_cloudsql/tests/scripts.sh`, `04_main-app/tests/scripts.sh`, `01_cloudbuild/deploy/tests/scripts.sh`

**Interfaces:**

- Consumes: `global-env/env.sh` variables `PROJECT_NAME`, `GOOGLE_PROJECT_ID`, `GOOGLE_PROJECT_REGION`, `EXEC_IAM_ACCOUNT`.
- Produces: every module `00_env.sh` exports shared variables and module-specific configuration; missing required values fail before any `gcloud` call.

- [x] **Step 1: Define module environment contracts**

  Use concrete variable names: `MAIN_APP_SUBNET_CIDR`, `PRIVATE_SERVICES_RANGE_CIDR`, `POSTGRES_DATABASE_NAME`, `POSTGRES_APP_USER`, `POSTGRES_MIGRATION_USER`, `POSTGRES_VERSION`, `POSTGRES_TIER`, `POSTGRES_STORAGE_GB`, `APP_SECRET_MAPPING`, `MIGRATION_SECRET_MAPPING`, `CLOUD_BUILD_SOURCE_BRANCH`, and `DEPLOY_SMOKE_TEST_URL`. Keep values non-secret; passwords and secret payloads are never environment-file values.

- [x] **Step 2: Implement module loaders**

  Each loader resolves paths from `BASH_SOURCE`, sources global env then module env, validates `EXEC_IAM_ACCOUNT`, and exports only its module contract. It must work both when sourced and when run as a command.

- [x] **Step 3: Add invalid-input tests**

  Prepend a failing `gcloud` stub to `PATH`, run each loader through an invalid configuration path, and assert it exits before the stub is invoked.

- [x] **Step 4: Run shell verification**

  Run `bash -n` on all four module script directories and `git diff --check`.

---

## Task 2: Add temporary EXEC_IAM_ACCOUNT roles for every module

**Files:**

- Modify: `01_cloudbuild/base/scripts/01_setup-exec-iam-account-role.sh`
- Create: `02_network/scripts/01_setup-exec-iam-account-role.sh`, `02_network/scripts/99_remove-exec-iam-account-role.sh`
- Create: `03_cloudsql/scripts/01_setup-exec-iam-account-role.sh`, `03_cloudsql/scripts/99_remove-exec-iam-account-role.sh`
- Create: `04_main-app/scripts/01_setup-exec-iam-account-role.sh`, `04_main-app/scripts/99_remove-exec-iam-account-role.sh`
- Create: `01_cloudbuild/deploy/scripts/01_setup-exec-iam-account-role.sh`, `01_cloudbuild/deploy/scripts/99_remove-exec-iam-account-role.sh`
- Create: `01_cloudbuild/base/scripts/99_remove-exec-iam-account-role.sh`
- Create: `05_co-signer/scripts/99_remove-exec-iam-account-role.sh`
- Test: module `tests/scripts.sh` files

**Interfaces:**

- Consumes: module `00_env.sh` and the exact gcloud verbs used by its later tasks.
- Produces: module-specific custom role names and deterministic add/remove binding commands for `user:${EXEC_IAM_ACCOUNT}`.

- [x] **Step 1: Define permission ownership**

  Network role covers VPC, subnet, address, router/NAT, service usage and compute network inspection. Cloud SQL role covers SQL instance/database/user and service networking inspection. Main-app role covers service account, Secret Manager metadata/IAM, Cloud Run inspection and project IAM needed for runtime bindings. Deploy role covers Cloud Build trigger, Cloud Run, Artifact Registry inspection and service-account IAM bindings.

- [x] **Step 2: Make role setup idempotent**

  Each script must create the project custom role when absent and update it when present, then add exactly one project IAM binding for `EXEC_IAM_ACCOUNT`. Existing role names must remain stable across reruns.

- [x] **Step 3: Implement scoped removal**

  Each `99_remove...` script removes only its known custom role binding and optionally deletes the known custom role after confirming no longer needed. It must not call a project-wide role removal loop.

- [x] **Step 4: Test no-secret and revoke behavior**

  Mock `gcloud` output must show the expected role member and role name while never receiving a password, secret value, or JSON key. Test removal command arguments against the module role only.

- [x] **Step 5: Run verification**

  Run all module shell tests and `bash -n` for every setup/removal script.

`01_cloudbuild/build-image` is intentionally excluded from this role set because it consumes the existing `01_cloudbuild/base` environment and image-builder identity; it does not own provisioning resources.

`05_co-signer/scripts/01_setup-exec-iam-account-role.sh` already owns a provisioning role, so its matching removal script is included for cleanup completeness. This does not activate or modify any Co-Signer VM, KMS, MySQL, subnet, or merchant resource.

---

## Task 3: Provision the main application network

**Files:**

- Create: `02_network/scripts/02_enable-apis.sh`
- Create: `02_network/scripts/03_create-vpc.sh`
- Create: `02_network/scripts/04_create-main-app-subnet.sh`
- Create: `02_network/scripts/05_create-private-services-access.sh`
- Create: `02_network/scripts/06_create-router-nat.sh`
- Modify: `02_network/tests/scripts.sh`

**Interfaces:**

- Consumes: network env contract and network operator role.
- Produces: `frozen-runner-vpc`, `frozen-runner-main-app-subnet`, `frozen-runner-private-services-range`, Private Services Access, `frozen-runner-router`, `frozen-runner-main-app-egress-ip`, and `frozen-runner-main-app-nat`.

- [x] **Step 1: Implement API enablement**

  Check each required service with `gcloud services list` before enabling: Compute, Cloud Build, Artifact Registry, IAM, IAM Credentials, Logging, Cloud Run, Secret Manager, Service Networking, Cloud SQL Admin and VPC Access.

- [x] **Step 2: Implement VPC and subnet creation**

  Create a custom-mode VPC and regional main-app subnet only when absent. Describe existing resources and compare mode, region, network and CIDR; fail on drift.

- [x] **Step 3: Implement Private Services Access**

  Reserve the configured global internal address range, create the servicenetworking connection for the VPC, and verify the connection points at the expected network and range.

- [x] **Step 4: Implement Cloud Router, address and NAT**

  Create the regional router, reserve the regional static external address, and create NAT limited to the main-app subnet. Verify region, router, IP allocation and subnet source configuration on rerun.

- [x] **Step 5: Add mock tests**

  Test invalid CIDR/region values before gcloud, absent-resource create paths, and existing-resource drift paths with a deterministic gcloud stub.

- [x] **Step 6: Run verification**

  Run `bash 02_network/tests/scripts.sh`, `bash -n 02_network/scripts/*.sh`, and `git diff --check`. Do not execute the scripts against GCP in automated verification.

---

## Task 4: Provision PostgreSQL Cloud SQL

**Files:**

- Create: `03_cloudsql/scripts/02_create-postgres-instance.sh`
- Create: `03_cloudsql/scripts/03_create-postgres-database-users.sh`
- Modify: `03_cloudsql/tests/scripts.sh`

**Interfaces:**

- Consumes: network private-services connection and Cloud SQL env contract.
- Produces: `frozen-runner-main-app-postgres`, configured database, application user, and migration DDL user; passwords are delivered only through stdin/Secret Manager.

- [x] **Step 1: Implement instance creation**

  Create PostgreSQL with the configured version, tier, storage, regional HA, private network, automated backup, PITR and deletion protection. On rerun compare those settings and fail on drift.

- [x] **Step 2: Implement database creation**

  Describe the configured database first and create it only when absent. Reject a database name that is not the configured main-app database.

- [x] **Step 3: Implement user creation without credentials in files**

  Accept passwords from a TTY/stdin flow or an explicitly provided Secret Manager version reference. Never print passwords or pass them through Cloud Build substitutions. Create the application and migration users separately.

- [x] **Step 4: Add safety tests**

  Verify invalid sizing/network inputs fail before gcloud, and mock command logs contain usernames/resource names but no password values.

- [x] **Step 5: Run verification**

  Run `bash 03_cloudsql/tests/scripts.sh`, `bash -n 03_cloudsql/scripts/*.sh`, and `git diff --check`.

---

## Task 5: Provision runtime service accounts and secrets

**Files:**

- Create: `04_main-app/scripts/02_setup-service-accounts.sh`
- Create: `04_main-app/scripts/03_setup-secrets.sh`
- Modify: `04_main-app/tests/scripts.sh`

**Interfaces:**

- Consumes: main-app env contract and main-app operator role.
- Produces: `cb-frozen-runner-mini`, `cb-frozen-runner-migration`, `cb-frozen-runner-deploy`, secret metadata, and resource-level accessor bindings.

- [x] **Step 1: Create service accounts idempotently**

  Describe each account before create, use stable display names, and never create keys. Keep `cb-share-build` as the existing image-build identity.

- [x] **Step 2: Configure deploy IAM**

  Grant deploy only Cloud Run Admin, Artifact Registry Reader, and service-account user on the app and migration runtime identities. Do not grant deploy access to application secret payloads.

- [x] **Step 3: Create secret metadata**

  Create configured application and migration Secret Manager resources with automatic replication when absent. Do not create values from repository files or shell literals.

- [x] **Step 4: Configure secret accessors**

  Grant app accessor only to `cb-frozen-runner-mini` secrets and migration accessor only to migration secrets. Validate mapping names and versions without reading secret payloads.

- [x] **Step 5: Add mock tests**

  Assert service accounts, roles, secret names and members are correct, and assert no secret payload appears in the gcloud stub log.

- [x] **Step 6: Run verification**

  Run `bash 04_main-app/tests/scripts.sh`, `bash -n 04_main-app/scripts/*.sh`, and `git diff --check`.

---

## Task 6: Implement Cloud Run deploy configuration

**Files:**

- Modify: `/Users/leadbest/Documents/Work/frozen-runner/cicd/prod/cloudbuild-deploy.yaml`
- Create: `01_cloudbuild/deploy/scripts/02_setup-deploy-iam.sh`
- Create: `01_cloudbuild/deploy/scripts/03_create-production-trigger.sh`
- Create: `01_cloudbuild/deploy/scripts/04_run-production-deploy.sh`
- Create: `01_cloudbuild/deploy/scripts/05_verify-deployment.sh`
- Modify: `01_cloudbuild/deploy/tests/scripts.sh`

**Interfaces:**

- Consumes: release image tag, Artifact Registry repository, network VPC arguments, app/migration secret mappings, deploy service account and runtime service accounts.
- Produces: a manually triggered `frozen-runner-production-deploy-trigger` that runs migration successfully before app deploy.

- [x] **Step 1: Make deploy YAML project-neutral**

  Replace the hard-coded `projects/frozen-runner` segment with `projects/${PROJECT_ID}` while preserving image substitutions, migration Job execution, `--wait`, app ingress and VPC arguments.

- [x] **Step 2: Implement deploy IAM setup**

  Create or confirm `cb-frozen-runner-deploy`, grant only the deploy permissions defined in Task 5, and bind `serviceAccountUser` only to `cb-frozen-runner-mini` and `cb-frozen-runner-migration`.

- [x] **Step 3: Implement trigger drift check**

  Create the manual trigger only when absent. Verify repository, branch, build config, service account and substitutions on rerun; fail with a drift report instead of replacing the trigger.

- [x] **Step 4: Implement trigger execution validation**

  Require a non-empty `v<release>` tag, region, VPC arguments and both secret mappings before invoking `gcloud builds triggers run`. Use the custom `^;^` substitution delimiter for comma-containing mappings.

- [x] **Step 5: Implement deployment verification**

  Describe the migration Job, latest execution, Cloud Run service image/revision/traffic, and configured ingress. Smoke-test the configured existing Load Balancer URL only when explicitly provided.

- [x] **Step 6: Add mock tests**

  Assert invalid input paths do not call gcloud, and assert deploy command ordering is migration deploy → migration execute/wait → app deploy.

- [x] **Step 7: Run verification**

  Run `bash 01_cloudbuild/deploy/tests/scripts.sh`, `bash -n 01_cloudbuild/deploy/scripts/*.sh`, sibling repo YAML validation, and `git diff --check` in both repositories.

---

## Task 7: Add operator runbooks and complete local verification

**Files:**

- Modify: `README.md`
- Create: `02_network/README.md`
- Create: `03_cloudsql/README.md`
- Create: `04_main-app/README.md`
- Create: `01_cloudbuild/deploy/README.md`

- [x] **Step 1: Document module order**

  Document the exact setup order, required non-secret env values, expected GCP project target, and the reverse removal order.

- [x] **Step 2: Document secret input boundary**

  Explain that secret versions and database passwords are entered through stdin/approved Secret Manager procedures, never committed or passed as substitutions.

- [x] **Step 3: Document post-provision cleanup**

  Add commands for each module’s `99_remove-exec-iam-account-role.sh` and a final check showing that only runtime/deploy service account bindings remain.

- [x] **Step 4: Run full local checks**

  Run `bash -n 02_network/scripts/*.sh 03_cloudsql/scripts/*.sh 04_main-app/scripts/*.sh 01_cloudbuild/deploy/scripts/*.sh`, all module test scripts, and `git diff --check` in both repositories.

- [x] **Step 5: Review external-operation boundary**

  Confirm no automated command provisions GCP, performs OAuth, creates a trigger, builds an image, deploys Cloud Run, or writes a secret.

---

## Final Acceptance

- [x] Every provisioning module has `env/env.sh`, `00_env.sh`, module-scoped `01_setup-exec-iam-account-role.sh`, and `99_remove-exec-iam-account-role.sh`; `01_cloudbuild/base` has the same setup/removal lifecycle, while `01_cloudbuild/build-image` remains a consumer of base.
- [x] The existing `co-signer` provisioning role also has a scoped removal script, without provisioning any Co-Signer resource in this plan.
- [x] All provisioning scripts target `GOOGLE_PROJECT_ID` and use `PROJECT_NAME` only for resource naming.
- [x] Co-Signer resources and the existing Global Load Balancer are untouched.
- [x] Existing Cloud Build image resources are reused rather than recreated.
- [x] Existing-resource drift fails safely for network, Cloud SQL, secrets, service accounts and deploy trigger.
- [x] Production deploy waits for migration success before app deployment.
- [x] Local syntax, mock safety tests and whitespace checks pass in both repositories.
- [x] The operator can revoke all custom provisioning roles created by this repo without removing runtime identities or unknown human permissions.
