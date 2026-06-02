<#
.SYNOPSIS
  Read-only local repository health audit for Edgar's Windows workspaces.

.DESCRIPTION
  Scans configured roots for Git repositories, evaluates category and exemption policy,
  checks dirty tree, upstream presence, ahead/behind counts, and read-only remote
  reachability, then writes stable JSON and Markdown reports.

  This script intentionally does not run git pull, push, commit, clean, reset, merge,
  checkout, or fetch. Remote check uses git ls-remote so local refs and worktrees are
  not modified.
#>
[CmdletBinding()]
param(
  [string]$ConfigPath,
  [string]$ReportDirectory,
  [switch]$NoRemoteCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the script directory and default config path defensively. $PSScriptRoot
# can be empty in some -File invocation contexts, so fall back through
# $PSCommandPath, $MyInvocation, and the current location before joining names.
$scriptDirectory = $PSScriptRoot
if (-not $scriptDirectory -and $PSCommandPath) { $scriptDirectory = Split-Path -Parent $PSCommandPath }
if (-not $scriptDirectory -and $MyInvocation.MyCommand.Path) { $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDirectory) { $scriptDirectory = (Get-Location).Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $scriptDirectory 'repos.config.json' }

function ConvertTo-PlainPath {
  param([Parameter(Mandatory)][string]$Path)
  $trimmed = $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  # repoOverrides.pathPattern entries may contain wildcard characters, which
  # [System.IO.Path]::GetFullPath rejects on .NET Framework. Normalize separators
  # directly when wildcards are present so matching works across runtimes.
  if ($trimmed.IndexOfAny([char[]]@('*', '?')) -ge 0) {
    return ($trimmed -replace '/', '\')
  }
  return [System.IO.Path]::GetFullPath($trimmed)
}

function Invoke-Git {
  param(
    [Parameter(Mandatory)][string]$RepoPath,
    [Parameter(Mandatory)][string[]]$Arguments,
    [int]$TimeoutSeconds = 30
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = 'git'
  $psi.WorkingDirectory = $RepoPath
  foreach ($argument in $Arguments) {
    [void]$psi.ArgumentList.Add($argument)
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $process = [System.Diagnostics.Process]::Start($psi)
  if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    try { $process.Kill($true) } catch { $process.Kill() }
    return [pscustomobject]@{ ExitCode = 124; StdOut = ''; StdErr = "Timed out after $TimeoutSeconds seconds" }
  }

  return [pscustomobject]@{
    ExitCode = $process.ExitCode
    StdOut = $process.StandardOutput.ReadToEnd().Trim()
    StdErr = $process.StandardError.ReadToEnd().Trim()
  }
}

function Test-PathLike {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Pattern
  )
  return [WildcardPattern]::new((ConvertTo-PlainPath -Path $Pattern), [System.Management.Automation.WildcardOptions]::IgnoreCase).IsMatch((ConvertTo-PlainPath -Path $Path))
}

function Get-RepoOverride {
  param(
    [Parameter(Mandatory)][string]$RepoPath,
    [array]$Overrides
  )
  foreach ($override in @($Overrides)) {
    $propertyNames = @($override.PSObject.Properties.Name)
    if (($propertyNames -contains 'path') -and $override.path -and ((ConvertTo-PlainPath -Path $override.path) -ieq (ConvertTo-PlainPath -Path $RepoPath))) {
      return $override
    }
    if (($propertyNames -contains 'pathPattern') -and $override.pathPattern -and (Test-PathLike -Path $RepoPath -Pattern $override.pathPattern)) {
      return $override
    }
  }
  return $null
}

function Find-GitRepositories {
  param([Parameter(Mandatory)][array]$ScanRoots)

  $repos = [System.Collections.Generic.List[object]]::new()
  $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $missingRoots = [System.Collections.Generic.List[string]]::new()

  foreach ($root in $ScanRoots) {
    $rootPath = [string]$root.path
    if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
      [void]$missingRoots.Add($rootPath)
      continue
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath (Join-Path $rootPath '.git')) {
      [void]$candidates.Add($rootPath)
    }

    $gitDirs = Get-ChildItem -LiteralPath $rootPath -Force -Directory -Recurse:([bool]$root.recursive) -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq '.git' }
    foreach ($gitDir in $gitDirs) {
      [void]$candidates.Add($gitDir.Parent.FullName)
    }

    foreach ($candidate in $candidates) {
      $plain = ConvertTo-PlainPath -Path $candidate
      if ($seen.Add($plain)) {
        [void]$repos.Add([pscustomobject]@{ Path = $plain; DefaultCategory = [string]$root.defaultCategory })
      }
    }
  }

  return [pscustomobject]@{ Repositories = $repos; MissingRoots = $missingRoots }
}

function Get-GitRepositoryHealth {
  param(
    [Parameter(Mandatory)][string]$RepoPath,
    [Parameter(Mandatory)][string]$Category,
    [Parameter(Mandatory)]$Policy,
    [string[]]$Exemptions = @(),
    [bool]$RemoteCheckEnabled = $true,
    [int]$RemoteTimeoutSeconds = 15,
    [string]$Notes = ''
  )

  $issues = [System.Collections.Generic.List[object]]::new()
  $status = Invoke-Git -RepoPath $RepoPath -Arguments @('status', '--porcelain=v1', '--branch')
  if ($status.ExitCode -ne 0) {
    return [pscustomobject]@{
      path = $RepoPath; name = Split-Path -Leaf $RepoPath; category = $Category; severity = 'critical'
      branch = $null; upstream = $null; dirty = $null; ahead = $null; behind = $null
      fetchStatus = [pscustomobject]@{ status = 'not-run'; detail = 'git status failed before read-only fetch policy could be recorded.' }
      remoteCheck = [pscustomobject]@{ status = 'not-run'; detail = 'git status failed' }
      issues = @([pscustomobject]@{ code = 'git-status-failed'; severity = 'critical'; message = $status.StdErr })
      notes = $Notes
    }
  }

  $lines = @($status.StdOut -split "`r?`n" | Where-Object { $_ -ne '' })
  $branchLine = $lines | Where-Object { $_ -like '## *' } | Select-Object -First 1
  $dirtyLines = @($lines | Where-Object { $_ -notlike '## *' })
  $dirty = $dirtyLines.Count -gt 0

  $branch = $null
  $upstream = $null
  $ahead = 0
  $behind = 0
  if ($branchLine) {
    $branchText = $branchLine.Substring(3)
    if ($branchText -match '^(?<branch>.+?)(\.\.\.(?<upstream>[^\[]+))?( \[(?<meta>.+)\])?$') {
      $branch = $Matches.branch.Trim()
      if ($Matches.ContainsKey('upstream') -and $Matches.upstream) { $upstream = $Matches.upstream.Trim() }
      if ($Matches.ContainsKey('meta') -and $Matches.meta) {
        foreach ($part in ($Matches.meta -split ', ')) {
          if ($part -match '^ahead (?<count>\d+)$') { $ahead = [int]$Matches.count }
          if ($part -match '^behind (?<count>\d+)$') { $behind = [int]$Matches.count }
        }
      }
    } else {
      $branch = $branchText
    }
  }

  $policyExemptions = @()
  if ($Policy.PSObject.Properties.Name -contains 'exemptions') { $policyExemptions = @($Policy.exemptions) }
  $allExemptions = @($policyExemptions + $Exemptions) | Where-Object { $_ } | Select-Object -Unique

  if ($dirty -and ('dirty-tree' -notin $allExemptions)) {
    [void]$issues.Add([pscustomobject]@{ code = 'dirty-tree'; severity = [string]$Policy.dirtySeverity; message = "Working tree has $($dirtyLines.Count) changed path(s)." })
  }
  if (-not $upstream -and ('missing-upstream' -notin $allExemptions)) {
    [void]$issues.Add([pscustomobject]@{ code = 'missing-upstream'; severity = [string]$Policy.missingUpstreamSeverity; message = 'Current branch has no upstream tracking branch.' })
  }
  if ($ahead -gt 0) {
    [void]$issues.Add([pscustomobject]@{ code = 'ahead'; severity = [string]$Policy.aheadSeverity; message = "Local branch is ahead by $ahead commit(s)." })
  }
  if ($behind -ge [int]$Policy.behindCriticalThreshold) {
    [void]$issues.Add([pscustomobject]@{ code = 'behind'; severity = 'critical'; message = "Local branch is behind by $behind commit(s)." })
  } elseif ($behind -ge [int]$Policy.behindWarningThreshold) {
    [void]$issues.Add([pscustomobject]@{ code = 'behind'; severity = 'warning'; message = "Local branch is behind by $behind commit(s)." })
  }

  $fetchStatus = [pscustomobject]@{ status = 'not-performed'; detail = 'Read-only policy forbids git fetch; ahead/behind reflects existing local remote-tracking refs.' }
  $remoteCheck = [pscustomobject]@{ status = 'skipped'; detail = 'No upstream or disabled by policy.' }
  if ($RemoteCheckEnabled -and $upstream -and ('remote-check' -notin $allExemptions)) {
    $remoteName = ($upstream -split '/', 2)[0]
    $remote = Invoke-Git -RepoPath $RepoPath -Arguments @('ls-remote', '--exit-code', $remoteName, 'HEAD') -TimeoutSeconds $RemoteTimeoutSeconds
    if ($remote.ExitCode -eq 0) {
      $remoteCheck = [pscustomobject]@{ status = 'ok'; detail = "Read-only ls-remote succeeded for $remoteName." }
    } elseif ($remote.ExitCode -eq 124) {
      $remoteCheck = [pscustomobject]@{ status = 'timeout'; detail = $remote.StdErr }
      [void]$issues.Add([pscustomobject]@{ code = 'remote-check-timeout'; severity = 'warning'; message = "Remote check timed out for $remoteName." })
    } else {
      $remoteCheck = [pscustomobject]@{ status = 'failed'; detail = ($remote.StdErr + ' ' + $remote.StdOut).Trim() }
      [void]$issues.Add([pscustomobject]@{ code = 'remote-check-failed'; severity = 'warning'; message = "Read-only remote check failed for $remoteName." })
    }
  }

  $severityRank = @{ critical = 3; warning = 2; info = 1; ok = 0 }
  $severity = 'ok'
  foreach ($issue in $issues) {
    if ($severityRank[[string]$issue.severity] -gt $severityRank[$severity]) { $severity = [string]$issue.severity }
  }

  return [pscustomobject]@{
    path = $RepoPath
    name = Split-Path -Leaf $RepoPath
    category = $Category
    severity = $severity
    branch = $branch
    upstream = $upstream
    dirty = $dirty
    changedPathCount = $dirtyLines.Count
    ahead = $ahead
    behind = $behind
    fetchStatus = $fetchStatus
    remoteCheck = $remoteCheck
    exemptions = @($allExemptions)
    issues = @($issues)
    notes = $Notes
  }
}

function New-MarkdownReport {
  param([Parameter(Mandatory)]$Report)

  $lines = [System.Collections.Generic.List[string]]::new()
  [void]$lines.Add('# Repo Health Report')
  [void]$lines.Add('')
  [void]$lines.Add("Generated: $($Report.generatedAt)")
  [void]$lines.Add("Mode: read-only audit; no pull, push, commit, clean, reset, merge, checkout, or fetch operations are performed.")
  [void]$lines.Add('')
  [void]$lines.Add('## Summary')
  [void]$lines.Add('')
  [void]$lines.Add("- Repositories: $($Report.summary.total)")
  [void]$lines.Add("- Critical: $($Report.summary.critical)")
  [void]$lines.Add("- Warning: $($Report.summary.warning)")
  [void]$lines.Add("- Info: $($Report.summary.info)")
  [void]$lines.Add("- OK: $($Report.summary.ok)")
  if ($Report.missingRoots.Count -gt 0) {
    [void]$lines.Add("- Missing scan roots: $($Report.missingRoots.Count)")
  }
  [void]$lines.Add('')
  if (($Report.PSObject.Properties.Name -contains 'policyDecisions') -and (@($Report.policyDecisions).Count -gt 0)) {
    [void]$lines.Add('## Policy Decisions')
    [void]$lines.Add('')
    [void]$lines.Add('| Target | Category | Decision | Issue | Rationale |')
    [void]$lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($decision in $Report.policyDecisions) {
      [void]$lines.Add("| ``$($decision.target)`` | $($decision.category) | $($decision.decision) | $($decision.issue) | $($decision.rationale) |")
    }
    [void]$lines.Add('')
  }
  [void]$lines.Add('## Repo Table')
  [void]$lines.Add('')
  [void]$lines.Add('| Severity | Category | Repo | Branch | Upstream | Dirty | Ahead | Behind | Fetch | Remote | Notes |')
  [void]$lines.Add('| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- |')
  foreach ($repo in $Report.repositories) {
    $dirtyText = if ($repo.dirty) { "yes ($($repo.changedPathCount))" } else { 'no' }
    $notes = if ($repo.issues.Count -gt 0) { (($repo.issues | ForEach-Object { "$($_.code): $($_.message)" }) -join '<br>') } elseif ($repo.notes) { $repo.notes } else { '' }
    [void]$lines.Add("| $($repo.severity) | $($repo.category) | ``$($repo.path)`` | $($repo.branch) | $($repo.upstream) | $dirtyText | $($repo.ahead) | $($repo.behind) | $($repo.fetchStatus.status) | $($repo.remoteCheck.status) | $notes |")
  }
  [void]$lines.Add('')
  [void]$lines.Add('## Immediate Follow-up')
  [void]$lines.Add('')
  $followUps = @($Report.repositories | Where-Object { $_.severity -in @('critical', 'warning') } | Sort-Object @{ Expression = { if ($_.severity -eq 'critical') { 0 } else { 1 } } }, path)
  if ($followUps.Count -eq 0) {
    [void]$lines.Add('- No critical or warning follow-up detected.')
  } else {
    foreach ($repo in $followUps) {
      $issueText = ($repo.issues | ForEach-Object { "$($_.code) ($($_.severity))" }) -join ', '
      [void]$lines.Add("- [$($repo.severity)] ``$($repo.path)`` - $issueText")
    }
  }
  if ($Report.missingRoots.Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('## Missing Scan Roots')
    [void]$lines.Add('')
    foreach ($root in $Report.missingRoots) { [void]$lines.Add("- ``$root``") }
  }

  return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
  throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$reportDir = if ($ReportDirectory) { $ReportDirectory } elseif ($config.reports.directory) { [string]$config.reports.directory } else { Join-Path $scriptDirectory 'reports' }
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$scan = Find-GitRepositories -ScanRoots @($config.scanRoots)
$repoReports = [System.Collections.Generic.List[object]]::new()
foreach ($repo in $scan.Repositories) {
  $override = Get-RepoOverride -RepoPath $repo.Path -Overrides @($config.repoOverrides)
  $overrideProperties = if ($override) { @($override.PSObject.Properties.Name) } else { @() }
  $category = if ($override -and ($overrideProperties -contains 'category') -and $override.category) { [string]$override.category } else { [string]$repo.DefaultCategory }
  if (-not $category) { $category = 'product' }
  $policyProperty = $config.policies.PSObject.Properties[$category]
  if (-not $policyProperty) { throw "Policy not found for category '$category'" }
  $policy = $policyProperty.Value
  $exemptions = if ($override -and ($overrideProperties -contains 'exemptions')) { @($override.exemptions) } else { @() }
  $notes = if ($override -and ($overrideProperties -contains 'notes') -and $override.notes) { [string]$override.notes } else { '' }
  $remoteEnabled = [bool]$config.remoteCheck.enabled -and (-not $NoRemoteCheck)
  [void]$repoReports.Add((Get-GitRepositoryHealth -RepoPath $repo.Path -Category $category -Policy $policy -Exemptions $exemptions -RemoteCheckEnabled $remoteEnabled -RemoteTimeoutSeconds ([int]$config.remoteCheck.timeoutSeconds) -Notes $notes))
}

$summary = [pscustomobject]@{
  total = $repoReports.Count
  critical = @($repoReports | Where-Object severity -eq 'critical').Count
  warning = @($repoReports | Where-Object severity -eq 'warning').Count
  info = @($repoReports | Where-Object severity -eq 'info').Count
  ok = @($repoReports | Where-Object severity -eq 'ok').Count
}

$report = [pscustomobject]@{
  generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
  script = $PSCommandPath
  config = (ConvertTo-PlainPath -Path $ConfigPath)
  mode = 'read-only'
  prohibitedOperations = @('pull', 'push', 'commit', 'clean', 'reset', 'merge', 'checkout', 'fetch')
  fetchStatusMode = 'not-performed-read-only'
  remoteCheckMode = if ($NoRemoteCheck) { 'disabled' } else { [string]$config.remoteCheck.mode }
  scanRoots = @($config.scanRoots)
  missingRoots = @($scan.MissingRoots)
  policyDecisions = if ($config.PSObject.Properties.Name -contains 'policyDecisions') { @($config.policyDecisions) } else { @() }
  summary = $summary
  repositories = @($repoReports | Sort-Object severity, path)
}

$jsonPath = Join-Path $reportDir ([string]$config.reports.jsonFile)
$markdownPath = Join-Path $reportDir ([string]$config.reports.markdownFile)
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
New-MarkdownReport -Report $report | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Host "Repo health audit complete."
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $markdownPath"
Write-Host "Repositories: $($summary.total); critical=$($summary.critical); warning=$($summary.warning); info=$($summary.info); ok=$($summary.ok)"
