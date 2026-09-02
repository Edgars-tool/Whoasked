# WHO-150 Runbook：修復 Gateway + Cloudflared 服務狀態

## 目的
把以下三個健康檢查恢復到可用狀態：
- `http://127.0.0.1:18789/health` 有回應（Gateway）
- cloudflared 本機對應 port（預設 8765）有 LISTEN
- 外網 `https://mcp.edgars.tools/mcp` 可連線

## 一次執行（建議）
以 PowerShell 執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\fix-who150-gateway-cloudflared.ps1 -StartGateway -RestartCloudflared
```

## 腳本做了什麼
1. 檢查 Gateway health endpoint。
2. 若加上 `-StartGateway`，執行：
   - `C:\Users\EdgarsTool\Projects\openclaw-workspace\start-gateway-local.ps1`
3. 檢查 `cloudflared` process 是否存在。
4. 檢查本機 port（預設 8765）是否 LISTEN。
5. 若加上 `-RestartCloudflared`，嘗試重啟 Windows service（名稱含 `cloudflared`）。
6. 檢查 `https://mcp.edgars.tools/mcp` 是否可達。

## 常用參數
- `-StartGateway`：自動嘗試啟動 Gateway。
- `-RestartCloudflared`：自動嘗試重啟 cloudflared 服務。
- `-SkipExternalCheck`：跳過外網檢查。
- `-GatewayWorkspace`：覆蓋 Gateway 專案路徑。
- `-GatewayStartScript`：覆蓋啟動腳本名稱。

## 驗證
最後請再跑德德原本的健檢批次檔：

```powershell
C:\Users\EdgarsTool\Desktop\健檢.bat
```

目標是三項都顯示 ✅。
