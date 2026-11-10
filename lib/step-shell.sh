#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034
# SC2154: installer globals are set by install.sh before these run.
# SC2034: variables are read by install.sh, not here.
# ==============================================================================
#  Virtual☆Paradise — shell / window-rule step helpers
# ==============================================================================
#  Window-rule block moves, the fcitx5 Unikey profile, and the per-shell rc
#  edits (PATH, aliases, banner cache, error hook). Sourced by install.sh.
# ==============================================================================

extract_rules_block() {
  local file="$1" start end
  VP_RULES_BLOCK=""
  start="$(grep -n "Virtual Paradise Add-on Window Rules" "$file" 2>/dev/null | head -n 1 | cut -d: -f1)"
  [[ -n $start ]] || return 1

  end="$start"
  while sed -n "$((end + 1))p" "$file" 2>/dev/null | grep -q '^o\.window('; do
    end=$((end + 1))
  done

  VP_RULES_BLOCK="$(sed -n "${start},${end}p" "$file")"
  sed -i "${start},${end}d" "$file" 2>/dev/null || true
  return 0
}

insert_rules_block() {
  local file="$1" block merged
  [[ -n $VP_RULES_BLOCK ]] || return 1

  block="$(mktemp)"
  merged="$(mktemp)"
  printf '\n%s\n' "$VP_RULES_BLOCK" >"$block"

  if grep -q "hyprmoncfg-monitors.lua" "$file"; then
    awk -v blockfile="$block" '
      /hyprmoncfg-monitors\.lua/ && !inserted {
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        inserted = 1
      }
      { print }
    ' "$file" >"$merged"
    if [[ -s $merged ]]; then
      replace_file_preserving "$file" "$merged" || {
        rm -f "$merged"
        cat "$block" >>"$file"
      }
    else
      rm -f "$merged"
      cat "$block" >>"$file"
    fi
  else
    cat "$block" >>"$file"
  fi
  rm -f "$block" "$merged"
  return 0
}

CONFIGURE_FCITX_UNIKEY() {
  command -v fcitx5 &>/dev/null || return 0

  local fcitx_dir="$CONFIG_DIR/fcitx5"
  local fcitx_profile="$fcitx_dir/profile"
  mkdir -p "$fcitx_dir"

  # Keep the user's own profile so uninstall.sh can put it back. Only taken when
  # the profile lacks our unikey entry, i.e. when it is genuinely the user's: a
  # later run must not back up the file we ourselves wrote, or uninstall would
  # "restore" our profile and leave fcitx5 configured for the rice.
  if [[ -f "$fcitx_profile" ]] \
    && ! grep -q "Name=unikey" "$fcitx_profile" \
    && [[ ! -f "$fcitx_profile.paradise.bak" ]]; then
    cp "$fcitx_profile" "$fcitx_profile.paradise.bak" 2>/dev/null || true
  fi

  if [[ ! -f "$fcitx_profile" ]]; then
    cat << 'EOF' > "$fcitx_profile"
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF
    log_sub "Initialized Fcitx5 profile with US Keyboard and Unikey"
  elif ! grep -q "Name=unikey" "$fcitx_profile"; then
    local next_idx=0
    while grep -q "^\[Groups/0/Items/${next_idx}\]" "$fcitx_profile"; do
      next_idx=$((next_idx + 1))
    done
    cat << EOF >> "$fcitx_profile"

[Groups/0/Items/${next_idx}]
Name=unikey
Layout=
EOF
    log_sub "Added Unikey input method to existing Fcitx5 profile (slot ${next_idx})"
  fi

  if pgrep -x fcitx5 &>/dev/null; then
    fcitx5-remote -r 2>/dev/null || systemctl --user restart omarchy-fcitx5.service 2>/dev/null || true
  fi
}

configure_shell_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  # Keep the pre-theme ~/.bashrc so uninstall can restore it. ~/.zshrc already
  # has the installer's .zshrc.bak.* snapshot path; .bashrc had none.
  if [[ "$file" == *".bashrc"* && ! -f "$file.paradise.bak" ]]; then
    cp "$file" "$file.paradise.bak" 2>/dev/null || true
  fi

  # Ensure $LOCAL_BIN is in PATH
  if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$file" && ! grep -q 'PATH=.*/\.local/bin' "$file"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$file"
  fi

  # Purge any legacy agy or paradise-agent aliases
  sed -i '/alias agy=/d; /alias pa=/d; /alias offline-agent=/d' "$file" 2>/dev/null || true

  # The banner is printed by a cached shell wrapper now. Rendering it with
  # Python cost the interpreter startup - about 30 ms - on every interactive
  # shell, which is the difference between a terminal that feels instant and
  # one that does not.
  sed -i 's|\$HOME/\.local/bin/paradise_banner\.py|$HOME/.local/bin/paradise_banner.sh|g' \
    "$file" 2>/dev/null || true

  # Add Virtual Paradise aliases
  if ! grep -q "paradise_banner" "$file" && ! grep -q "paradise-banner" "$file"; then
    cat << 'EOF' >> "$file"

# ==============================================================================
#  Virtual☆Paradise Add-on Aliases & Integration
# ==============================================================================
alias banner="$HOME/.local/bin/paradise_banner.sh"
alias rice="$HOME/.local/bin/rice_layout.sh"
alias matrix="$HOME/.local/bin/virtual_matrix.py"
alias boost="$HOME/.local/bin/toggle_cooler_boost.sh"
alias cast="$HOME/.local/bin/cast_screen.sh"

# Run Virtual Paradise Cyberpunk Banner on terminal startup (only in interactive shells)
# The banner is cached and printed from the shell: rendering it with Python
# cost ~30 ms of every shell start.
if [[ -o interactive ]] 2>/dev/null || [[ "$-" == *i* ]]; then
  if [[ -z "$VIRTUAL_PARADISE_NO_BANNER" && -x "$HOME/.local/bin/paradise_banner.sh" ]]; then
    "$HOME/.local/bin/paradise_banner.sh"
  fi
fi
EOF
  fi

  # Add fastfetch aliases
  if ! grep -q "alias ff=" "$file"; then
    echo "alias ff='fastfetch'" >> "$file"
  fi
  if ! grep -q "alias ffa=" "$file"; then
    echo "alias ffa='fastfetch --logo ~/.config/fastfetch/logo_anime.txt'" >> "$file"
  fi

  # Add cyberpunk error border hook
  if ! grep -q "__omarchy_error_border_hook" "$file" && ! grep -q "_omarchy_error_border_hook" "$file"; then
    if [[ "$file" == *".bashrc"* ]]; then
      cat << 'EOF' >> "$file"

# ==============================================================================
#  CYBERPUNK WINDOW ERROR SHAKE & BLAZING NEON RED GLOW HOOK (BASH)
# ==============================================================================
__omarchy_last_err_state=0

__omarchy_error_border_hook() {
  local exit_code=$?
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    if [[ $exit_code -ne 0 && $__omarchy_last_err_state -eq 0 ]]; then
      __omarchy_last_err_state=1
      (~/.local/bin/hypr_window_error_shake.sh &>/dev/null &)
    elif [[ $exit_code -eq 0 && $__omarchy_last_err_state -ne 0 ]]; then
      __omarchy_last_err_state=0
      (~/.local/bin/hypr_window_error_restore.sh &>/dev/null &)
    fi
  fi
  return $exit_code
}

if [[ "$PROMPT_COMMAND" != *"__omarchy_error_border_hook"* ]]; then
  PROMPT_COMMAND="__omarchy_error_border_hook${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
EOF
    elif [[ "$file" == *".zshrc"* ]]; then
      cat << 'EOF' >> "$file"

# ==============================================================================
#  CYBERPUNK WINDOW ERROR SHAKE & BLAZING NEON RED GLOW HOOK (ZSH)
# ==============================================================================
typeset -g __omarchy_last_err_state=0

__omarchy_error_border_hook() {
  local exit_code=$?
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    if [[ $exit_code -ne 0 && $__omarchy_last_err_state -eq 0 ]]; then
      __omarchy_last_err_state=1
      (~/.local/bin/hypr_window_error_shake.sh &>/dev/null &!)
    elif [[ $exit_code -eq 0 && $__omarchy_last_err_state -ne 0 ]]; then
      __omarchy_last_err_state=0
      (~/.local/bin/hypr_window_error_restore.sh &>/dev/null &!)
    fi
  fi
  return $exit_code
}

autoload -Uz add-zsh-hook 2>/dev/null || true
add-zsh-hook precmd __omarchy_error_border_hook 2>/dev/null || precmd_functions+=(__omarchy_error_border_hook)
EOF
    fi
  fi
}

