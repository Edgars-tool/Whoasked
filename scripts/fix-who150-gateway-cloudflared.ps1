param(
    [string]$GatewayHealthUrl = "http://127.0.0.1:18789/health",
    [int]$GatewayPort = 18789,
    [int]$CloudflaredLocalPort = 8765,
    [string]$GatewayWorkspace = "C:\Users\EdgarsTool\Projects\openclaw-workspace",
    [string]$GatewayStartScript = "start-gateway-local.ps1",
    [switch]$StartGateway,
    [switch]$RestartCloudflared,
    [switch]$SkipExternalCheck
)

$ErrorActionPreference = "Stop"

function Test-HttpJson {
    param([string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        return [PSCustomObject]@{
            Ok = $true
            StatusCode = [int]$response.StatusCode
            Content = $response.Content
            Error = $null
        }
    } catch {
        return [PSCustomObject]@{
            Ok = $false
            StatusCode = $null
            Content = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-LocalPortListen {
    param([int]$Port)
    $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $connections)
}

Write-Host "=== WHO-150 修復助手：Gateway + Cloudflared ===" -ForegroundColor Cyan

# 1) Gateway health
$gatewayHealth = Test-HttpJson -Url $GatewayHealthUrl
if ($gatewayHealth.Ok) {
    Write-Host "[OK] Gateway health 可達，HTTP $($gatewayHealth.StatusCode)" -ForegroundColor Green
} else {
    Write-Warning "[FAIL] Gateway health 無回應：$($gatewayHealth.Error)"

    if ($StartGateway) {
        Write-Host "嘗試啟動 Gateway：$GatewayWorkspace\\$GatewayStartScript" -ForegroundColor Yellow
        Push-Location $GatewayWorkspace
        try {
            & ".\\$GatewayStartScript"
            Start-Sleep -Seconds 5
        } finally {
            Pop-Location
        }

        $gatewayHealth = Test-HttpJson -Url $GatewayHealthUrl
        if ($gatewayHealth.Ok) {
            Write-Host "[OK] Gateway 啟動後 health 可達，HTTP $($gatewayHealth.StatusCode)" -ForegroundColor Green
        } else {
            Write-Warning "[FAIL] Gateway 啟動後仍無回應：$($gatewayHealth.Error)"
        }
    } else {
        Write-Host "提示：可加上 -StartGateway 參數自動嘗試啟動。" -ForegroundColor DarkYellow
    }
}

# 2) Cloudflared process + listen port
$cloudflaredProcess = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
if ($cloudflaredProcess) {
    Write-Host "[OK] cloudflared process 存在（PID: $($cloudflaredProcess.Id -join ', ')）" -ForegroundColor Green
} else {
    Write-Warning "[FAIL] cloudflared process 不存在"
}

$portListening = Test-LocalPortListen -Port $CloudflaredLocalPort
if ($portListening) {
    Write-Host "[OK] Local port $CloudflaredLocalPort 正在 LISTEN" -ForegroundColor Green
} else {
    Write-Warning "[FAIL] Local port $CloudflaredLocalPort 未 LISTEN"
}

if ($RestartCloudflared) {
    Write-Host "嘗試重啟 cloudflared Windows Service" -ForegroundColor Yellow
    $svc = Get-Service | Where-Object { $_.Name -like "*cloudflared*" -or $_.DisplayName -like "*cloudflared*" } | Select-Object -First 1

    if ($svc) {
        if ($svc.Status -eq "Running") {
            Restart-Service -Name $svc.Name -Force
        } else {
            Start-Service -Name $svc.Name
        }
        Start-Sleep -Seconds 3

        $portListening = Test-LocalPortListen -Port $CloudflaredLocalPort
        if ($portListening) {
            Write-Host "[OK] 重啟後 port $CloudflaredLocalPort 已 LISTEN" -ForegroundColor Green
        } else {
            Write-Warning "[FAIL] 重啟後 port $CloudflaredLocalPort 仍未 LISTEN"
        }
    } else {
        Write-Warning "找不到 cloudflared service。可能是手動啟動模式。"
    }
}

# 3) External endpoint check
if (-not $SkipExternalCheck) {
    $external = Test-HttpJson -Url "https://mcp.whoasked.vip/mcp"
    if ($external.Ok) {
        Write-Host "[OK] 外網 MCP endpoint 可達，HTTP $($external.StatusCode)" -ForegroundColor Green
    } else {
        Write-Warning "[FAIL] 外網 MCP endpoint 異常：$($external.Error)"
    }
}

Write-Host "=== 檢查完成 ===" -ForegroundColor Cyan
