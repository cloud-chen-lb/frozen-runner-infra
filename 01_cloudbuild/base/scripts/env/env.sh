# Cloud Build 專用 metadata；由 connection/repository 建立後填入。
# 供基礎環境與 CI/release trigger 使用，不建立資源，也不包含秘密值。
# 變更名稱前須確認既有 Cloud Build connection/repository，避免 trigger 指向錯誤來源。
CLOUD_BUILD_CONNECTION_NAME="Github_Connect"
CLOUD_BUILD_REPOSITORY_NAME="echox-project-frozen-runner"
