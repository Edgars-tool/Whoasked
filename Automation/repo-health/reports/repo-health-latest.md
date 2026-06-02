# Repo Health Report

Generated: 2026-04-27 00:02:17 +08:00
Mode: read-only audit; no pull, push, commit, clean, reset, merge, checkout, or fetch operations are performed.

## Summary

- Repositories: 20
- Critical: 1
- Warning: 16
- Info: 3
- OK: 0

## Policy Decisions

| Target | Category | Decision | Issue | Rationale |
| --- | --- | --- | --- | --- |
| `Projects\rebuild` | product | track upstream origin/codex/agent-git-pr-rule | WHO-124 | Active dev branch; upstream backfilled so the audit no longer flags missing-upstream. |
| `workspace-lobster` | local-only | local-only; no remote tracking required | WHO-124 | Final decision: not promoted to a remote tracking branch until Edgar approves a remote. |
| `.openclaw\workspace\main` | local-only | local-only | WHO-124 | Intentional local-only workspace; missing-upstream is expected. |
| `openclaw-google-workspace` | local-only | local-only until remote approved | WHO-124 | No remote until Edgar approves; treated as intentional local-only. |
| `.openclaw\extensions\ai-agent-console` | mirror | mirror-only; canonical is Projects\ai-agent-console | WHO-124 | Duplicate clone; the canonical working copy is Projects\ai-agent-console. |
| `duplicate clones` | mirror | canonical working copy is the only primary; mirror-tagged duplicates stay mirror-only | WHO-124 | Avoid re-judging duplicate working copies on every audit. |
| `workspace severity thresholds` | workspace | keep warning=5, critical=25 | WHO-124 | No further tuning until a fresh Windows report shows the threshold is still too noisy. |

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
