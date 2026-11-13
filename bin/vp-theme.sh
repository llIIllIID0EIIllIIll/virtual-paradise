#!/usr/bin/env bash
# ==============================================================================
#  Virtual☆Paradise — portable custom themes
# ==============================================================================
#  Usage:
#    vp-theme.sh save [name]          # save the live palette (auto name if omitted)
#    vp-theme.sh list                 # one saved theme per line
#    vp-theme.sh load <name>          # apply a saved palette, no shell restart
#    vp-theme.sh export <name> <path> # copy the JSON somewhere portable
#    vp-theme.sh export-current <path> [name]  # write the live palette directly
#    vp-theme.sh import <path> [name] # validate and add a JSON palette
#    vp-theme.sh delete <name>        # remove a saved palette
# ==============================================================================

set -euo pipefail

STATE="$HOME/.local/state/virtual-paradise"
THEMES="$STATE/themes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '4,14p' "$0" | sed 's/^#  //'
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

theme_path() {
  local slug
  slug="$(slugify "$1")"
  [[ -n $slug ]] || {
    echo "Invalid theme name." >&2
    exit 2
  }
  printf '%s/%s.json\n' "$THEMES" "$slug"
}

require_theme() {
  local path
  path="$(theme_path "$1")"
  [[ -f $path ]] || {
    echo "No saved theme: $1" >&2
    exit 1
  }
  printf '%s\n' "$path"
}

save_theme() {
  local name="${1:-}" slug path
  if [[ -z $name ]]; then
    name="custom-$(date +%Y%m%d-%H%M%S)"
  fi
  slug="$(slugify "$name")"
  [[ -n $slug ]] || {
    echo "Invalid theme name." >&2
    exit 2
  }
  mkdir -p "$THEMES"
  path="$THEMES/$slug.json"
  [[ -f "$STATE/palette.json" ]] || {
    echo "No live palette yet. Pick a custom color first." >&2
    exit 1
  }

  flock -s "$STATE/palette.lock" python3 - "$STATE/palette.json" "$path" "$name" <<'PY'
import datetime
import json
import os
import sys
import tempfile

source, dest, name = sys.argv[1:4]
roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(source, encoding="utf-8"))
colors = {}
for role in roles:
    value = data.get(role)
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        raise SystemExit(f"palette.json has no valid {role}")
    if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
        raise SystemExit(f"palette.json has an invalid {role}: {value}")
    colors[role] = value.lower()

out = {
    "schemaVersion": 1,
    "name": name,
    "savedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "colors": colors,
}
fd, tmp = tempfile.mkstemp(prefix=".theme.", suffix=".tmp", dir=os.path.dirname(dest))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, dest)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print(dest)
PY
}

load_theme() {
  local path
  path="$(require_theme "${1:-}")"
  local -a colors=()
  while IFS= read -r value; do
    colors+=("$value")
  done < <(python3 - "$path" <<'PY'
import json
import sys

roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(sys.argv[1], encoding="utf-8"))
colors = data.get("colors", {})
for role in roles:
    value = colors.get(role)
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        raise SystemExit(f"saved theme has no valid {role}")
    if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
        raise SystemExit(f"saved theme has an invalid {role}: {value}")
    print(value[1:])
PY
)
  [[ ${#colors[@]} -eq 8 ]] || {
    echo "Saved theme is incomplete." >&2
    exit 1
  }
  "$SCRIPT_DIR/theme-switcher.sh" custom "${colors[@]}"
}

export_current() {
  local dest="${1:-}" name="${2:-}"
  [[ -n $dest ]] || {
    echo "Usage: vp-theme.sh export-current <path> [name]" >&2
    exit 2
  }
  [[ -f "$STATE/palette.json" ]] || {
    echo "No live palette yet. Pick a custom color first." >&2
    exit 1
  }
  [[ -n $name ]] || name="$(basename "$dest" .json)"
  mkdir -p "$(dirname "$dest")"
  flock -s "$STATE/palette.lock" python3 - "$STATE/palette.json" "$dest" "$name" <<'PY'
import datetime
import json
import os
import sys
import tempfile

source, dest, name = sys.argv[1:4]
roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(source, encoding="utf-8"))
colors = {}
for role in roles:
    value = data.get(role)
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        raise SystemExit(f"palette.json has no valid {role}")
    if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
        raise SystemExit(f"palette.json has an invalid {role}: {value}")
    colors[role] = value.lower()

out = {
    "schemaVersion": 1,
    "name": name,
    "savedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "colors": colors,
}
fd, tmp = tempfile.mkstemp(prefix=".theme.", suffix=".tmp", dir=os.path.dirname(dest))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, dest)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print(dest)
PY
}

list_themes() {
  [[ -d $THEMES ]] || return 0
  find "$THEMES" -maxdepth 1 -type f -name '*.json' -printf '%f\n' \
    | sed 's/\.json$//' | sort
}

export_theme() {
  local name="${1:-}" dest="${2:-}" path
  [[ -n $dest ]] || {
    echo "Usage: vp-theme.sh export <name> <path>" >&2
    exit 2
  }
  path="$(require_theme "$name")"
  cp -f "$path" "$dest"
  printf '%s\n' "$dest"
}

import_theme() {
  local source="${1:-}" name="${2:-}" slug path
  [[ -f $source ]] || {
    echo "No such theme file: $source" >&2
    exit 1
  }
  if [[ -z $name ]]; then
    name="$(basename "$source" .json)"
  fi
  slug="$(slugify "$name")"
  [[ -n $slug ]] || {
    echo "Invalid theme name." >&2
    exit 2
  }
  mkdir -p "$THEMES"
  path="$THEMES/$slug.json"

  python3 - "$source" "$path" "$name" <<'PY'
import datetime
import json
import os
import sys
import tempfile

source, dest, name = sys.argv[1:4]
roles = ("accent", "secondary", "tertiary", "warm", "pink", "hot", "background", "foreground")
data = json.load(open(source, encoding="utf-8"))
colors = data.get("colors", data)
if not isinstance(colors, dict):
    raise SystemExit("theme file has no colors object")
clean = {}
for role in roles:
    value = colors.get(role)
    if not isinstance(value, str) or len(value) != 7 or value[0] != "#":
        raise SystemExit(f"theme file has no valid {role}")
    if any(c not in "0123456789abcdefABCDEF" for c in value[1:]):
        raise SystemExit(f"theme file has an invalid {role}: {value}")
    clean[role] = value.lower()

out = {
    "schemaVersion": 1,
    "name": name,
    "savedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "colors": clean,
}
fd, tmp = tempfile.mkstemp(prefix=".theme.", suffix=".tmp", dir=os.path.dirname(dest))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(out, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, dest)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
print(dest)
PY
}

delete_theme() {
  local path
  path="$(require_theme "${1:-}")"
  rm -f "$path"
  printf 'Deleted %s\n' "$path"
}

case "${1:-}" in
  save) save_theme "${2:-}" ;;
  list) list_themes ;;
  load) load_theme "${2:-}" ;;
  export) export_theme "${2:-}" "${3:-}" ;;
  export-current) export_current "${2:-}" "${3:-}" ;;
  import) import_theme "${2:-}" "${3:-}" ;;
  delete) delete_theme "${2:-}" ;;
  ""|-h|--help) usage ;;
  *)
    echo "Unknown action: $1" >&2
    usage >&2
    exit 2
    ;;
esac
