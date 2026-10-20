#!/usr/bin/env bash
# Virtual☆Paradise — SDDM theme management.
#
# The login theme is installed as its own directory and selected with a
# dedicated drop-in. The stock Omarchy theme
# (/usr/share/sddm/themes/omarchy) belongs to the omarchy-settings package and
# is never written to: patching it in place broke on package updates and gave
# uninstall.sh nothing to restore.
#
# Every function takes a "system root" prefix so the test suite can run against
# a throwaway tree. Production passes "/" — paths are built as
# "${root%/}/usr/share/..." so that still resolves to /usr/share/....
#
# Sourced by install.sh, uninstall.sh and tests/run.sh; defines functions only.

VP_SDDM_THEME_NAME="virtual-paradise"
VP_SDDM_CONF_NAME="zz-virtual-paradise-theme.conf"
VP_SDDM_STATE_DIR="/var/lib/virtual-paradise/sddm"
VP_SDDM_MARKER="Virtual☆Paradise SDDM theme"
VP_SDDM_CONF_MARKER="Installed by Virtual Paradise"

sddm_theme_path() {
  printf '%s/usr/share/sddm/themes/%s\n' "${1%/}" "$VP_SDDM_THEME_NAME"
}

# Read the theme SDDM would actually load, following its documented order:
# /usr/lib/sddm/sddm.conf.d/*.conf, then /etc/sddm.conf.d/*.conf (each sorted
# by name), then /etc/sddm.conf, which has the highest precedence.
sddm_effective_theme() {
  local root="${1%/}" file line section current=""
  while IFS= read -r file; do
    [[ -f $file ]] || continue
    section=""
    while IFS= read -r line || [[ -n $line ]]; do
      line="${line%%#*}"
      line="${line%%;*}"
      if [[ $line =~ ^[[:space:]]*\[([^]]+)\][[:space:]]*$ ]]; then
        section="${BASH_REMATCH[1]}"
        continue
      fi
      [[ $section == Theme ]] || continue
      if [[ $line =~ ^[[:space:]]*Current[[:space:]]*=[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]; then
        current="${BASH_REMATCH[1]}"
      fi
    done <"$file"
  done < <(
    {
      find "$root/usr/lib/sddm/sddm.conf.d" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | LC_ALL=C sort
      find "$root/etc/sddm.conf.d" -maxdepth 1 -type f -name '*.conf' 2>/dev/null | LC_ALL=C sort
      if [[ -f "$root/etc/sddm.conf" ]]; then
        printf '%s\n' "$root/etc/sddm.conf"
      fi
    }
  )
  printf '%s\n' "$current"
}

# Check that the installed theme is complete: the greeter needs every file the
# QML references, and a missing asset would only show up at the login screen.
sddm_theme_verify() {
  local root="${1%/}" theme_dir f missing=0
  theme_dir="$(sddm_theme_path "$root")"

  for f in Main.qml theme.conf metadata.desktop; do
    if [[ ! -f "$theme_dir/$f" ]]; then
      printf 'sddm: missing %s\n' "$theme_dir/$f" >&2
      missing=1
    fi
  done

  if [[ -f "$theme_dir/Main.qml" ]]; then
    while IFS= read -r f; do
      [[ -n $f ]] || continue
      if [[ ! -f "$theme_dir/$f" ]]; then
        printf 'sddm: Main.qml references missing asset %s\n' "$f" >&2
        missing=1
      fi
    done < <(
      grep -oE '"[A-Za-z0-9_./-]+\.(png|gif|jpe?g|svg)"' "$theme_dir/Main.qml" \
        | tr -d '"' | LC_ALL=C sort -u
    )
  fi

  if [[ ! -f "$theme_dir/still.png" ]]; then
    # Caught by the loop above, but name it explicitly: without it the greeter
    # has no picture at all, which is the one thing users would notice.
    printf 'sddm: the splash picture still.png is missing\n' >&2
    missing=1
  fi

  return "$missing"
}

# The old installer copied sddm/Main.qml and the 13 MB gif into the omarchy
# package theme. Undo that once, so upgrades and uninstalls leave a stock login
# screen even for machines that ran the old installer.
sddm_repair_legacy_theme() {
  local root="${1%/}"
  local theme="$root/usr/share/sddm/themes/omarchy"
  local stock="$root/usr/share/omarchy/default/sddm/omarchy"
  local main="$theme/Main.qml" gif="$theme/Miku_animated_full.gif"

  [[ -d $theme && -f $gif ]] || return 0
  # Only touch the directory if it really carries the old patch: either it
  # still points at the Miku gif, or it is one of our own themes. The old
  # installer copied the QML over, so the marker is the reliable tell.
  if ! grep -qs 'Miku_animated_full\.gif' "$main" && ! grep -qsF "$VP_SDDM_MARKER" "$main"; then
    return 0
  fi

  rm -f "$gif" || return 1
  if [[ -f "$stock/Main.qml" ]] && ! grep -qs 'Miku_animated_full\.gif' "$stock/Main.qml"; then
    cp "$stock/Main.qml" "$main" || return 1
    printf 'sddm: restored the stock omarchy theme (removed the old in-place patch)\n'
  else
    printf 'sddm: removed the old Miku gif; restore the omarchy Main.qml from its package if the theme looks wrong\n' >&2
  fi
  return 0
}

# Install the theme and select it. Safe to run repeatedly: the payload is
# staged next to the destination and swapped in, so an interrupted run never
# leaves a half-written theme for the greeter to load.
sddm_theme_install() {
  local root="${1%/}" repo="${2:-$PWD}"
  local theme_dir conf_dir conf state_dir stage old f

  theme_dir="$(sddm_theme_path "$root")"
  conf_dir="$root/etc/sddm.conf.d"
  conf="$conf_dir/$VP_SDDM_CONF_NAME"
  state_dir="$root$VP_SDDM_STATE_DIR"

  if [[ ! -f "$repo/sddm/Main.qml" ]]; then
    printf 'sddm: %s/sddm/Main.qml not found\n' "$repo" >&2
    return 1
  fi
  if [[ ! -f "$repo/sddm/assets/still.png" ]]; then
    printf 'sddm: %s/sddm/assets/still.png not found\n' "$repo" >&2
    return 1
  fi
  if [[ -e "$theme_dir" ]] && ! grep -qsF "$VP_SDDM_MARKER" "$theme_dir/Main.qml" 2>/dev/null; then
    printf 'sddm: refusing to replace %s: it was not installed by Virtual Paradise\n' \
      "$theme_dir" >&2
    return 1
  fi

  sddm_repair_legacy_theme "$root" || true

  mkdir -p "$(dirname "$theme_dir")" "$conf_dir" "$state_dir" || return 1

  stage="${theme_dir}.new.$$"
  rm -rf "$stage"
  if ! mkdir -p "$stage"; then
    return 1
  fi
  for f in Main.qml theme.conf metadata.desktop; do
    if [[ ! -f "$repo/sddm/$f" ]] || ! cp "$repo/sddm/$f" "$stage/$f"; then
      printf 'sddm: cannot install sddm/%s\n' "$f" >&2
      rm -rf "$stage"
      return 1
    fi
  done
  if [[ -d "$repo/sddm/assets" ]]; then
    if ! cp "$repo/sddm/assets"/*.png "$stage"/ 2>/dev/null; then
      printf 'sddm: warning: no PNG assets found in %s/sddm/assets\n' "$repo" >&2
    fi
  fi
  # The same backdrop and neon frame the Plymouth splash uses, so the greeter
  # is the boot animation continued instead of a different screen.
  for f in backdrop.png frame.png; do
    if [[ ! -f "$repo/plymouth/$f" ]] || ! cp "$repo/plymouth/$f" "$stage/$f"; then
      printf 'sddm: cannot install plymouth/%s\n' "$f" >&2
      rm -rf "$stage"
      return 1
    fi
  done
  find "$stage" -type f -exec chmod 644 {} + 2>/dev/null || true
  chmod 755 "$stage" 2>/dev/null || true

  old="${theme_dir}.old.$$"
  rm -rf "$old"
  if [[ -e "$theme_dir" ]]; then
    mv "$theme_dir" "$old" || { rm -rf "$stage"; return 1; }
  fi
  if ! mv "$stage" "$theme_dir"; then
    [[ -e $old ]] && mv "$old" "$theme_dir"
    rm -rf "$stage"
    return 1
  fi
  rm -rf "$old"

  # Keep a foreign drop-in safe; only the first install needs the backup.
  if [[ -f "$conf" ]] && ! grep -qs "$VP_SDDM_CONF_MARKER" "$conf"; then
    [[ -f "$state_dir/previous-theme.conf" ]] || cp -a "$conf" "$state_dir/previous-theme.conf"
  fi
  if ! cat >"$conf" <<EOF
# $VP_SDDM_CONF_MARKER — remove with uninstall.sh.
# The name sorts after Omarchy's 99-*.conf so this [Theme] section wins.
[Theme]
Current=$VP_SDDM_THEME_NAME
EOF
  then
    printf 'sddm: cannot write %s\n' "$conf" >&2
    return 1
  fi

  if ! sddm_theme_verify "$root"; then
    printf 'sddm: the installed theme is incomplete (see above)\n' >&2
    return 1
  fi

  local effective
  effective="$(sddm_effective_theme "$root")"
  if [[ "$effective" != "$VP_SDDM_THEME_NAME" ]]; then
    printf 'sddm: warning: SDDM would load theme "%s" instead of %s.\n' \
      "${effective:-<embedded>}" "$VP_SDDM_THEME_NAME" >&2
    printf 'sddm: remove the [Theme] Current= override in %s/etc/sddm.conf to use the new theme.\n' \
      "${root:-/}" >&2
  fi

  printf 'sddm: installed theme %s\n' "$theme_dir"
  return 0
}

# Remove our theme and restore whatever theme selection was there before.
# A directory that is not ours is left alone, even when the name matches.
sddm_theme_remove() {
  local root="${1%/}"
  local theme_dir conf state_dir
  theme_dir="$(sddm_theme_path "$root")"
  conf="$root/etc/sddm.conf.d/$VP_SDDM_CONF_NAME"
  state_dir="$root$VP_SDDM_STATE_DIR"

  if [[ -e "$theme_dir" ]]; then
    if grep -qsF "$VP_SDDM_MARKER" "$theme_dir/Main.qml" 2>/dev/null; then
      rm -rf "$theme_dir" || return 1
      printf 'sddm: removed theme %s\n' "$theme_dir"
    else
      printf 'sddm: leaving %s: it was not installed by Virtual Paradise\n' "$theme_dir" >&2
    fi
  fi

  if [[ -f "$conf" ]] && grep -qsF "$VP_SDDM_CONF_MARKER" "$conf"; then
    rm -f "$conf"
    if [[ -f "$state_dir/previous-theme.conf" ]]; then
      if mv "$state_dir/previous-theme.conf" "$conf"; then
        printf 'sddm: restored the previous theme selection\n'
      fi
    fi
  fi

  rmdir "$state_dir" 2>/dev/null || true
  rmdir "$root/var/lib/virtual-paradise" 2>/dev/null || true
  return 0
}
