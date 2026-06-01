#!/usr/bin/env bash
# WHO-217: Initialise /opt/edgar safe-zone directory structure on the VPS.
# Idempotent — safe to re-run.
set -euo pipefail

# ---------- configuration ----------
BASE="/opt/edgar"
# VPS_USER: the unprivileged user that remote editors (WinSCP / VSCode Remote /
# Codex Remote) will SSH in as. Override via env var if the username differs.
VPS_USER="${VPS_USER:-edgar}"

# ---------- colour helpers ----------
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
info()  { printf '  -> %s\n' "$*"; }

# ---------- pre-flight ----------
if [[ $EUID -ne 0 ]]; then
  red "This script must be run as root (or via sudo)."
  exit 1
fi

if ! id "$VPS_USER" &>/dev/null; then
  red "User '$VPS_USER' does not exist. Create it first or set VPS_USER."
  exit 1
fi

VPS_GROUP="$(id -gn "$VPS_USER")"

# ---------- create directories ----------
green "Creating $BASE directory tree ..."

#  repos     — git clones, editable via WinSCP / VSCode / Codex
#  runtime   — Docker volumes, databases, state files (hands-off)
#  backups   — scheduled / manual backups
#  logs      — application & service logs
declare -A DIRS=(
  [repos]="0755"
  [runtime]="0750"
  [backups]="0750"
  [logs]="0755"
)

for dir in "${!DIRS[@]}"; do
  target="$BASE/$dir"
  mode="${DIRS[$dir]}"
  mkdir -p "$target"
  chown "$VPS_USER:$VPS_GROUP" "$target"
  chmod "$mode" "$target"
  info "$target  owner=$VPS_USER  mode=$mode"
done

# ---------- sticky-group on repos so new files keep the group ----------
chmod g+s "$BASE/repos"
info "$BASE/repos  setgid bit applied"

# ---------- protect runtime from casual browsing ----------
# A .no-visual-edit marker file signals to editors / mount scripts
# that this tree should not be a primary mount target.
touch "$BASE/runtime/.no-visual-edit"
chown "$VPS_USER:$VPS_GROUP" "$BASE/runtime/.no-visual-edit"
info "$BASE/runtime/.no-visual-edit  marker created"

# ---------- summary ----------
echo ""
green "Done. Directory layout:"
ls -la "$BASE"
echo ""
green "Visual-edit safe paths:"
info "$BASE/repos   (WinSCP / VSCode Remote / Codex Remote OK)"
info "$BASE/logs    (read-only browsing OK)"
echo ""
green "Restricted paths (do NOT mount as primary edit target):"
info "$BASE/runtime (Docker state / databases — view only)"
info "$BASE/backups (backup storage — view only)"
