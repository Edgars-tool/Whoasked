# Repo Health Audit

Read-only Git repository audit for Edgar's Windows workspaces. It scans the
configured roots, applies category/exemption policy, and writes stable JSON and
Markdown reports. It never runs `pull`, `push`, `commit`, `clean`, `reset`,
`merge`, `checkout`, or `fetch`; remote reachability uses `git ls-remote`.

## Run

```powershell
powershell -ExecutionPolicy Bypass -File .\audit-repos.ps1
```

Optional parameters:

- `-ConfigPath <path>` — config file (defaults to `repos.config.json` next to the script).
- `-ReportDirectory <path>` — overrides `reports.directory` from the config.
- `-NoRemoteCheck` — skip the read-only `ls-remote` reachability probe.

Reports are written to `reports/repo-health-latest.json` and
`reports/repo-health-latest.md`.

## Policy model

`repos.config.json` defines:

- `scanRoots` — directories scanned for `.git` working copies.
- `policies` — per-category severity rules (`product`, `workspace`, `local-only`,
  `mirror`).
- `repoOverrides` — per-repo `path` (exact) or `pathPattern` (wildcard) entries
  that pin a category, exemptions, and notes. More specific overrides must come
  **before** broader `pathPattern` entries because the first match wins.
- `policyDecisions` — WHO-124 decision log, surfaced in both reports.

## WHO-124 decisions

| Target | Category | Decision |
| --- | --- | --- |
| `Projects\rebuild` | product | Track upstream `origin/codex/agent-git-pr-rule`. |
| `workspace-lobster` | local-only | Local-only; no remote tracking until a remote is approved. |
| `.openclaw\workspace\main` | local-only | Local-only; missing upstream expected. |
| `openclaw-google-workspace` | local-only | Local-only until a remote is approved. |
| `.openclaw\extensions\ai-agent-console` | mirror | Mirror-only; canonical copy is `Projects\ai-agent-console`. |
| duplicate clones | mirror | Only the canonical working copy is primary; mirror-tagged duplicates stay mirror-only. |
| workspace thresholds | workspace | Keep `warning=5`, `critical=25` until a fresh Windows report shows it is still too noisy. |

These decisions are encoded in `repos.config.json` (`repoOverrides` +
`policyDecisions`) so future audits do not need to re-judge each exception.
