# 全域環境設定：供所有基礎設施腳本載入專案與執行帳號資訊。
# 主要流程是選定環境值並由各模組驗證後匯出；本檔不建立 GCP 資源。
# PROJECT_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION、EXEC_IAM_ACCOUNT
# 會影響資源命名、目標專案、區域與 IAM 綁定；請確認 gcloud 目前帳號有權限。
# 安全限制：本檔只放非密碼設定，切換環境前須人工確認專案 ID，避免誤操作。
# Active environment configuration for Cloud Build scripts.
# Change these values when switching between development and production.

# Beta 環境：切換至 Beta 時取消以下 4 行註解，並將 Prod 區塊的同名設定註解；
# PROJECT_NAME 是資源名稱前綴，格式為小寫英數字與連字號組成的專案名稱。
# PROJECT_NAME="frozen-runner"
# GOOGLE_PROJECT_ID 是 GCP project ID，格式為 GCP 專案 ID；請填入要操作的 Beta 專案。
# GOOGLE_PROJECT_ID="echox-beta"
# GOOGLE_PROJECT_REGION 是 GCP 區域，格式為區域名稱；請填入資源部署所在區域。
# GOOGLE_PROJECT_REGION="asia-east1"
# EXEC_IAM_ACCOUNT 是執行佈建腳本的人員 IAM 電子郵件；格式為帳號 email。
# EXEC_IAM_ACCOUNT="cloud.chen@getoken.io"

# Prod 環境：正式環境使用以下 4 行設定；切換環境時只保留一個區塊的同名設定。
# PROJECT_NAME 是資源名稱前綴，格式為小寫英數字與連字號組成的專案名稱。
PROJECT_NAME="frozen-runner"
# GOOGLE_PROJECT_ID 是 GCP project ID，格式為 GCP 專案 ID；請填入正式環境專案。
GOOGLE_PROJECT_ID="echox-project"
# GOOGLE_PROJECT_REGION 是 GCP 區域，格式為區域名稱；須與既有網路、Cloud SQL 與 Cloud Run 配置一致。
GOOGLE_PROJECT_REGION="asia-east1"
# EXEC_IAM_ACCOUNT 是執行佈建腳本的人員 IAM 電子郵件；格式為帳號 email，且目前 gcloud 帳號須有對應權限。
EXEC_IAM_ACCOUNT="cloud.chen@getoken.io"
