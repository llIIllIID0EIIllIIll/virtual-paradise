#!/usr/bin/env bash
# Virtual☆Paradise — Plymouth boot theme management.
#
# The boot splash is installed as its own theme and selected by name. The
# stock Omarchy theme (/usr/share/plymouth/themes/omarchy) belongs to the
# omarchy-settings package and is never written to: patching it in place
# meant a package update silently reverted the animation and uninstall.sh had
# nothing to restore.
#
# Every function takes a "system root" prefix so the test suite can run against
# a throwaway tree. Production passes "/" — paths are built as
# "${root%/}/usr/share/..." so that still resolves to /usr/share/....
#
# Sourced by install.sh, uninstall.sh and tests/run.sh; defines functions only.

VP_PLYMOUTH_THEME_NAME="virtual-paradise"
VP_PLYMOUTH_DESCRIPTOR="virtual-paradise.plymouth"
VP_PLYMOUTH_SCRIPT="virtual-paradise.script"
VP_PLYMOUTH_MARKER_FILE="virtual-paradise.marker"
VP_PLYMOUTH_MARKER="Virtual☆Paradise Plymouth theme"
VP_PLYMOUTH_STATE_DIR="/var/lib/virtual-paradise/plymouth"

# The old installer overwrote the package-owned omarchy script with this one.
# It is the marker that tells us a directory still carries our patch.
VP_PLYMOUTH_LEGACY_MARKER="Instant Lazy Loading"

# Frame counts of the bundled animations; the script loops modulo these.
VP_PLYMOUTH_INTRO_COUNT=259
VP_PLYMOUTH_OUTRO_COUNT=72

# Resolution and colour depth of the animation frames.
#
# Every frame is packed into the initramfs, and the splash is scaled to the
# screen anyway: 1920x1080 PNGs meant ~97 MB of images in the boot image, and
# Plymouth had that much to decode every second.
#
# 1600x900 with a 256 colour palette is visually the same once Plymouth
# stretches it over the screen (Plymouth converts palette PNGs through
# png_set_palette_to_rgb) and cuts the image data to about a third. The
# frames are also what the boot image has to read, so this is boot time
# saved.
VP_PLYMOUTH_FRAME_WIDTH=1600
VP_PLYMOUTH_FRAME_HEIGHT=900
VP_PLYMOUTH_FRAME_PIXEL_FORMAT="pal8"

# Stock assets the script needs next to the animation frames.
VP_PLYMOUTH_ASSETS="bullet.png entry.png lock.png logo.png progress_bar.png progress_box.png"

# The theme's own decoration: the neon frame around the picture and the cyber
# pattern that tiles the bars around it. They are shipped in plymouth/ and
# copied into the theme directory like the rest of the payload.
VP_PLYMOUTH_DECORATION="frame.png tile.png"

plymouth_theme_path() {
  printf '%s/usr/share/plymouth/themes/%s\n' "${1%/}" "$VP_PLYMOUTH_THEME_NAME"
}

plymouth_stock_dir() {
  printf '%s/usr/share/omarchy/default/plymouth\n' "${1%/}"
}

plymouth_legacy_dir() {
  printf '%s/usr/share/plymouth/themes/omarchy\n' "${1%/}"
}

plymouth_conf_path() {
  printf '%s/etc/plymouth/plymouthd.conf\n' "${1%/}"
}

# The theme plymouthd would load, read from /etc/plymouth/plymouthd.conf.
plymouth_current_theme() {
  local root="${1%/}" conf value
  conf="$(plymouth_conf_path "$root")"
  [[ -f $conf ]] || return 0
  value="$(sed -n 's/^[[:space:]]*Theme[[:space:]]*=[[:space:]]*//p' "$conf" | tail -n 1)"
  printf '%s\n' "$value"
}

# Write the theme selection into the [Daemon] section of plymouthd.conf, the
# same file plymouth-set-default-theme maintains. An empty name resets the
# selection so plymouthd falls back to its own default.
plymouth_set_theme() {
  local root="${1%/}" name="${2:-}" conf
  conf="$(plymouth_conf_path "$root")"
  mkdir -p "$(dirname "$conf")" || return 1

  if [[ -z $name ]]; then
    [[ -f $conf ]] || return 0
    sed -i '/^[[:space:]]*Theme[[:space:]]*=/d' "$conf" || return 1
    return 0
  fi

  if [[ ! -f $conf ]]; then
    printf '[Daemon]\nTheme=%s\n' "$name" >"$conf" || return 1
    return 0
  fi

  if grep -qE '^[[:space:]]*Theme[[:space:]]*=' "$conf"; then
    sed -i -E "s|^[[:space:]]*Theme[[:space:]]*=.*|Theme=$name|" "$conf" || return 1
  elif grep -qE '^[[:space:]]*\[Daemon\][[:space:]]*$' "$conf"; then
    sed -i "/^[[:space:]]*\[Daemon\][[:space:]]*$/a Theme=$name" "$conf" || return 1
  else
    printf '[Daemon]\nTheme=%s\n' "$name" >>"$conf" || return 1
  fi
  return 0
}

# A directory is ours only when it carries our marker file.
plymouth_theme_is_ours() {
  local root="${1%/}" dir
  dir="$(plymouth_theme_path "$root")"
  [[ -f "$dir/$VP_PLYMOUTH_MARKER_FILE" ]] || return 1
  grep -qsF "$VP_PLYMOUTH_MARKER" "$dir/$VP_PLYMOUTH_MARKER_FILE"
}

# Check that the installed theme is complete: Plymouth only complains about a
# missing image when the machine is booting, so it has to be checked here.
plymouth_theme_verify() {
  local root="${1%/}" dir asset missing=0
  dir="$(plymouth_theme_path "$root")"

  for asset in "$VP_PLYMOUTH_DESCRIPTOR" "$VP_PLYMOUTH_SCRIPT" "$VP_PLYMOUTH_MARKER_FILE"; do
    if [[ ! -f "$dir/$asset" ]]; then
      printf 'plymouth: missing %s\n' "$dir/$asset" >&2
      missing=1
    fi
  done

  for asset in intro-1.png outro-1.png $VP_PLYMOUTH_ASSETS $VP_PLYMOUTH_DECORATION; do
    if [[ ! -f "$dir/$asset" ]]; then
      printf 'plymouth: missing %s\n' "$dir/$asset" >&2
      missing=1
    fi
  done

  # A short frame set still boots, but the animation would stutter and the
  # script loops modulo the full count.
  if [[ -f "$dir/intro-1.png" ]] && [[ ! -f "$dir/intro-$VP_PLYMOUTH_INTRO_COUNT.png" ]]; then
    printf 'plymouth: warning: the boot animation is incomplete (intro-%s.png missing)\n' \
      "$VP_PLYMOUTH_INTRO_COUNT" >&2
  fi
  if [[ -f "$dir/outro-1.png" ]] && [[ ! -f "$dir/outro-$VP_PLYMOUTH_OUTRO_COUNT.png" ]]; then
    printf 'plymouth: warning: the shutdown animation is incomplete (outro-%s.png missing)\n' \
      "$VP_PLYMOUTH_OUTRO_COUNT" >&2
  fi

  if [[ -f "$dir/$VP_PLYMOUTH_DESCRIPTOR" ]]; then
    if ! grep -qF "ScriptFile=$dir/$VP_PLYMOUTH_SCRIPT" "$dir/$VP_PLYMOUTH_DESCRIPTOR"; then
      printf 'plymouth: %s does not point at the installed script\n' \
        "$dir/$VP_PLYMOUTH_DESCRIPTOR" >&2
      missing=1
    fi
  fi

  return "$missing"
}

# Encode the animation frames with ffmpeg. The old installer wrote them into
# the package-owned omarchy theme; they now live in our own theme directory.
plymouth_encode_frames() {
  local stage="$1" repo="$2" video
  command -v ffmpeg >/dev/null 2>&1 || {
    printf 'plymouth: ffmpeg is not installed, the animation frames cannot be built\n' >&2
    return 1
  }

  video="$repo/backgrounds/Miku_animated_full.mp4"
  if [[ -f $video ]]; then
    ffmpeg -y -loglevel error -i "$video" \
      -vf "scale=${VP_PLYMOUTH_FRAME_WIDTH}:${VP_PLYMOUTH_FRAME_HEIGHT}" \
      -pix_fmt "$VP_PLYMOUTH_FRAME_PIXEL_FORMAT" \
      "$stage/intro-%d.png" || return 1
  fi

  video="$repo/backgrounds/Miku_missing.mp4"
  if [[ -f $video ]]; then
    ffmpeg -y -loglevel error -i "$video" \
      -vf "scale=${VP_PLYMOUTH_FRAME_WIDTH}:${VP_PLYMOUTH_FRAME_HEIGHT}" \
      -pix_fmt "$VP_PLYMOUTH_FRAME_PIXEL_FORMAT" \
      "$stage/outro-%d.png" || return 1
  fi
  return 0
}

# Are the frames already encoded at the wanted resolution? Frames from an
# older install are the full 1920x1080 and would keep the boot image big, so
# they are re-encoded when the size does not match.
plymouth_frames_match() {
  local stage="$1" frame size
  for frame in "$stage/intro-1.png" "$stage/outro-1.png"; do
    [[ -f $frame ]] || continue
    size="$(plymouth_image_size "$frame")" || return 0
    [[ $size == "${VP_PLYMOUTH_FRAME_WIDTH}x${VP_PLYMOUTH_FRAME_HEIGHT}" ]] || return 1
  done
  return 0
}

# Read the pixel size of a PNG without pulling in a tool: the IHDR chunk
# holds the width and height as two big-endian 32-bit numbers. A file that is
# not a PNG reports nothing, and the caller keeps it as it is.
plymouth_image_size() {
  local frame="$1" bytes magic
  magic="$(od -An -tx1 -N4 "$frame" 2>/dev/null | tr -d ' \n')"
  [[ $magic == "89504e47" ]] || return 1

  bytes="$(od -An -tu1 -j16 -N8 "$frame" 2>/dev/null | tr -s ' ' | sed 's/^ //')"
  [[ -n $bytes ]] || return 1
  # shellcheck disable=SC2086
  set -- $bytes
  [[ $# -eq 8 ]] || return 1
  printf '%dx%d' "$(( $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 ))" \
    "$(( $5 * 16777216 + $6 * 65536 + $7 * 256 + $8 ))"
}

# Copy the stock assets (lock, entry, bullet, progress bar) next to the
# animation. They belong to the omarchy-settings package, so they are read
# from its source directory and never written back into it.
plymouth_copy_assets() {
  local root="${1%/}" stage="$2" src asset copied=1
  src="$(plymouth_stock_dir "$root")"
  if [[ ! -d $src ]]; then
    src="$(plymouth_legacy_dir "$root")"
  fi

  for asset in $VP_PLYMOUTH_ASSETS; do
    if [[ -f "$src/$asset" ]]; then
      cp "$src/$asset" "$stage/$asset" || return 1
      copied=0
    fi
  done
  return "$copied"
}

# The old installer replaced /usr/share/plymouth/themes/omarchy/omarchy.script
# and dropped ~330 generated PNGs into that package-owned directory. Undo it
# once, so upgrades and uninstalls leave a stock boot splash even for machines
# that ran the old installer.
plymouth_repair_legacy_theme() {
  local root="${1%/}" legacy stock
  legacy="$(plymouth_legacy_dir "$root")"
  stock="$(plymouth_stock_dir "$root")"

  [[ -f "$legacy/omarchy.script" ]] || return 0
  grep -qs "$VP_PLYMOUTH_LEGACY_MARKER" "$legacy/omarchy.script" || return 0

  if [[ -f "$stock/omarchy.script" ]]; then
    cp "$stock/omarchy.script" "$legacy/omarchy.script" || return 1
    printf 'plymouth: restored the stock omarchy script (removed the old in-place patch)\n'
  else
    printf 'plymouth: warning: %s carries our patched script but the stock copy is missing\n' \
      "$legacy" >&2
  fi

  # The frames and background images were ours; the stock theme has none of them.
  local legacy_frame
  for legacy_frame in "$legacy"/intro-*.png "$legacy"/outro-*.png \
    "$legacy/background.png" "$legacy/background-shutdown.png"; do
    [[ -f $legacy_frame ]] && rm -f "$legacy_frame"
  done
  return 0
}

# Install the theme and select it. Safe to run repeatedly: the payload is
# staged next to the destination and swapped in, so an interrupted run never
# leaves a half-written theme for plymouthd to load.
plymouth_theme_install() {
  local root="${1%/}" repo="${2:-$PWD}"
  local theme_dir state_dir stage old script_src frame_src

  theme_dir="$(plymouth_theme_path "$root")"
  state_dir="$root$VP_PLYMOUTH_STATE_DIR"

  script_src="$repo/plymouth/$VP_PLYMOUTH_SCRIPT"
  if [[ ! -f $script_src ]]; then
    # Older checkouts shipped the script under the stock name.
    script_src="$repo/plymouth/omarchy.script"
  fi
  if [[ ! -f $script_src ]]; then
    printf 'plymouth: no theme script found in %s/plymouth\n' "$repo" >&2
    return 1
  fi

  if [[ -e $theme_dir ]] && ! plymouth_theme_is_ours "$root"; then
    printf 'plymouth: refusing to replace %s: it was not installed by Virtual Paradise\n' \
      "$theme_dir" >&2
    return 1
  fi

  mkdir -p "$(dirname "$theme_dir")" "$state_dir" || return 1

  stage="${theme_dir}.new.$$"
  rm -rf "$stage"
  mkdir -p "$stage" || return 1

  # Reuse the frames that are already on the machine. Re-encoding 331 PNGs on
  # every install is slow, and the upgrade path usually has them already. This
  # has to happen before the legacy repair, which deletes the frames the old
  # installer left in Omarchy's package-owned theme.
  frame_src=""
  if [[ -d $theme_dir ]]; then
    frame_src="$theme_dir"
  else
    local legacy_dir
    legacy_dir="$(plymouth_legacy_dir "$root")"
    [[ -d $legacy_dir ]] && frame_src="$legacy_dir"
  fi
  if [[ -n $frame_src ]]; then
    local -a frames=()
    local frame
    for frame in "$frame_src"/intro-*.png "$frame_src"/outro-*.png; do
      [[ -f $frame ]] && frames+=("$frame")
    done
    if [[ ${#frames[@]} -gt 0 ]]; then
      cp "${frames[@]}" "$stage/" || {
        rm -rf "$stage"
        return 1
      }
    fi
  fi

  plymouth_repair_legacy_theme "$root" || true

  if [[ ! -f "$stage/intro-$VP_PLYMOUTH_INTRO_COUNT.png" ]] || ! plymouth_frames_match "$stage"; then
    # Frames from an older install are the wrong size; re-encoding them keeps
    # the boot image small.
    rm -f "$stage"/intro-*.png "$stage"/outro-*.png 2>/dev/null || true
    plymouth_encode_frames "$stage" "$repo" || true
  fi

  if ! plymouth_copy_assets "$root" "$stage"; then
    printf 'plymouth: the stock Plymouth assets could not be copied\n' >&2
    rm -rf "$stage"
    return 1
  fi

  # The theme's own decoration: the neon frame and the caption.
  local decoration
  for decoration in $VP_PLYMOUTH_DECORATION; do
    if [[ -f "$repo/plymouth/$decoration" ]]; then
      cp "$repo/plymouth/$decoration" "$stage/$decoration" || {
        rm -rf "$stage"
        return 1
      }
    else
      printf 'plymouth: %s/plymouth/%s is missing\n' "$repo" "$decoration" >&2
      rm -rf "$stage"
      return 1
    fi
  done

  if [[ -f "$stage/intro-1.png" ]]; then
    cp "$stage/intro-1.png" "$stage/background.png" 2>/dev/null || true
  fi
  if [[ -f "$stage/outro-1.png" ]]; then
    cp "$stage/outro-1.png" "$stage/background-shutdown.png" 2>/dev/null || true
  fi

  cp "$script_src" "$stage/$VP_PLYMOUTH_SCRIPT" || {
    rm -rf "$stage"
    return 1
  }
  printf '%s\n' "$VP_PLYMOUTH_MARKER" >"$stage/$VP_PLYMOUTH_MARKER_FILE" || {
    rm -rf "$stage"
    return 1
  }

  cat >"$stage/$VP_PLYMOUTH_DESCRIPTOR" <<EOF
[Plymouth Theme]
Name=Virtual Paradise
Description=Virtual☆Paradise Miku boot and shutdown animation.
ModuleName=script

[script]
ImageDir=$theme_dir
ScriptFile=$theme_dir/$VP_PLYMOUTH_SCRIPT
ConsoleLogBackgroundColor=0x070810
MonospaceFont=Cantarell 11
Font=Cantarell 11
EOF

  find "$stage" -type f -exec chmod 644 {} + 2>/dev/null || true
  chmod 755 "$stage" 2>/dev/null || true

  old="${theme_dir}.old.$$"
  rm -rf "$old"
  if [[ -e $theme_dir ]]; then
    mv "$theme_dir" "$old" || {
      rm -rf "$stage"
      return 1
    }
  fi
  if ! mv "$stage" "$theme_dir"; then
    [[ -e $old ]] && mv "$old" "$theme_dir"
    rm -rf "$stage"
    return 1
  fi
  rm -rf "$old"

  if ! plymouth_theme_verify "$root"; then
    printf 'plymouth: the installed theme is incomplete (see above)\n' >&2
    return 1
  fi

  # Remember the selection that was active before the first install, so
  # uninstall can put it back.
  local current
  current="$(plymouth_current_theme "$root")"
  if [[ ! -f "$state_dir/previous-theme" ]] && [[ $current != "$VP_PLYMOUTH_THEME_NAME" ]]; then
    printf '%s\n' "$current" >"$state_dir/previous-theme" 2>/dev/null || true
  fi

  if ! plymouth_set_theme "$root" "$VP_PLYMOUTH_THEME_NAME"; then
    printf 'plymouth: could not write %s\n' "$(plymouth_conf_path "$root")" >&2
    return 1
  fi

  printf 'plymouth: installed theme %s\n' "$theme_dir"
  return 0
}

# Remove our theme and restore whatever theme selection was there before.
# A directory that is not ours is left alone, even when the name matches.
plymouth_theme_remove() {
  local root="${1%/}"
  local theme_dir state_dir previous current
  theme_dir="$(plymouth_theme_path "$root")"
  state_dir="$root$VP_PLYMOUTH_STATE_DIR"

  if [[ -e $theme_dir ]]; then
    if plymouth_theme_is_ours "$root"; then
      rm -rf "$theme_dir" || return 1
      printf 'plymouth: removed theme %s\n' "$theme_dir"
    else
      printf 'plymouth: leaving %s: it was not installed by Virtual Paradise\n' \
        "$theme_dir" >&2
    fi
  fi

  current="$(plymouth_current_theme "$root")"
  if [[ $current == "$VP_PLYMOUTH_THEME_NAME" ]]; then
    previous=""
    [[ -f "$state_dir/previous-theme" ]] && previous="$(head -n 1 "$state_dir/previous-theme" 2>/dev/null || true)"
    if [[ -n $previous ]]; then
      plymouth_set_theme "$root" "$previous" || return 1
      printf 'plymouth: restored the previous theme selection (%s)\n' "$previous"
    else
      plymouth_set_theme "$root" "" || return 1
      printf 'plymouth: reset the theme selection\n'
    fi
  fi

  rm -rf "$state_dir" 2>/dev/null || true
  rmdir "$root/var/lib/virtual-paradise" 2>/dev/null || true
  return 0
}
