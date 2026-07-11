# WHO-210 / EDG-108 Runbook：Linear Webhook → Hermes 處理 → Linear 回寫 E2E 測試

## 目的

驗證 `linear.whoasked.vip/linear-webhook` 收到 Linear webhook 後，能把事件寫入 queue、由 Hermes 消費處理，並把結果 comment 回寫到 Linear。

## 邊界與安全

- 不要把 `LINEAR_WEBHOOK_SECRET`、Linear API token 或任何密鑰寫入 repo、issue comment、log 摘要。
- 若需要密鑰，請從部署環境或德德的 secrets isolation zone 取得；不要貼到聊天或文件。
- 本 runbook 只描述驗證步驟，不會部署、重啟服務或修改遠端設定。
- PowerShell 範例中的路徑與 service 名稱需依實際 VPS / Windows / container 部署調整。

## 前置條件

- WHO-208 已確認實際 webhook 事件類型與 header 名稱。
- WHO-209 的 Hermes queue consumer 與 Linear comment 回寫邏輯已部署。
- 目標服務 `https://linear.whoasked.vip/linear-webhook` 可從測試機連線。
- 測試者可讀取目標環境的 queue 與 Hermes log。

## 共用變數

```powershell
$WebhookUri = "https://linear.whoasked.vip/linear-webhook"
$RawBody = ".\tmp\who-210-test-body.json"
$DeliveryId = "who-210-smoke-$(Get-Date -Format yyyyMMdd-HHmmss)"
$WebhookSecret = $env:LINEAR_WEBHOOK_SECRET
```

> 若 `$WebhookSecret` 是空值，先停止；不要把 secret 輸入到會被 commit 的檔案。

## 案例 1：手動發送測試 webhook

### 1. 送出 Linear 相容測試 webhook

先 dry-run，確認 payload 與簽章可產生：

```powershell
.\scripts\send-linear-test-webhook.ps1 `
  -Uri $WebhookUri `
  -WebhookSecret $WebhookSecret `
  -DeliveryId $DeliveryId `
  -RawBodyFile $RawBody `
  -DryRun
```

再驗證 raw body 簽章：

```powershell
$Signature = (.\scripts\send-linear-test-webhook.ps1 -Uri $WebhookUri -WebhookSecret $WebhookSecret -DeliveryId $DeliveryId -RawBodyFile $RawBody -DryRun | Select-String "Linear-Signature:" | ForEach-Object { $_.ToString().Split(":", 2)[1].Trim() })
.\scripts\verify-linear-webhook-signature.ps1 -WebhookSecret $WebhookSecret -RawBodyFile $RawBody -Signature $Signature
```

正式送出：

```powershell
.\scripts\send-linear-test-webhook.ps1 `
  -Uri $WebhookUri `
  -WebhookSecret $WebhookSecret `
  -DeliveryId $DeliveryId `
  -RawBodyFile $RawBody
```

### 2. 觀察 queue 是否寫入

在實際部署環境檢查 `event-queue.jsonl` 或對應 queue backend：

```powershell
Get-Content .\runtime\event-queue.jsonl -Tail 20 -Wait
```

觀察重點：

- 是否出現同一個 `DeliveryId` 或 webhook payload id。
- 是否保留足夠欄位追蹤 Linear issue/comment。
- webhook 收到後 5 秒內是否出現可消費事件。

### 3. 觀察 Hermes 是否消費 queue

依實際部署方式查看 Hermes log：

```powershell
Get-Content .\logs\hermes-agent.log -Tail 100 -Wait
```

觀察重點：

- 是否記錄收到 event、dedupe key、issue identifier。
- 是否開始執行處理流程。
- 是否有錯誤、重試、或 skipped duplicate。

## 案例 2：真實 Linear Agent @mention

1. 在 Linear issue 留言：`@hermesagent 請回覆這則 WHO-210 E2E 測試。`
2. 觀察 webhook receiver log，確認 Linear 真的送到 `linear.whoasked.vip`。
3. 觀察 queue 是否新增真實事件。
4. 觀察 Hermes 是否處理該 issue/comment。
5. 回到 Linear 確認是否新增 Hermes comment。

成功時至少要記錄：

- Linear comment 建立時間。
- webhook receiver 收到時間。
- queue 寫入時間。
- Hermes 開始處理時間。
- Linear comment 回寫時間。

## 案例 3：長時任務處理

1. 在 Linear 發送一則較複雜但安全的任務，例如：「請整理此 issue 的測試結果，列出成功、失敗、待確認項目。」
2. 觀察 Hermes log 是否有清楚的進度、錯誤與最終狀態。
3. 確認 Linear 回覆格式符合德德可讀性需求：先結論、再細節、清楚列出下一步。

## 成功標準

- webhook 收到後 5 秒內開始處理或進入可消費 queue。
- Hermes 處理完成後成功回寫 Linear comment。
- 回寫內容與觸發的 Linear issue/comment 對得起來。
- log 能追蹤 delivery id、dedupe key、issue id、comment id、處理狀態。
- 重送相同 `DeliveryId` 時，不會產生重複處理或重複回覆。

## 常見問題

### 簽章驗證失敗

最常見原因是驗簽時使用 parse 後重新序列化的 JSON，而不是 webhook 原始 body。請用 `-RawBodyFile` 保存並驗證原始 body。

### queue 沒有事件

先確認 webhook endpoint 是否回 2xx，再確認 receiver log 是否記錄驗簽失敗、event type 被忽略、或 dedupe 擋下。

### Linear 沒有回覆

先確認 Hermes 是否真的完成處理，再確認 Linear API token 權限、目標 issue/comment id、以及回寫 API 的錯誤訊息。
