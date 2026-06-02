# WHO-97 Runbook：`cache-trace.jsonl` rotation / archive

## 目的

控制 `logs\cache-trace.jsonl` 持續成長，避免單檔過大，同時保留可追溯 checkpoint，不直接刪除 active log。

## 預設規則

- 輪替門檻：`256 MB`
- archive 位置：`logs\archive\cache-trace\`
- 檔名格式：`cache-trace.yyyyMMdd-HHmmss.checkpoint.jsonl`
- 保留份數：`14`（超過會刪除最舊檔案）

## 執行方式（PowerShell）

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\rotate-cache-trace.ps1
```

## 常用參數

- `-TraceLogPath`：覆寫 trace log 路徑（預設 `.\logs\cache-trace.jsonl`）
- `-RotateAtMB`：設定輪替門檻（預設 `256`）
- `-KeepArchives`：設定保留份數（預設 `14`）
- `-ForceRotate`：忽略大小門檻，強制執行一次

## 安全設計

1. 先 `Copy-Item` 建立 checkpoint，再處理 active log。
2. active log 以 truncate 清空（保留同一路徑），降低對 gateway 寫入流程的干擾。
3. 依 WHO-97 guardrails，archive 清理只在 `logs\archive\cache-trace\` 下進行，不跨到其他工作區路徑（例如 secrets、runtime cache、Desktop）。

## 併發寫入注意

- 若 gateway 正在高頻寫入，checkpoint 與 truncate 之間仍存在極短時間差，少量最新資料可能不在 checkpoint 中。
- 建議在低流量時段或維護時段執行；若可控，先暫停 trace 寫入再執行會更安全。
