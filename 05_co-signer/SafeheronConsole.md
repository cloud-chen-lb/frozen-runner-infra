# 在 Safeheron Console 中設定 Frozen Runner

## 設定 Frozen Runner 的 API Key

1. 先從開發人員那取得這些資訊，通常會隨著本文件附上

    - API Public Key 
    - frozen runner 服務的固定ip位址

2. 左側選單 -> 管理 -> API

    - 按下左上角的 "創建 API Key" 後會出現 "添加 API Key" Sheet

3. 添加 API Key Sheet
    
    - 用途
        
        選擇 "訪問 API"
    
    - 名稱
        
        輸入 "frozen-runner" ，這邊的名稱未來會在策略中設定 建議按照本文件寫輸入
    
    - 您的公鑰

        輸入從開發人員拿到的 `API Public Key`
    
    - IP白名單
        
        請打開IP白名單後 輸入步驟1 中拿到的 `frozen runner 服務的固定ip位址`

    - API Key 非法訪問熔断

        根據需求設定，推薦打開增加安全性

    - 設置權限

       勾選 "讀取" "發起/取消交易 (從 API 創建的錢包帳戶)" "發起/取消交易 (從平台內創建的錢包帳戶)"

    以上都設定完成以後 按下 "提交審批" 等審批完成以後 請按照下一個步驟說明提供開發人員設定資訊

4. 審批完成以後 請提供開發人員以下資訊

    - 左側選單 -> 管理 -> API -> 在列表上找到 `frozen-runner` 並按下公鑰欄位上的 "查看" 按鈕 -> API Key 公鑰明細

        請複製此頁面上的 `API Key` 和 `平台公鑰` 後 將此資訊加密以後寄給 開發人員
        
## 設定 Co-Signer

1. 先從開發人員那取得這些資訊，通常會隨著本文件附上

    - Co-Signer Public Key
    - Co-Signer 的固定ip位址
    - Co-Signer Callback URL

2. 左側選單 -> 管理 -> API

    - 按下左上角的 "創建 API Key" 後會出現 "添加 API Key" Sheet

3. 添加 API Key Sheet

    - 用途
        
        選擇 "部署 API Co-Signer"
    
    - 名稱
        
        輸入 "frozen-runner-cosigner" ，這邊的名稱未來會在策略節點中設定 建議按照本文件寫輸入
    
    - IP 白名單

        輸入開發人員提供的 `Co-Signer 的固定ip位址`
    
    - API Key 非法訪問熔断

        根據需求設定，推薦打開增加安全性
    
    - Callback
        
        URL 輸入開發人員提供的 `Co-Signer Callback URL`

        公鑰 輸入開發人員提供的 `Co-Signer Public Key`
    
    以上都設定完成以後 按下 "提交審批" 等審批完成以後 請按照下一個步驟說明提供開發人員設定資訊

4. 審批完成以後 請提供開發人員 Pairing Token

   - 左側選單 -> 管理 -> API -> 在列表上找到 `frozen-runner-cosigner` 按下 "更多" -> Pairing Token
       
        在頁面中複製 `Pairing Token` 後 提供給開發人員
        
        * Pairing Token 是一個 1 小時有效的一次性 Token，可以通過刷新生成新的 1 小時有效的 Token，請確保開發人員可以在一個小時內處理這一段
  
   - 啟動 Co-Signer
        
        開發人員透過 `Pairing Token` 啟動 Co-Signer 後會提供 `激活碼` 和 `QR Code` 給 Safeheron團隊創建人，創建人審核同意以後 Co-Signer 才正式可用
      
