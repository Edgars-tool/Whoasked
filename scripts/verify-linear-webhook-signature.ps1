param(
    [Parameter(Mandatory)]
    [string]$WebhookSecret,
    [Parameter(Mandatory)]
    [string]$RawBodyFile,
    [Parameter(Mandatory)]
    [string]$Signature
)

$ErrorActionPreference = "Stop"

function ConvertTo-HexString {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return -join ($Bytes | ForEach-Object { $_.ToString("x2") })
}

$rawBodyPath = [IO.Path]::GetFullPath($RawBodyFile)
if (-not (Test-Path -LiteralPath $rawBodyPath)) {
    throw "Raw body file not found: $rawBodyPath"
}

$rawBody = [IO.File]::ReadAllText($rawBodyPath, [Text.UTF8Encoding]::new($false))
$keyBytes = [Text.Encoding]::UTF8.GetBytes($WebhookSecret)
$bodyBytes = [Text.Encoding]::UTF8.GetBytes($rawBody)
$hmac = [Security.Cryptography.HMACSHA256]::new($keyBytes)
try {
    $expected = ConvertTo-HexString -Bytes ($hmac.ComputeHash($bodyBytes))
} finally {
    $hmac.Dispose()
}

Write-Host "=== Linear webhook signature verify ===" -ForegroundColor Cyan
Write-Host "Raw body: $rawBodyPath"
Write-Host "Expected: $expected"
Write-Host "Provided: $Signature"

if ($expected -ieq $Signature) {
    Write-Host "[OK] Signature matches raw body." -ForegroundColor Green
    exit 0
}

Write-Host "[FAIL] Signature does not match raw body." -ForegroundColor Red
Write-Warning "請確認驗簽使用的是 webhook 收到的原始 body bytes；不要 parse JSON 後再重新序列化。"
exit 1
