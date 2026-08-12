# 全域環境設定：供所有基礎設施腳本載入專案與執行帳號資訊。
# 主要流程是選定環境值並由各模組驗證後匯出；本檔不建立 GCP 資源。
# PROJECT_NAME、GOOGLE_PROJECT_ID、GOOGLE_PROJECT_REGION、EXEC_IAM_ACCOUNT
# 會影響資源命名、目標專案、區域與 IAM 綁定；請確認 gcloud 目前帳號有權限。
# 安全限制：本檔只放非密碼設定，切換環境前須人工確認專案 ID，避免誤操作。
# Active environment configuration for Cloud Build scripts.
# Change these values when switching between development and production.

# Beta
# PROJECT_NAME="frozen-runner"
# GOOGLE_PROJECT_ID="echox-beta"
# GOOGLE_PROJECT_REGION="asia-east1"
# EXEC_IAM_ACCOUNT="cloud.chen@getoken.io"

# Prod
# 專案名稱
PROJECT_NAME="frozen-runner"
# GCP專案ID
GOOGLE_PROJECT_ID="echox-project"
# GCP專案區域
GOOGLE_PROJECT_REGION="asia-east1"
# GCP專案執行IAM帳號
EXEC_IAM_ACCOUNT="cloud.chen@getoken.io"
