#!/usr/bin/env bash
# Virtual☆Paradise — ownership rules for ~/.config/omarchy/shell.json.
#
# The theme ships a bar layout (shell-paradise.json), but the live shell.json
# belongs to the user. Re-applying the theme on every login used to overwrite
# any layout change the user had made, and leaving the theme overwrote it again
# with the stock layout. Both directions now use a three-way comparison:
#
#   shell-default.json   pristine Omarchy layout, snapshotted once
#   shell-paradise.json  the layout this theme wants
#   shell-layout.applied.json  the last layout this theme actually installed
#   shell.json           the live layout
#
# Apply only when the live file is missing, still the stock default, still the
# previous theme layout, or still the last layout we applied. A file that
# differs from all of those is a user edit and is never overwritten unless the
# caller passes force=1 (install.sh --force-shell-layout). Comparisons use the
# `bar` subtree only; runtime plugin state is merged across a layout write.
#
# Sourced by install.sh, uninstall.sh, the theme-set hook and tests. Defines
# functions only; do not execute it.
#
# Overridable for tests:
#   VP_CONFIG_DIR / CONFIG_DIR / XDG_CONFIG_HOME
#   VP_STATE_DIR / XDG_STATE_HOME
#   VP_SHELL_FORCE=1

vp_layout_config_dir() {
  printf '%s\n' "${VP_CONFIG_DIR:-${CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}}}"
}

vp_layout_state_dir() {
  printf '%s\n' "${VP_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/virtual-paradise}"
}

vp_layout_live() {
  printf '%s/omarchy/shell.json\n' "$(vp_layout_config_dir)"
}

vp_layout_theme() {
  printf '%s/omarchy/shell-paradise.json\n' "$(vp_layout_config_dir)"
}

vp_layout_default() {
  printf '%s/omarchy/shell-default.json\n' "$(vp_layout_config_dir)"
}

vp_layout_applied() {
  printf '%s/shell-layout.applied.json\n' "$(vp_layout_state_dir)"
}

# True when both files exist and describe the same bar layout.
#
# Omarchy writes runtime plugin state (`plugins`, `disabledPlugins`,
# `cloneSourceRestores`) into the same shell.json as the bar layout. Enabling
# one of the theme's widgets therefore changes the file without touching the
# layout, and a byte comparison would mistake that for a user edit and preserve
# the theme layout forever. Compare the `bar` subtree instead; that is the part
# this theme owns. A malformed or bar-less file is never "equal", so a broken
# file is preserved rather than overwritten.
vp_layout_same() {
  [[ -f $1 && -f $2 ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    local a b
    a="$(jq -S -c '.bar' "$1" 2>/dev/null)" || a=""
    b="$(jq -S -c '.bar' "$2" 2>/dev/null)" || b=""
    if [[ -n $a && $a != null && -n $b && $b != null ]]; then
      [[ $a == "$b" ]]
      return $?
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    a = json.load(open(sys.argv[1])).get("bar")
    b = json.load(open(sys.argv[2])).get("bar")
except Exception:
    sys.exit(1)
if a is None or b is None:
    sys.exit(1)
sys.exit(0 if a == b else 1)
PY
    return $?
  fi
  cmp -s "$1" "$2"
}

# True when the live bar is Omarchy's activeBarId fallback rather than a user
# layout. When the first-party bar cannot load, the host swaps the bar id to
# `omarchy.bar` without asking; that transient state must not be mistaken for a
# customisation and pinned forever.
vp_layout_is_fallback() {
  local live="$1" theme="$2"
  [[ -f $live && -f $theme ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    local live_id theme_id
    live_id="$(jq -r '.bar.id // empty' "$live" 2>/dev/null)" || live_id=""
    theme_id="$(jq -r '.bar.id // empty' "$theme" 2>/dev/null)" || theme_id=""
    if [[ -n $live_id && -n $theme_id ]]; then
      [[ $live_id == omarchy.bar && $theme_id != omarchy.bar ]]
      return $?
    fi
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$live" "$theme" <<'PY' 2>/dev/null
import json, sys
try:
    live = json.load(open(sys.argv[1], encoding="utf-8"))
    theme = json.load(open(sys.argv[2], encoding="utf-8"))
except Exception:
    sys.exit(1)
live_id = (live.get("bar") or {}).get("id")
theme_id = (theme.get("bar") or {}).get("id")
sys.exit(0 if live_id == "omarchy.bar" and theme_id not in (None, "", "omarchy.bar") else 1)
PY
    return $?
  fi
  return 1
}

# Write `template` to `out`, keeping the runtime plugin lists and any unknown
# top-level keys from `live`. Replacing the whole file would undo a user's
# plugin enable/disable choices every time the theme layout was re-applied.
# Falls back to a plain copy when neither jq nor python3 is available.
vp_layout_merge() {
  local template="$1" live="$2" out="$3"
  [[ -f $template ]] || return 1

  # A missing live file still has to go through the same serialiser as a
  # present one. Copying the template byte-for-byte here and merging on the
  # next run would make a second install look like a change even though the
  # content is identical.
  if [[ ! -f $live ]]; then
    if command -v jq >/dev/null 2>&1; then
      if jq '.' "$template" >"$out" 2>/dev/null && [[ -s $out ]]; then
        return 0
      fi
      rm -f "$out" 2>/dev/null || true
    fi
    if command -v python3 >/dev/null 2>&1; then
      if python3 - "$template" "$out" <<'PY' 2>/dev/null
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
      then
        return 0
      fi
      rm -f "$out" 2>/dev/null || true
    fi
    cp "$template" "$out"
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    if jq -s '
      .[0] as $new | .[1] as $old
      | $new
      + ($old | with_entries(select(.key as $k | ($new | has($k)) | not)))
      | if (($old | has("plugins")) or ($new | has("plugins")))
        then .plugins = ($old.plugins // $new.plugins) else . end
      | if (($old | has("disabledPlugins")) or ($new | has("disabledPlugins")))
        then .disabledPlugins = ($old.disabledPlugins // $new.disabledPlugins) else . end
      | if (($old | has("cloneSourceRestores")) or ($new | has("cloneSourceRestores")))
        then .cloneSourceRestores = ($old.cloneSourceRestores // $new.cloneSourceRestores) else . end
    ' "$template" "$live" >"$out" 2>/dev/null && [[ -s $out ]]; then
      return 0
    fi
    rm -f "$out" 2>/dev/null || true
  fi
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$template" "$live" "$out" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        new = json.load(fh)
    with open(sys.argv[2], encoding="utf-8") as fh:
        old = json.load(fh)
except Exception:
    sys.exit(1)
for key, value in old.items():
    if key not in new:
        new[key] = value
for key in ("plugins", "disabledPlugins", "cloneSourceRestores"):
    if key in old:
        new[key] = old[key]
with open(sys.argv[3], "w", encoding="utf-8") as fh:
    json.dump(new, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
    then
      return 0
    fi
    rm -f "$out" 2>/dev/null || true
  fi
  cp "$template" "$out"
}

# Install a freshly rendered theme layout.
#
# $1 = new theme layout file
# $2 = 1 to force, 0/none to respect user edits
# Prints "applied" or "preserved" on stdout.
vp_layout_install_from() {
  local new_layout="$1" force="${2:-0}"
  local live theme default applied old_theme decision
  live="$(vp_layout_live)"
  theme="$(vp_layout_theme)"
  default="$(vp_layout_default)"
  applied="$(vp_layout_applied)"

  [[ -f $new_layout ]] || return 1
  mkdir -p "$(dirname "$theme")" "$(dirname "$applied")" || return 1

  # Keep the previous theme layout long enough to recognise a re-install over
  # our own previous output. Without this, the first re-install after an
  # upgrade would look like a user edit and be preserved forever.
  old_theme="$(mktemp)" || return 1
  if [[ -f $theme ]]; then
    cp "$theme" "$old_theme" 2>/dev/null || true
  fi

  decision="preserved"
  if [[ $force == 1 || ${VP_SHELL_FORCE:-0} == 1 ]]; then
    decision="applied"
  elif [[ ! -f $live ]]; then
    decision="applied"
  elif vp_layout_same "$live" "$default"; then
    decision="applied"
  elif [[ -s $old_theme ]] && vp_layout_same "$live" "$old_theme"; then
    decision="applied"
  elif vp_layout_same "$live" "$applied"; then
    decision="applied"
  elif vp_layout_is_fallback "$live" "$new_layout"; then
    # Omarchy swapped the bar id to its stock fallback because the first-party
    # bar was temporarily unavailable. That is not a user edit; the installer
    # is about to restore the bar and the theme layout.
    decision="applied"
  fi

  if ! cp "$new_layout" "$theme"; then
    rm -f "$old_theme"
    return 1
  fi

  if [[ $decision == applied ]]; then
    local merged
    merged="$(mktemp)" || {
      rm -f "$old_theme"
      return 1
    }
    if ! vp_layout_merge "$new_layout" "$live" "$merged"; then
      rm -f "$old_theme" "$merged"
      return 1
    fi
    if ! cp "$merged" "$live"; then
      rm -f "$old_theme" "$merged"
      return 1
    fi
    cp "$merged" "$applied" 2>/dev/null || true
    rm -f "$merged"
  fi

  rm -f "$old_theme"
  printf '%s\n' "$decision"
}

# Called when the theme becomes active. Prints "applied", "already" or
# "preserved". "already" means the live file is already the theme layout; the
# applied marker is still refreshed.
vp_layout_enter() {
  local live theme default applied merged
  live="$(vp_layout_live)"
  theme="$(vp_layout_theme)"
  default="$(vp_layout_default)"
  applied="$(vp_layout_applied)"

  [[ -f $theme ]] || {
    printf 'preserved\n'
    return 0
  }

  if [[ -f $live ]] \
    && ! vp_layout_same "$live" "$default" \
    && ! vp_layout_same "$live" "$theme" \
    && ! vp_layout_same "$live" "$applied" \
    && ! vp_layout_is_fallback "$live" "$theme"; then
    printf 'preserved\n'
    return 0
  fi

  if vp_layout_same "$live" "$theme"; then
    merged="$(mktemp)" || return 1
    if vp_layout_merge "$theme" "$live" "$merged"; then
      mkdir -p "$(dirname "$applied")" 2>/dev/null || true
      cp "$merged" "$applied" 2>/dev/null || true
    fi
    rm -f "$merged"
    printf 'already\n'
    return 0
  fi

  merged="$(mktemp)" || return 1
  if ! vp_layout_merge "$theme" "$live" "$merged"; then
    rm -f "$merged"
    return 1
  fi
  if ! cp "$merged" "$live"; then
    rm -f "$merged"
    return 1
  fi
  mkdir -p "$(dirname "$applied")" 2>/dev/null || true
  cp "$merged" "$applied" 2>/dev/null || true
  rm -f "$merged"
  printf 'applied\n'
}

# Called when another theme becomes active. Prints "restored", "already" or
# "preserved". Only a layout this theme owns is replaced by the stock default;
# a user-customised layout survives a theme switch.
#
# $1 = 1 to restore the stock file even when the bar already matches. The
# uninstaller uses this so the theme's plugin lists cannot survive a removal.
# Theme switches use the default and let the plugin hook set the final state.
vp_layout_leave() {
  local force_restore="${1:-0}"
  local live theme default applied
  live="$(vp_layout_live)"
  theme="$(vp_layout_theme)"
  default="$(vp_layout_default)"
  applied="$(vp_layout_applied)"

  if [[ ! -f $default ]]; then
    printf 'preserved\n'
    return 0
  fi

  if [[ -f $live ]] \
    && ! vp_layout_same "$live" "$default" \
    && ! vp_layout_same "$live" "$applied" \
    && ! vp_layout_same "$live" "$theme" \
    && ! vp_layout_is_fallback "$live" "$theme"; then
    printf 'preserved\n'
    return 0
  fi

  if vp_layout_same "$live" "$default"; then
    if [[ $force_restore == 1 && -f $live ]]; then
      cp "$default" "$live" || return 1
    fi
    rm -f "$applied" 2>/dev/null || true
    printf 'already\n'
    return 0
  fi

  cp "$default" "$live" || return 1
  rm -f "$applied" 2>/dev/null || true
  printf 'restored\n'
}
