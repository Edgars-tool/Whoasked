# Repo Health Report

Generated: 2026-04-27 00:02:17 +08:00
Mode: read-only audit; no pull, push, commit, clean, reset, merge, checkout, or fetch operations are performed.

## Summary

- Repositories: 20
- Critical: 1
- Warning: 16
- Info: 3
- OK: 0

## Repo Table

| Severity | Category | Repo | Branch | Upstream | Dirty | Ahead | Behind | Fetch | Remote | Notes |
| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- | --- |
| critical | product | `C:\Users\EdgarsTool\Projects\haodai-linebot` | main | origin/main | no | 0 | 22 | not-performed | ok | behind: Local branch is behind by 22 commit(s). |
| warning | product/workspace | baseline aggregate | varies | varies | varies | varies | varies | not-performed | varies | 16 warning repos recorded in WHO-122 baseline evidence; rerun on Windows to regenerate full row-level details. |
| info | workspace/local-only | baseline aggregate | varies | varies | varies | varies | varies | not-performed | varies | 3 info repos recorded in WHO-122 baseline evidence; rerun on Windows to regenerate full row-level details. |

## Immediate Follow-up

- [critical] `C:\Users\EdgarsTool\Projects\haodai-linebot` — behind (critical), local branch is behind by 22 commit(s).
- Review warning repos after critical behind state is resolved; `.openclaw` family noise should be interpreted through the workspace exemption policy.

## Baseline Evidence

- Latest verified run: 2026-04-27 00:02:17 +08:00
- Baseline counts from WHO-122: repo=20, critical=1, warning=16, info=3
- This checked-in report is a baseline artifact. Running `audit-repos.ps1` on Edgar's Windows machine regenerates complete JSON and Markdown reports.
