# 用途：提供主應用程式 Cloud Build connection/repository metadata。
# 流程：由 00_env.sh 載入，供 connection 與 CI/release trigger 腳本使用。
# 重要變數：CLOUD_BUILD_CONNECTION_NAME、CLOUD_BUILD_REPOSITORY_NAME。
# 資源影響：只定義設定；安全/驗證限制：名稱變更前須確認既有 GCP 資源，避免 trigger 指錯來源。
CLOUD_BUILD_CONNECTION_NAME="Github_Connect"
CLOUD_BUILD_REPOSITORY_NAME="echox-project-frozen-runner"
