#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — diagnostics
# ==============================================================================
#  Read-only. Collects the facts needed to debug an install, theme switch or
#  boot problem: system, git revision, XDG paths, theme/plugin state, timers,
#  boot time and the theme's recent journal lines.
#
#  Usage:
#    vp-diagnose.sh                 print the report
#    vp-diagnose.sh --output FILE   also write it to FILE
#    vp-diagnose.sh --upload        ask, then upload to https://0x0.st
#
#  It never writes to the configuration and never needs sudo.
# ==============================================================================

set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
SELF_DIR="$(dirname "$SELF")"
REPO_DIR="$(cd "$SELF_DIR/.." && pwd)"

OUTPUT=""
UPLOAD=0
case "${1:-}" in
  -h | --help)
    sed -n '2,18p' "$SELF" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --output)
    OUTPUT="${2:-}"
    [[ -n $OUTPUT ]] || { echo "vp-diagnose: --output needs a path" >&2; exit 2; }
    ;;
  --upload) UPLOAD=1 ;;
  "") ;;
  *)
    echo "vp-diagnose: unknown option: $1" >&2
    exit 2
    ;;
esac

# Omarchy resolves its own paths; reuse the shared helper when present.
for _env in "$REPO_DIR/lib/omarchy-env.sh" \
            "$HOME/.local/share/virtual-paradise/omarchy-env.sh"; do
  if [[ -f $_env ]]; then
    # shellcheck disable=SC1090
    . "$_env"
    omarchy_export_env
    break
  fi
done
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
unset _env

REPORT="$(mktemp)"
trap 'rm -f "$REPORT"' EXIT

section() {
  printf '\n[=== %s ===]\n' "$*" | tee -a "$REPORT"
}

run() {
  printf '$ %s\n' "$*" | tee -a "$REPORT"
  "$@" 2>&1 | tee -a "$REPORT"
  local rc=${PIPESTATUS[0]}
  printf '[exit %s]\n' "$rc" | tee -a "$REPORT"
}

have() { command -v "$1" >/dev/null 2>&1; }

section "System"
{
  date
  uname -a
  [[ -r /etc/os-release ]] && grep -E '^(NAME|PRETTY_NAME|ID|ID_LIKE|VERSION_ID)=' /etc/os-release
  printf 'session: %s\n' "${XDG_SESSION_TYPE:-unknown}"
  have Hyprland && Hyprland --version | head -1
  if have quickshell; then quickshell --version 2>&1 | head -1; fi
  if [[ -x /usr/lib/qt6/bin/qmllint ]]; then /usr/lib/qt6/bin/qmllint --version 2>&1 | head -1; fi
} | tee -a "$REPORT"

section "Theme repository"
{
  printf 'path: %s\n' "$REPO_DIR"
  [[ -f "$REPO_DIR/VERSION" ]] && grep -m1 '^[0-9]' "$REPO_DIR/VERSION"
  if have git && [[ -d "$REPO_DIR/.git" ]]; then
    printf 'remote: %s\n' "$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo none)"
    printf 'head:   %s\n' "$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo none)"
    printf 'branch: %s\n' "$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"
    printf 'tag:    %s\n' "$(git -C "$REPO_DIR" describe --tags --exact-match 2>/dev/null || echo none)"
    git -C "$REPO_DIR" status --short 2>&1
  fi
} | tee -a "$REPORT"

section "XDG paths"
{
  for v in XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR; do
    printf '%-16s %s\n' "$v" "${!v:-<unset>}"
  done
} | tee -a "$REPORT"

section "Installed state"
{
  printf 'theme: %s\n' "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme.name" 2>/dev/null || echo none)"
  cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
  [[ -d "$cfg/omarchy/themes/virtual-paradise" ]] \
    && printf 'theme payload: present (%s files)\n' "$(find "$cfg/omarchy/themes/virtual-paradise" -type f 2>/dev/null | wc -l)" \
    || printf 'theme payload: missing\n'
  [[ -f "$cfg/omarchy/shell.json" ]] \
    && printf 'shell.json bar: %s\n' "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("bar",{}).get("id","?"))' "$cfg/omarchy/shell.json" 2>/dev/null || echo unreadable)"
  state="${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise"
  printf 'override rows: %s\n' "$(grep -c . "$state/overrides.state" 2>/dev/null || echo 0)"
  printf 'pinned plugins: %s\n' "$(grep -c . "$state/plugin-versions.lock" 2>/dev/null || echo 0)"
  if have omarchy; then
    omarchy plugin list --json 2>/dev/null \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print("plugins: %d (%d enabled)" % (len(d), sum(1 for p in d if p.get("enabled"))))' 2>/dev/null \
      || printf 'plugins: unreadable\n'
  fi
} | tee -a "$REPORT"

section "Plugin pin drift"
if have "$HOME/.local/bin/paradise-plugin-update"; then
  "$HOME/.local/bin/paradise-plugin-update" --verify 2>&1 | tee -a "$REPORT"
elif [[ -x "$REPO_DIR/bin/update-plugins.sh" ]]; then
  "$REPO_DIR/bin/update-plugins.sh" --verify 2>&1 | tee -a "$REPORT"
else
  echo "update-plugins.sh not found" | tee -a "$REPORT"
fi

section "Services and boot"
{
  systemctl --user list-timers --all --no-pager 2>/dev/null | grep -E 'paradise|NEXT' | head -8
  if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/plymouth/plymouthd.conf" ]]; then
    grep -E '^Theme' "${XDG_CONFIG_HOME:-$HOME/.config}/plymouth/plymouthd.conf" 2>/dev/null
  fi
  systemd-analyze time 2>/dev/null
} | tee -a "$REPORT"

section "Recent theme log"
journalctl --user -b --no-pager 2>/dev/null \
  | grep -iE 'virtual.?paradise|doe\.|omarchy-shell' \
  | grep -iE 'error|warn|typeerror|binding loop' \
  | tail -40 | tee -a "$REPORT"

echo
echo "Report saved to: $REPORT"

if [[ -n $OUTPUT ]]; then
  cp "$REPORT" "$OUTPUT" && echo "Copied to: $OUTPUT"
fi

if [[ $UPLOAD -eq 1 ]]; then
  if ! have curl; then
    echo "curl not found; cannot upload." >&2
    exit 0
  fi
  echo
  echo "The report will be uploaded to https://0x0.st (public, expires in ~15 days)."
  echo "Review it first: $REPORT"
  printf 'Upload? [y/N] '
  read -r answer
  case "$answer" in
    [yY])
      url="$(curl -fsS -F "file=@$REPORT" -F expires=360 https://0x0.st 2>/dev/null || true)"
      if [[ -n $url ]]; then
        echo "Uploaded: $url"
      else
        echo "Upload failed." >&2
      fi
      ;;
    *) echo "Upload skipped." ;;
  esac
fi
