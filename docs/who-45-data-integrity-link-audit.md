# WHO-45 — 資料完整性與路徑斷鏈驗證

> Scope：S8-03 驗證資料完整性與路徑斷鏈。  
> Date：2026-06-24。  
> Environment：Codex session in `/workspace/Whoasked`（Linux-native runtime）。

## 0. 驗證邊界

本次驗證先在目前可存取的 repo workspace 內執行，不直接掃描或索引 secrets，也不把缺少本機掛載誤判為資料遺失。

### 可直接驗證

- `/workspace/Whoasked` repo 內文件、腳本、設定與既有報告。
- repo 內對 Windows / VPS / gateway / cloudflared / repo-health 的路徑引用。
- repo 內已記錄的 duplicate / mirror / local-only policy。

### 無法直接驗證，需在 Windows 本機補跑

- `D:\Agent-KB\DAILY\RECENT.md`
- `D:\Agent-KB\DAILY\LEARNINGS.md`
- `D:\Agent-KB\RULES.md`
- `D:\Agent-KB\PLAYBOOKS\AGENT-SKILLS-SCAN-MAP.md`
- `D:\Obsidian\EdgarsObsidianVault`
- `D:\01_projects_staging\龍蝦專案`
- `G:\AI_WORK_512`
- `G:\AI-Cache`

在本 session 中，上述 `D:` orientation files 對應的 `/mnt/d/...` 路徑均為 Missing；這代表「目前 runtime 未掛載或不可見」，不等於 Windows 本機資料遺失。

## 1. 正式工作資料檢查（W1）

| Target | Evidence in repo | Status | Issue type | Notes |
| --- | --- | --- | --- | --- |
| `Projects\rebuild` | `Automation/repo-health/repos.config.json` policy decision | Present in baseline policy | None in repo scope | 已標為 product，expected upstream 是 `origin/codex/agent-git-pr-rule`。 |
| `workspace-lobster` | `Automation/repo-health/repos.config.json` policy decision | Present in baseline policy | None in repo scope | 已決議 local-only；不應被誤判為 missing upstream。 |
| `.openclaw\workspace\main` | `Automation/repo-health/repos.config.json` policy decision | Present in baseline policy | None in repo scope | 已決議 local-only。 |
| `openclaw-google-workspace` | `Automation/repo-health/repos.config.json` policy decision | Present in baseline policy | None in repo scope | 已決議 remote 未核准前維持 local-only。 |
| `haodai-linebot` | `Automation/repo-health/reports/repo-health-latest.md` | Present in baseline report | Follow-up | baseline 顯示 behind 22 commits，屬 repo health 後續處理，不是資料遺失。 |

## 2. 知識與資料區檢查（W2）

| Target | Current session result | Status | Issue type | Required follow-up |
| --- | --- | --- | --- | --- |
| `D:\Agent-KB` orientation files | `/mnt/d/...` all Missing | Not verifiable here | Missing / unknown | 回 Windows 本機確認 D: 掛載與檔案存在性。 |
| `D:\Obsidian\EdgarsObsidianVault` | Not mounted in this runtime | Not verifiable here | Missing / unknown | 回 Windows 本機檢查 vault root、主要 index、常用筆記入口。 |
| `D:\01_projects_staging\龍蝦專案` | Not mounted in this runtime | Not verifiable here | Missing / unknown | 回 Windows 本機檢查 OpenClaw / Hermes / Lobster workspace 實際路徑。 |
| `G:\AI_WORK_512` | Not mounted in this runtime | Not verifiable here | Missing / unknown | 回 Windows 本機確認 heavy AI storage 是否仍可讀。 |
| `G:\AI-Cache` | Not mounted in this runtime | Not verifiable here | Missing / unknown | 回 Windows 本機確認 cache root 是否存在；不要視為永久知識庫。 |

## 3. 常用路徑、腳本、引用檢查（W3 / W4）

### Repo 內現有引用

| File | Referenced path / endpoint | Status | Issue type | Notes |
| --- | --- | --- | --- | --- |
| `scripts/fix-who150-gateway-cloudflared.ps1` | `C:\Users\EdgarsTool\Projects\openclaw-workspace` | Needs Windows verification | Broken link / old path candidate | Current terrain 指定 `D:\01_projects_staging\龍蝦專案` 為 OpenClaw / Hermes / 龍蝦工作區；此 `C:` path 可能是舊位置或 fallback。 |
| `docs/who-150-runbook.md` | `C:\Users\EdgarsTool\Projects\openclaw-workspace\start-gateway-local.ps1` | Needs Windows verification | Broken link / old path candidate | 文件與腳本一致，但和新地形不一致。需確認實際 gateway 啟動腳本是否已搬到 D:。 |
| `Automation/repo-health/repos.config.json` | `C:\Users\EdgarsTool\Projects` and `C:\Users\EdgarsTool\.openclaw` | Baseline config | Misplaced / old path candidate | WHO-124 baseline 仍掃 C: 舊 workspace；若 workspace 已正式搬到 D:，需補新版 scanRoots。 |
| `Automation/repo-health/reports/repo-health-latest.md` | C: repo paths | Baseline artifact | Stale reference | 報告日期為 2026-04-27，應回 Windows 重跑以取得搬遷後 fresh report。 |
| `docs/02-directory-structure.md` | `/opt/edgar/repos`, `/opt/edgar/runtime`, `/opt/edgar/backups`, `/opt/edgar/logs` | Current VPS docs | None | VPS safe-zone 文件與 Windows D/G 地形是不同主題，不視為斷鏈。 |

### 建議的 Windows 補跑命令

在 Windows PowerShell 回到 repo 後執行：

```powershell
# 檢查 orientation files 是否存在
$Required = @(
  'D:\Agent-KB\DAILY\RECENT.md',
  'D:\Agent-KB\DAILY\LEARNINGS.md',
  'D:\Agent-KB\RULES.md',
  'D:\Agent-KB\PLAYBOOKS\AGENT-SKILLS-SCAN-MAP.md'
)
$Required | ForEach-Object { [pscustomobject]@{ Path = $_; Exists = Test-Path -LiteralPath $_ } }

# 掃描 repo 內舊 C: 引用
rg -n 'C:\\Users\\EdgarsTool|D:\\|G:\\|openclaw-workspace|Agent-KB|Edgars_secret' .

# 重新產 repo health report（read-only）
powershell -ExecutionPolicy Bypass -File .\Automation\repo-health\audit-repos.ps1 -NoRemoteCheck
```

## 4. 重複副本與多版本殘留（W5）

| Duplicate / mirror candidate | Canonical / decision | Status | Issue type | Notes |
| --- | --- | --- | --- | --- |
| `.openclaw\extensions\ai-agent-console` | Canonical is `Projects\ai-agent-console` | Marked mirror | Duplicate | 已在 repo-health policy 中標記 mirror-only，不應作為 primary。 |
| duplicate clones | Canonical working copy only | Policy exists | Duplicate | 已有通用決策：canonical working copy 才是 primary。 |
| `workspace-lobster` | local-only | Policy exists | Multi-version risk | local-only 不是 duplicate 本身，但若 D: 有新位置，需確認 C: 舊副本是否退場或標為 mirror。 |
| `openclaw-google-workspace` | local-only until remote approved | Policy exists | Multi-version risk | 若搬遷後存在 D: 與 C: 雙副本，需補 canonical/mirror 標記。 |

## 5. 四類問題清單

### Missing（遺失 / 未可見）

- `D:\Agent-KB` orientation files 在本 session 的 `/mnt/d/...` 不可見；需於 Windows 本機確認。
- `D:\Obsidian\EdgarsObsidianVault`、`D:\01_projects_staging\龍蝦專案`、`G:\AI_WORK_512`、`G:\AI-Cache` 未掛載於本 runtime；狀態 Unknown。

### Duplicate（重複副本 / 多版本殘留）

- `.openclaw\extensions\ai-agent-console` 已標記為 mirror，canonical 是 `Projects\ai-agent-console`。
- `duplicate clones` 已有 policy decision，但需要搬遷後 fresh Windows scan 重新確認是否還有 C:/D: 雙副本。

### Broken link（斷鏈 / 舊引用）

- `scripts/fix-who150-gateway-cloudflared.ps1` 與 `docs/who-150-runbook.md` 仍引用 `C:\Users\EdgarsTool\Projects\openclaw-workspace`；和目前 D: 新地形不一致，需 Windows 本機確認是否已斷。
- `Automation/repo-health/repos.config.json` scanRoots 仍以 `C:\Users\EdgarsTool\Projects` / `.openclaw` 為主；若資料主場已搬到 D:，需新增或切換 scan roots。

### Misplaced（誤放 / 分層不符）

- repo-health baseline 仍以 C: 作為工作資料掃描主場；若 Workspace rebuilt 已完成，這可能代表 audit config 落後於新地形。
- gateway 啟動腳本 default path 位於 C:；若 Gateway 現在屬 D: `龍蝦專案`，應避免長期把 C: 當 AI 工作主場。

## 6. 後續清理與修正依據

1. 回 Windows 本機先確認 D:/G: 實體路徑存在性，再判定 Missing 是否成立。
2. 針對 repo-health：新增搬遷後 scanRoots 或另建 migration-aware config，保留 C: baseline 但不要把它當 fresh state。
3. 針對 gateway：確認 `start-gateway-local.ps1` 的正式位置；若已搬到 D:，更新 script default 與 runbook。
4. 針對 duplicate：重新跑 repo-health 後，把 C: 舊副本標為 mirror / deprecated，或在確認後清理；清理前不可刪除。
5. 將本文件結果交給 WHO-47 rollback / recovery 文件，作為「哪些路徑仍需驗證、哪些引用可能斷」的輸入。
