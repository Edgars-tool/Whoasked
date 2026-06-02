param(
    [string]$TraceLogPath = (Join-Path (Get-Location) "logs\cache-trace.jsonl"),
    [ValidateRange(1, 4096)]
    [int]$RotateAtMB = 256,
    [ValidateRange(1, 365)]
    [int]$KeepArchives = 14,
    [switch]$ForceRotate
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([Parameter(Mandatory)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Ensure-FileExists {
    param([Parameter(Mandatory)][string]$FilePath)
    $parent = Split-Path -Parent $FilePath
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $FilePath)) {
        New-Item -ItemType File -Path $FilePath -Force | Out-Null
    }
}

Write-Host "=== WHO-97 cache trace rotation ===" -ForegroundColor Cyan
Write-Warning "若 gateway 正在高頻寫入，checkpoint（備份）與 truncate（清空）之間可能有極短時間差，少數最新資料可能遺漏。建議於低流量或維護時段執行。"

$tracePath = Resolve-FullPath -Path $TraceLogPath
Ensure-FileExists -FilePath $tracePath

$logDir = Split-Path -Parent $tracePath
$archiveDir = Join-Path (Join-Path $logDir "archive") "cache-trace"
New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

$traceItem = Get-Item -LiteralPath $tracePath
$thresholdBytes = [int64]$RotateAtMB * 1MB

if (-not $ForceRotate -and $traceItem.Length -lt $thresholdBytes) {
    Write-Host ("[SKIP] {0} < {1} MB，未達輪替門檻。" -f [Math]::Round(($traceItem.Length / 1MB), 2), $RotateAtMB) -ForegroundColor Yellow
    exit 0
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$checkpointPath = Join-Path $archiveDir ("cache-trace.{0}.checkpoint.jsonl" -f $timestamp)

Copy-Item -LiteralPath $tracePath -Destination $checkpointPath -Force
Write-Host "[OK] 已建立 checkpoint：$checkpointPath" -ForegroundColor Green

$stream = [System.IO.File]::Open($tracePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
try {
    $stream.SetLength(0)
} finally {
    $stream.Dispose()
}

# 以 Write 權限重新開啟檔案，確認 truncate 後仍可被寫入。
try {
    $writeProbe = [System.IO.File]::Open($tracePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    $writeProbe.Dispose()
} catch {
    throw "truncate 後無法重新開啟檔案進行寫入：$tracePath。$($_.Exception.Message)"
}

Write-Host "[OK] 已清空 active trace，gateway 可繼續寫入同一路徑。" -ForegroundColor Green

$archives = Get-ChildItem -LiteralPath $archiveDir -File -Filter "cache-trace.*.checkpoint.jsonl" |
    Sort-Object LastWriteTimeUtc -Descending

if ($archives.Count -gt $KeepArchives) {
    $toRemove = $archives | Select-Object -Skip $KeepArchives
    foreach ($archive in $toRemove) {
        Remove-Item -LiteralPath $archive.FullName -Force
        Write-Host "[CLEANUP] 移除舊 archive：$($archive.Name)" -ForegroundColor DarkYellow
    }
}

$activeSizeMB = [Math]::Round(((Get-Item -LiteralPath $tracePath).Length / 1MB), 2)
Write-Host ("[DONE] Active log：{0} MB，保留 archive 份數上限：{1}" -f $activeSizeMB, $KeepArchives) -ForegroundColor Cyan
