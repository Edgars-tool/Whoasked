param(
    [string]$Uri = "https://linear.whoasked.vip/linear-webhook",
    [Parameter(Mandatory)]
    [string]$WebhookSecret,
    [string]$DeliveryId = ([guid]::NewGuid().ToString()),
    [string]$ActorId = "29b7ba38-2eb0-4add-8d97-b9d7e4bf1ece",
    [string]$IssueId = "edg-108-test-issue",
    [string]$IssueIdentifier = "EDG-108",
    [string]$CommentBody = "@hermesagent EDG-108 smoke test webhook",
    [string]$RawBodyFile,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function ConvertTo-HexString {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return -join ($Bytes | ForEach-Object { $_.ToString("x2") })
}

function New-HmacSha256Hex {
    param(
        [Parameter(Mandatory)][string]$Secret,
        [Parameter(Mandatory)][string]$Message
    )

    $keyBytes = [Text.Encoding]::UTF8.GetBytes($Secret)
    $messageBytes = [Text.Encoding]::UTF8.GetBytes($Message)
    $hmac = [Security.Cryptography.HMACSHA256]::new($keyBytes)
    try {
        return ConvertTo-HexString -Bytes ($hmac.ComputeHash($messageBytes))
    } finally {
        $hmac.Dispose()
    }
}

$payload = [ordered]@{
    action = "create"
    type = "Comment"
    createdAt = (Get-Date).ToUniversalTime().ToString("o")
    webhookTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    actor = [ordered]@{
        id = $ActorId
        name = "hermesagent-test"
        type = "user"
    }
    data = [ordered]@{
        id = "comment-$DeliveryId"
        body = $CommentBody
        issue = [ordered]@{
            id = $IssueId
            identifier = $IssueIdentifier
            title = "[CLOUD] WHO-210 測試完整 Webhook → 處理 → 回寫流程"
        }
    }
    organizationId = "whoasked-test-org"
    url = "https://linear.app/whoasked/issue/$IssueIdentifier"
}

$rawBody = $payload | ConvertTo-Json -Depth 10 -Compress
$signature = New-HmacSha256Hex -Secret $WebhookSecret -Message $rawBody

if ($RawBodyFile) {
    $rawBodyPath = [IO.Path]::GetFullPath($RawBodyFile)
    $parent = Split-Path -Parent $rawBodyPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($rawBodyPath, $rawBody, [Text.UTF8Encoding]::new($false))
    Write-Host "[OK] raw body written: $rawBodyPath" -ForegroundColor Green
}

Write-Host "=== Linear test webhook ===" -ForegroundColor Cyan
Write-Host "URI: $Uri"
Write-Host "Delivery ID: $DeliveryId"
Write-Host "Linear-Signature: $signature"
Write-Host "Body bytes: $([Text.Encoding]::UTF8.GetByteCount($rawBody))"

if ($DryRun) {
    Write-Host "[DRY-RUN] Not sending request." -ForegroundColor Yellow
    Write-Host $rawBody
    exit 0
}

$response = Invoke-WebRequest -Uri $Uri -Method Post -Body $rawBody -ContentType "application/json" -Headers @{
    "Linear-Delivery" = $DeliveryId
    "Linear-Signature" = $signature
    "User-Agent" = "Whoasked-WHO-210-E2E/1.0"
}

Write-Host ("[DONE] HTTP {0}" -f [int]$response.StatusCode) -ForegroundColor Green
if ($response.Content) {
    Write-Host $response.Content
}
