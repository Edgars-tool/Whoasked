# Whoasked — VPS Visual Workspace Bridge

Scripts and documentation for safely bridging Windows desktop tools (WinSCP, VSCode Remote, Codex Remote) to the Oracle VPS.

## Quick Start

```bash
# On the VPS — create the safe-zone directory structure
sudo ./scripts/init-vps-dirs.sh
```

## Directory Layout

```
/opt/edgar/
  repos/      ← git clones, safe for remote editing
  runtime/    ← Docker state / databases (do NOT mount as edit target)
  backups/    ← scheduled & manual backups
  logs/       ← application & service logs
```

See [`docs/02-directory-structure.md`](docs/02-directory-structure.md) for the full permission strategy and visual-operability matrix.

## Docs

| Doc | Description |
|---|---|
| `01-connection-config.md` | VPS connection baseline (WHO-216)（文件尚未加入 repo）|
| [`02-directory-structure.md`](docs/02-directory-structure.md) | Safe-zone dirs & permissions (WHO-217) |
| [`who-97-cache-trace-rotation.md`](docs/who-97-cache-trace-rotation.md) | `cache-trace.jsonl` rotation / archive runbook (WHO-97) |
| [`who-210-e2e-webhook-runbook.md`](docs/who-210-e2e-webhook-runbook.md) | Linear webhook → Hermes processing → Linear comment E2E test runbook (WHO-210 / EDG-108) |
