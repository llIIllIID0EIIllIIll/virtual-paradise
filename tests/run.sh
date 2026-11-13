#!/usr/bin/env bash
# Virtual Paradise test suite.
#
#   ./tests/run.sh            run everything
#   ./tests/run.sh tc2 tc4    run only the named cases
#
# Cases are numbered TC-1..TC-28 and each maps to one numbered section of the
# README's test matrix, so the two cannot drift apart silently.

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

want() {
  [[ ${#SELECTED[@]} -eq 0 ]] && return 0
  local s
  for s in "${SELECTED[@]}"; do [[ $s == "$1" ]] && return 0; done
  return 1
}

SELECTED=("$@")

# ─────────────────────────────────────────────────────────────────────────────
# TC-1  Static checks: every script parses, every config is valid.
# ─────────────────────────────────────────────────────────────────────────────
if want tc1; then
  section "TC-1  Static checks"

  bad=()
  while IFS= read -r f; do
    bash -n "$f" 2>/dev/null || bad+=("$f")
  done < <(find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o \
             \( -name "*.sh" -o -name "lib.sh" \) -print | sort)
  check "every shell script parses under bash -n" \
    "$([[ ${#bad[@]} -eq 0 ]] && echo 0 || echo 1)" "${bad[*]:-}"

  # Hyprland's config is Lua, so "parseable" means a real Lua syntax check, not
  # `zsh -n`. A syntax error here is exactly what lands the user in Hyprland's
  # config-error overlay. luac ships with lua/luajit; without one we skip.
  luac_bin="$(command -v luac || command -v luac5.4 || command -v luac5.1 || true)"
  if [[ -n $luac_bin ]]; then
    luabad=()
    while IFS= read -r f; do
      "$luac_bin" -p "$f" 2>/dev/null || luabad+=("$f")
    done < <(find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o -name "*.lua" -print)
    check "hyprland lua files are parseable" \
      "$([[ ${#luabad[@]} -eq 0 ]] && echo 0 || echo 1)" "${luabad[*]:-}"
  else
    printf '  %sSKIP%s luac not installed\n' "$DIM" "$OFF"
  fi

  pybad=()
  while IFS= read -r f; do
    python3 -m py_compile "$f" 2>/dev/null || pybad+=("$f")
  done < <(find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o -name "*.py" -print)
  find "$REPO_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
  check "every python file compiles" \
    "$([[ ${#pybad[@]} -eq 0 ]] && echo 0 || echo 1)" "${pybad[*]:-}"

  jsonbad=$(python3 - "$REPO_DIR" <<'PY'
import json, os, sys
root = sys.argv[1]
bad = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d != ".git" and d != "__pycache__"]
    for name in filenames:
        if name.endswith(".json"):
            p = os.path.join(dirpath, name)
            try:
                json.load(open(p))
            except Exception as exc:
                bad.append(f"{os.path.relpath(p, root)}: {exc}")
print("\n".join(bad))
PY
)
  check "every JSON file is valid" \
    "$([[ -z $jsonbad ]] && echo 0 || echo 1)" "$jsonbad"

  tomlbad=$(python3 - "$REPO_DIR" <<'PY'
import os, sys
try:
    import tomllib
except ModuleNotFoundError:
    sys.exit(0)
root = sys.argv[1]
bad = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d != ".git" and d != "__pycache__"]
    for name in filenames:
        if name.endswith(".toml"):
            p = os.path.join(dirpath, name)
            try:
                tomllib.load(open(p, "rb"))
            except Exception as exc:
                bad.append(f"{os.path.relpath(p, root)}: {exc}")
print("\n".join(bad))
PY
)
  check "every TOML file is valid" \
    "$([[ -z $tomlbad ]] && echo 0 || echo 1)" "$tomlbad"

  # "Command ... is not executable: No such file or directory" is expected:
  # the units point at ~/.local/bin scripts that only exist after an install.
  # Anything else from systemd-analyze is a real defect.
  # qmllint, when present. Catches QML type errors that otherwise only show up
  # when the shell loads the file - a Gradient assigned where a ShapeGradient is
  # required took the whole bar down to the stock one and only surfaced in the
  # running shell's log.
  qmllint_bin="$(command -v qmllint || echo /usr/lib/qt6/bin/qmllint)"
  if [[ ! -d /usr/share/omarchy/shell/Commons || ! -d /usr/share/omarchy/shell/Ui ]]; then
    # Without the Omarchy modules qmllint can loop on an unresolved
    # component (network/Panel.qml did) and its type errors are noise. The
    # check only means something next to a real Omarchy install.
    printf '  %sSKIP%s qmllint (Omarchy QML modules not installed)\n' "$DIM" "$OFF"
  elif [[ -x $qmllint_bin ]]; then
    qmli="$(mktemp -d)"
    mkdir -p "$qmli/qs"
    for m in Commons Ui; do
      ln -s "/usr/share/omarchy/shell/$m" "$qmli/qs/$m"
    done
    qmlbad=""
    while IFS= read -r f; do
      rc=0
      out=$(timeout 15 "$qmllint_bin" -I "$qmli" "$f" 2>&1) || rc=$?
      if [[ $rc -eq 124 ]]; then
        qmlbad="$qmlbad
$(basename "$f"): qmllint timed out"
        continue
      fi
      out=$(printf '%s\n' "$out" \
        | grep -E 'incompatible-type|Cannot assign|unavailable' || true)
      [[ -n $out ]] && qmlbad="$qmlbad
$(basename "$f"): $out"
    done < <(find "$REPO_DIR/bars" "$REPO_DIR/plugins" "$REPO_DIR/bin" "$REPO_DIR/sddm" -name '*.qml' 2>/dev/null)
    rm -rf "$qmli"
    check "qmllint reports no QML type errors" \
      "$([[ -z $qmlbad ]] && echo 0 || echo 1)" "$qmlbad"
  else
    printf '  %sSKIP%s qmllint not installed\n' "$DIM" "$OFF"
  fi

  # The read-only diagnose report is the support tool; it must run without
  # sudo and print the sections a bug report needs.
  diag_root="$(mktemp -d)"
  diagout=$( HOME="$diag_root" bash "$REPO_DIR/bin/vp-diagnose.sh" 2>&1 )
  diag_rc=$?
  check "vp-diagnose runs read-only" "$diag_rc" "$(printf '%s' "$diagout" | tail -3)"
  check "vp-diagnose reports the repository and install state" \
    "$([[ $diagout == *"Theme repository"* && $diagout == *"Installed state"* ]] && echo 0 || echo 1)"
  check "install.sh --help documents diagnose" \
    "$(bash "$REPO_DIR/install.sh" --help 2>&1 | grep -q 'diagnose' && echo 0 || echo 1)"
  rm -rf "$diag_root"

  # Terminal emulator configs, validated by the emulator that reads them. These
  # are hand-written and the failure mode is a GUI dialog ("Configuration
  # Errors") rather than a broken build, so check them here. Ghostty prints
  # unknown fields on stdout and still exits 0, and foot stops at the first bad
  # option, so parse the output instead of the exit status.
  if command -v ghostty >/dev/null 2>&1; then
    gbad=$(ghostty +validate-config --config-file="$REPO_DIR/config/terminal/ghostty.conf" 2>&1)
    check "ghostty.conf has no unknown fields" \
      "$([[ -z $gbad ]] && echo 0 || echo 1)" "$gbad"
  else
    printf '  %sSKIP%s ghostty not installed\n' "$DIM" "$OFF"
  fi

  if command -v foot >/dev/null 2>&1; then
    fbad=$(foot --check-config --config="$REPO_DIR/config/terminal/foot.ini" 2>&1)
    check "foot.ini has no invalid options" \
      "$([[ -z $fbad ]] && echo 0 || echo 1)" "$fbad"
  else
    printf '  %sSKIP%s foot not installed\n' "$DIM" "$OFF"
  fi

  # Hyprland itself is the authority on its own Lua config: `hyprctl
  # configerrors` returns everything it rejected on the last load. Only
  # meaningful while a compositor instance is running, so skip otherwise.
  if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hbad=$(hyprctl configerrors 2>/dev/null | sed '/^[[:space:]]*$/d' || true)
    check "the running Hyprland reports no config errors" \
      "$([[ -z $hbad ]] && echo 0 || echo 1)" "$hbad"
  else
    printf '  %sSKIP%s no running Hyprland instance\n' "$DIM" "$OFF"
  fi

  # Shellcheck, when present. Skipped rather than failed on machines without
  # it, so the suite stays usable outside CI. The file list mirrors the lint
  # job in .github/workflows/test.yml; if they drift, one of the two starts
  # reporting things the other never sees.
  if command -v shellcheck >/dev/null 2>&1; then
    scbad=$(cd "$REPO_DIR" && shellcheck -S warning -f gcc \
      install.sh uninstall.sh lib/*.sh bin/*.sh tools/*.sh tests/*.sh 2>&1)
    check "shellcheck reports no warnings" \
      "$([[ -z $scbad ]] && echo 0 || echo 1)" "$scbad"
  else
    printf '  %sSKIP%s shellcheck not installed\n' "$DIM" "$OFF"
  fi

  # Two kinds of line are environment noise, not unit defects:
  #   - "Command ... is not executable": the units point at ~/.local/bin
  #     scripts that only exist after an install.
  #   - "Failed to lookup RuntimeDirectory path" / "Failed to initialize
  #     manager": there is no user systemd manager in a container or a bare CI
  #     runner. systemd 255 stays quiet there, systemd 262 (Arch) does not.
  unitbad=$(systemd-analyze verify \
    --user "$REPO_DIR"/systemd/*.service "$REPO_DIR"/systemd/*.timer 2>&1 \
    | grep -v -e 'is not executable: No such file or directory' \
                -e 'Failed to lookup RuntimeDirectory path' \
                -e 'Failed to initialize manager')
  check "systemd units verify" "$([[ -z $unitbad ]] && echo 0 || echo 1)" "$unitbad"

  # A file missing its trailing newline is legal but systemd-lint-clean tools
  # and git treat it as noise; it also breaks naive concatenation.
  nonl=$(for f in "$REPO_DIR"/systemd/*; do
           [[ -s $f && $(tail -c1 "$f" | wc -l) -eq 0 ]] && echo "$(basename "$f")"
         done)
  check "systemd units end with a newline" \
    "$([[ -z $nonl ]] && echo 0 || echo 1)" "$nonl"

  # Hyprland runs every bind that matches a chord, so a repeat is a double
  # action: SUPER + RETURN used to launch two terminals. Compare against the
  # installed Omarchy tree, or the committed fixture in CI.
  if command -v python3 >/dev/null 2>&1; then
    python3 "$REPO_DIR/tools/check-bindings.py" >/dev/null 2>&1
    check "keybindings do not repeat or shadow Omarchy defaults" $?

    shadow="$SANDBOX/bindings-shadow.lua"
    printf 'o.bind("SUPER + RETURN", "Terminal", "true")\n' >"$shadow"
    VP_BINDINGS_FILE="$shadow" OMARCHY_BINDINGS_DIR="$SANDBOX/no-omarchy" \
      python3 "$REPO_DIR/tools/check-bindings.py" >/dev/null 2>&1
    rc=$?
    check "the binding checker rejects a shadowed Omarchy chord" \
      "$([[ $rc -ne 0 ]] && echo 0 || echo 1)"

    duplicate="$SANDBOX/bindings-duplicate.lua"
    printf 'o.bind("SUPER + ALT + F24", "A", "true")\no.bind("SUPER + ALT + F24", "B", "true")\n' \
      >"$duplicate"
    VP_BINDINGS_FILE="$duplicate" OMARCHY_BINDINGS_DIR="$SANDBOX/no-omarchy" \
      python3 "$REPO_DIR/tools/check-bindings.py" >/dev/null 2>&1
    rc=$?
    check "the binding checker rejects a repeated chord" \
      "$([[ $rc -ne 0 ]] && echo 0 || echo 1)"

    # A chord may be taken over on purpose, but only when the default is
    # unbound first: otherwise both actions run.
    override="$SANDBOX/bindings-override.lua"
    printf 'hl.unbind("SUPER + ALT + LEFT")\no.bind("SUPER + ALT + LEFT", "A", "true")\n' \
      >"$override"
    VP_BINDINGS_FILE="$override" OMARCHY_BINDINGS_DIR="$SANDBOX/no-omarchy" \
      python3 "$REPO_DIR/tools/check-bindings.py" >/dev/null 2>&1
    rc=$?
    check "the binding checker allows a chord taken over with hl.unbind" \
      "$([[ $rc -eq 0 ]] && echo 0 || echo 1)"
  else
    printf '  %sSKIP%s python3 not installed\n' "$DIM" "$OFF"
  fi

  # The close pair is the one deliberate takeover: the chords stay Omarchy's,
  # but the action is the theme's glitch death. Every other bind lives on a
  # free chord, including the restored SUPER + ALT + arrows group move.
  check "only the close pair is taken over from Omarchy" \
    "$([[ $(grep -c '^hl.unbind(' "$REPO_DIR/hypr/bindings.lua") -eq 2 ]] \
      && grep -q 'hl.unbind("SUPER + Q")' "$REPO_DIR/hypr/bindings.lua" \
      && grep -q 'hl.unbind("SUPER + W")' "$REPO_DIR/hypr/bindings.lua" \
      && echo 0 || echo 1)"
  check "Omarchy's group move keeps its default chord" \
    "$(! grep -q 'o.bind("SUPER + ALT + LEFT"' "$REPO_DIR/hypr/bindings.lua" \
      && ! grep -q 'o.bind("SUPER + ALT + RIGHT"' "$REPO_DIR/hypr/bindings.lua" \
      && echo 0 || echo 1)"
  check "the live wallpaper keeps a free chord" \
    "$(grep -q 'o.bind("SUPER + ALT + N", "Next Live Wallpaper"' "$REPO_DIR/hypr/bindings.lua" \
      && grep -q 'o.bind("SUPER + ALT + SHIFT + N", "Previous Live Wallpaper"' "$REPO_DIR/hypr/bindings.lua" \
      && echo 0 || echo 1)"
  # Omarchy owns these actions now. A theme alias on a free chord would give
  # two ways to do the same thing, which is exactly what this policy retires.
  check "the theme does not alias an action Omarchy already owns" \
    "$(! grep -qE '"(File Manager|Web Browser|Emoji Picker|Lock Screen|VS Code|Next Wallpaper|Theme Menu)"' \
      "$REPO_DIR/hypr/bindings.lua" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-2  Override layer: entry points resolve, files land where QML will load them.
# ─────────────────────────────────────────────────────────────────────────────
if want tc2; then
  section "TC-2  Override layer targets"

  root="$(new_sandbox tc2)"
  mkdir -p "$root/home/.config/omarchy/plugins"
  build_shims "$root/bin"

  # ssupt.audio-control ships QML under a versioned runtime/<hash>/ tree. An
  # override copied to the plugin root would load nothing, so this is the case
  # most likely to break silently.
  A="$root/home/.config/omarchy/plugins/ssupt.audio-control"
  HASH=abc123
  mkdir -p "$A/runtime/$HASH/qml/panels" "$A/runtime/$HASH/qml/core"
  # Upstream files exist before the override layer touches them. Recording them
  # as modifications (rather than creations) is what exercises the backup path
  # for a plugin that is not a git checkout.
  printf '// pristine panel\n' >"$A/runtime/$HASH/qml/panels/Panel.qml"
  printf '// pristine model\n' >"$A/runtime/$HASH/qml/core/Model.js"
  cat >"$A/manifest.json" <<EOF
{"schemaVersion":1,"id":"ssupt.audio-control","kinds":["bar-widget"],
 "entryPoints":{"barWidget":"runtime/$HASH/qml/panels/Panel.qml",
                "service":"runtime/$HASH/qml/core/Service.qml"}}
EOF

  # The power-manager polls idle state every five seconds and prints a DEBUG
  # line on each poll. The override layer keeps the poll and drops the log.
  P="$root/home/.config/omarchy/plugins/onlyvishesh.power-manager"
  mkdir -p "$P"
  cat >"$P/Panel.qml" <<'EOF'
Item {
  Timer {
    onTriggered: { console.log("IDLE DEBUG - State:", root.currentStateKey, "Mins:", root.idleSleepMins, "Countdown:", root.idleCountdown); idleStatusProc.running = true }
  }
}
EOF

  # The Bluetooth panel declares a Connections target that can be undefined
  # while the bar is rebuilt; the override keeps it null.
  B="$root/home/.config/omarchy/plugins/ssupt.bluetooth-audio"
  mkdir -p "$B"
  cat >"$B/Panel.qml" <<'EOF'
Connections {
  target: root.audioPluginRegistry
  function onPluginsChanged() {}
}
EOF

  out=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
         PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
         bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_apply_all" 2>&1 )
  check "po_apply_all exits cleanly" "$?" "$out"

  if [[ -f "$A/runtime/$HASH/qml/panels/Panel.qml" ]]; then
    diff -q "$REPO_DIR/overrides/ssupt.audio-control/Panel.qml" \
            "$A/runtime/$HASH/qml/panels/Panel.qml" >/dev/null
    check "audio Panel.qml override landed on the runtime entry point" $?
  else
    fail "audio Panel.qml override landed on the runtime entry point" "not found under runtime/$HASH"
  fi

  if [[ -f "$A/runtime/$HASH/qml/core/Model.js" ]]; then
    diff -q "$REPO_DIR/overrides/ssupt.audio-control/Model.js" \
            "$A/runtime/$HASH/qml/core/Model.js" >/dev/null
    check "audio Model.js override matches the repo copy" $?
  else
    fail "audio Model.js override matches the repo copy" "not found under runtime/$HASH/qml/core"
  fi

  ! grep -q 'IDLE DEBUG' "$P/Panel.qml"
  check "the power-manager debug log is removed" $?
  grep -q 'idleStatusProc.running = true' "$P/Panel.qml"
  check "the power-manager status poll is kept" $?
  grep -q 'target: root.audioPluginRegistry ? root.audioPluginRegistry : null' "$B/Panel.qml"
  check "the Bluetooth Connections target is guarded" $?

  # A plugin that is not installed yet must degrade, not abort. Under `set -e`
  # the old code killed the whole installer here.
  absent=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
            PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
            bash -c "set -euo pipefail; . '$REPO_DIR/lib/plugin-overrides.sh'; po_resolve_entrypoint '$root/home/.config/omarchy/plugins/nope' barWidget || true" 2>&1 )
  check "po_resolve_entrypoint on a missing plugin is survivable" 0 "$absent"

  # --pin records the installed revisions. `omarchy plugin add` clones upstream
  # HEAD with no pin, so without this a fresh install has no rollback target.
  G="$root/home/.config/omarchy/plugins/gitplugin"
  mkdir -p "$G"
  ( cd "$G" && git init -q && git config user.email t@t && git config user.name t \
    && echo a >a.qml && git add -A && git commit -qm one )
  pinout=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
            PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
            PARADISE_STATE_DIR="$root/home/.local/state/virtual-paradise" \
            bash "$REPO_DIR/bin/update-plugins.sh" --pin 2>&1 )
  check "update-plugins --pin exits cleanly" "$?" "$pinout"
  lock="$root/home/.local/state/virtual-paradise/plugin-versions.lock"
  want_sha=$(git -C "$G" rev-parse HEAD)
  if [[ -s $lock ]] && grep -q "gitplugin $want_sha" "$lock"; then
    ok "--pin records the installed revision"
  else
    fail "--pin records the installed revision" "lockfile: $(cat "$lock" 2>/dev/null)"
  fi

  # --verify compares each checkout with the lockfile, so CI or a timer can
  # catch a plugin that moved without a recorded review.
  verify_ok=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    PARADISE_STATE_DIR="$root/home/.local/state/virtual-paradise" \
    bash "$REPO_DIR/bin/update-plugins.sh" --verify 2>&1; echo "rc=$?" )
  check "verify accepts the pinned revision" \
    "$(printf '%s' "$verify_ok" | grep -q 'rc=0' && echo 0 || echo 1)" "$verify_ok"

  ( cd "$G" && echo b >b.qml && git add -A && git commit -qm two )
  verify_bad=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    PARADISE_STATE_DIR="$root/home/.local/state/virtual-paradise" \
    bash "$REPO_DIR/bin/update-plugins.sh" --verify 2>&1; echo "rc=$?" )
  check "verify reports drift after HEAD moves" \
    "$(printf '%s' "$verify_bad" | grep -q 'rc=1' && echo 0 || echo 1)" "$verify_bad"

  # State file must list exactly what was patched, so revert can restore it.
  state="$root/home/.local/state/virtual-paradise/overrides.state"
  if [[ -s $state ]]; then
    grep -q "ssupt.audio-control" "$state"
    check "override state records the audio plugin" $?
    awk -F'\t' 'NF!=3 || $1 !~ /^(modified|created)$/ {bad=1} END{exit bad+0}' "$state"
    check "override state rows are well formed" $?
  else
    fail "override state records the audio plugin" "state file empty or missing"
  fi

  # The shared lock is reentrant: an install can call the override layer from
  # inside another locked step, and a plain non-reentrant flock would deadlock
  # the same process.
  lockout=$( HOME="$root/home" XDG_STATE_HOME="$root/home/.local/state" \
    VP_STATE_DIR="$root/home/.local/state/virtual-paradise" \
    bash -c '. "$1/lib/lock.sh"; vp_lock && vp_lock && vp_unlock && vp_unlock && echo ok' _ "$REPO_DIR" 2>&1 )
  check "the shared lock is reentrant" \
    "$([[ "$lockout" == ok ]] && echo 0 || echo 1)" "$lockout"
  check "the shared lock file exists" \
    "$([[ -f "$root/home/.local/state/virtual-paradise/virtual-paradise.lock" ]] && echo 0 || echo 1)"

  # The update path reverts the layer, updates plugins, then re-applies it.
  # If re-applying after a revert does not land the override again, every
  # plugin update would quietly strip the theming.
  po_cycle=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_revert_all; po_apply_all; \
      diff -q '$REPO_DIR/overrides/ssupt.audio-control/Panel.qml' \
        '$A/runtime/$HASH/qml/panels/Panel.qml'" 2>&1 )
  check "override layer survives revert then re-apply" "$?" "$po_cycle"

  # Revert must put the non-git runtime file back to its pristine content, not
  # delete it: the plugin has no git checkout to restore from, so the backup
  # taken by the override layer is the only copy of upstream's file.
  PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_revert_all" >/dev/null 2>&1
  if [[ -f "$A/runtime/$HASH/qml/panels/Panel.qml" ]]; then
    ok "revert leaves the runtime file in place"
  else
    fail "revert leaves the runtime file in place" "file was deleted"
  fi
  grep -qx '// pristine panel' "$A/runtime/$HASH/qml/panels/Panel.qml" 2>/dev/null
  check "revert restores a non-git plugin from its backup" $?
  grep -q 'IDLE DEBUG' "$P/Panel.qml" 2>/dev/null
  check "revert restores the power-manager debug line" $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-3  Installer idempotency: repeated runs converge and do not grow state.
# ─────────────────────────────────────────────────────────────────────────────
if want tc3; then
  section "TC-3  Installer idempotency"

  root="$(new_sandbox tc3)"
  build_shims "$root/bin"

  run_installer "$root"; rc1=$?
  install_plain="$(strip_ansi "$root/install.log")"
  check "first install exits 0" "$rc1" "$(printf '%s\n' "$install_plain" | tail -3)"
  # grep -q closes the pipe early; with pipefail an upstream SIGPIPE would
  # turn a match into a failure. Read the stripped log from a here-string.
  check "install reached step 10" \
    "$(grep -q '\[10/10\]' <<<"$install_plain" && echo 0 || echo 1)"

  # Snapshot, run twice more, and diff. Nothing may drift.
  cp -a "$root/home" "$root/snapshot"
  run_installer "$root"; check "second install exits 0" $? "$(strip_ansi "$root/install.log" | tail -3)"
  run_installer "$root"; check "third install exits 0" $? "$(strip_ansi "$root/install.log" | tail -3)"

  drift=$(diff -rq "$root/snapshot" "$root/home" 2>&1 \
          | grep -vE '\.bak_default|backup_[0-9]{8}|\.zshrc\.bak\.' )
  check "repeated installs change nothing" \
    "$([[ -z $drift ]] && echo 0 || echo 1)" "$drift"

  # Timestamped backups are capped: newest few plus the original pre-install copy.
  nbak=$(find "$root/home" -maxdepth 1 -name '.zshrc.bak.*' | wc -l)
  check "zshrc backups are capped (got $nbak, cap is 6)" \
    "$([[ $nbak -le 6 ]] && echo 0 || echo 1)"

  # A reinstall must keep files the user added to the managed directories and
  # still prune theme files that are no longer shipped.
  bg="$root/home/.config/omarchy/backgrounds/virtual-paradise"
  : >"$bg/my-user.mp4"
  : >"$bg/old-theme.mp4"
  printf 'old-theme.mp4\n' >>"$bg/.vp-files"
  run_installer "$root" >/dev/null 2>&1
  check "a reinstall keeps a user's own wallpaper" \
    "$([[ -f "$bg/my-user.mp4" ]] && echo 0 || echo 1)"
  check "a reinstall prunes a theme wallpaper that is gone" \
    "$([[ ! -f "$bg/old-theme.mp4" ]] && echo 0 || echo 1)"

  # --hook is the light path: overrides + layout only, never a full install.
  rm -rf "$root/home/.config/omarchy/themes/virtual-paradise"
  hook_rc=$( ( cd "$REPO_DIR" \
    && PATH="$root/bin:$PATH" HOME="$root/home" \
       XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
       SHIM_LOG="$root/shim.log" timeout 120 bash ./install.sh --hook ) >/dev/null 2>&1; echo $? )
  check "--hook exits 0" "$([[ "$hook_rc" == "0" ]] && echo 0 || echo 1)" "rc=$hook_rc"
  check "--hook does not run the full install" \
    "$([[ ! -d "$root/home/.config/omarchy/themes/virtual-paradise" ]] && echo 0 || echo 1)"
  check "the diagnose report is installed as paradise-diagnose" \
    "$([[ -L "$root/home/.local/bin/paradise-diagnose" ]] && echo 0 || echo 1)"

  # The Island Bar must be offered as a first-party plugin and never silently
  # left half-installed in the user-writable dir.
  check "no __USER__ placeholder survives into the installed shell.json" \
    "$(grep -q '__USER__' "$root/home/.config/omarchy/shell.json" && echo 1 || echo 0)"

  # A renamed or dropped widget file must not linger in the installed plugin
  # dir, where Quickshell would keep loading it. Derive the user rather than
  # assuming one, or the guard below silently skips the case on any other host.
  installed_clock="$root/home/.config/omarchy/plugins/${USER:-$(id -un)}.clock"
  if [[ -d $installed_clock ]]; then
    touch "$installed_clock/Removed.qml" "$installed_clock/stale.json"
    run_installer "$root" >/dev/null 2>&1
    check "installer prunes stale files from installed plugins" \
      "$([[ ! -e "$installed_clock/Removed.qml" && ! -e "$installed_clock/stale.json" ]] && echo 0 || echo 1)"
  fi

  # The same for helper scripts: a script the repository no longer ships must
  # not keep answering to a name the documentation dropped.
  printf '#!/bin/sh\n' >"$root/home/.local/bin/widgets.sh"
  run_installer "$root" >/dev/null 2>&1
  check "installer removes helper scripts the theme no longer ships" \
    "$([[ ! -e "$root/home/.local/bin/widgets.sh" ]] && echo 0 || echo 1)"

  python3 - "$root/home/.config/omarchy/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ids = [e.get("id") for s in ("left", "center", "right") for e in d["bar"]["layout"][s]]
missing = [i for i in ("io.github.woogy7.vitals",) if i not in ids]
sys.exit(1 if missing else 0)
PY
  check "shell.json references the Vitals widget" $?

  python3 - "$root/home/.config/omarchy/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
bar = d["bar"]
# transparent must stay true: the island design treats the gaps between
# islands as see-through, and false paints an opaque strip through them.
sys.exit(0 if bar.get("transparent") is True else 1)
PY
  check "bar.transparent is true in the shipped layout" $?

  # The world clock is merged into the clock's calendar dropdown; the
  # third-party notification bell left the layout (the stock service owns
  # notifications now).
  python3 - "$root/home/.config/omarchy/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ids = [e.get("id") for s in ("left", "center", "right") for e in d["bar"]["layout"][s]]
clock = next(e for e in d["bar"]["layout"]["center"] if str(e.get("id", "")).endswith("clock"))
ok = ("omarchy.elsewhen" not in ids
      and "jankeesvw.notification-center" not in ids
      and isinstance(clock.get("worldZones"), list) and len(clock.get("worldZones")) > 0)
sys.exit(0 if ok else 1)
PY
  check "the clock carries the world clock and no standalone panel does" $?

  # The minimal layout: the right island keeps the five essentials plus the
  # Tools button, the specialized widgets are mounted hidden behind it,
  # indicators only take space while one is active, and the active-window
  # label is capped.
  python3 - "$root/home/.config/omarchy/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
right = d["bar"]["layout"]["right"]
# The installer renders __USER__, but the CI container has no USER in the
# environment. Derive the prefix from the installed layout instead of the
# test process so the assertion is about the theme, not the runner.
net = next(e for e in right if str(e.get("id", "")).endswith(".network"))
user = str(net.get("id", ""))[:-len(".network")]
visible = [e.get("id") for e in right if not e.get("hidden")]
hidden = [e.get("id") for e in right if e.get("hidden")]
want = ["omarchy.tray", user + ".network", "ssupt.audio-control",
        "onlyvishesh.power-manager", user + ".system-update", user + ".tools"]
special = ["io.github.randazraik.xray", "io.github.grichard99.omaproton-vpn",
           "io.github.kristoferlund.webcam", "crmne.hyprmoncfg",
           "io.github.jeffcortez23.omarchy-projector-cast", "ssupt.bluetooth-audio"]
indicators = next(e for e in d["bar"]["layout"]["center"] if str(e.get("id", "")).endswith("indicators"))
active = next(e for e in d["bar"]["layout"]["left"] if str(e.get("id", "")).endswith("active-window"))
ok = (visible == want
      and hidden == special
      and not any(e.get("fold") for e in right)
      and indicators.get("alwaysShow") is False
      and 0 < int(active.get("maxWidth", 999)) <= 200)
sys.exit(0 if ok else 1)
PY
  check "the shipped layout is the minimal one" $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-4  Uninstaller: restores shell.json, removes units, leaves shell-default.
# ─────────────────────────────────────────────────────────────────────────────
if want tc4; then
  section "TC-4  Uninstaller"

  root="$(new_sandbox tc4)"
  build_shims "$root/bin"
  run_installer "$root" >/dev/null 2>&1

  run_uninstaller "$root"; check "uninstall exits 0" $? "$(strip_ansi "$root/uninstall.log" | tail -3)"

  C="$root/home/.config/omarchy"

  # A sandbox has no /usr/share/omarchy/config/omarchy/shell.json to snapshot,
  # so the honest invariant is: uninstall must either restore a real pristine
  # default, or preserve shell.json untouched. It must never leave the Paradise
  # layout in place while reporting success.
  if [[ -f "$C/shell-default.json" ]]; then
    diff -q "$C/shell.json" "$C/shell-default.json" >/dev/null
    check "shell.json is restored from shell-default.json" $?
    check "restored shell-default.json is not our own layout" \
      "$(grep -q '__USER__\|woogy7\.vitals' "$C/shell-default.json" && echo 1 || echo 0)" \
      "shell-default.json was seeded from the Paradise template"
  else
    ok "no pristine default available; shell.json preserved instead"
    grep -q 'Preserving' "$root/uninstall.log"
    check "uninstall says it preserved shell.json" $?
    check "shell.json still exists after uninstall" \
      "$([[ -f "$C/shell.json" ]] && echo 0 || echo 1)"
  fi

  check "theme directory removed" \
    "$([[ ! -d "$C/themes/virtual-paradise" ]] && echo 0 || echo 1)"

  check "paradise systemd units removed" \
    "$([[ -z "$(find "$root/home/.config/systemd/user" -name 'paradise-*' -print -quit 2>/dev/null)" ]] && echo 0 || echo 1)"

  # The uninstaller advertises this directory as a recovery point, so it must
  # actually contain the files it removed.
  snap=$(grep -o 'Backup snapshot: .*' "$root/uninstall.log" | sed 's/Backup snapshot: //')
  if [[ -n $snap && -d $snap ]]; then
    n=$(find "$snap" -type f | wc -l)
    check "uninstall backup snapshot is not empty ($n files)" \
      "$([[ $n -gt 0 ]] && echo 0 || echo 1)"
  else
    fail "uninstall backup snapshot is not empty" "no snapshot directory reported"
  fi

  # shell-default.json only exists when a pristine default was available to
  # snapshot, so assert on the decision rather than on the file.
  if [[ -f "$C/shell-default.json" ]]; then
    ok "shell-default.json kept without --purge-defaults"
  else
    grep -q 'No pristine Omarchy shell.json found' "$root/install.log"
    check "installer explains why shell-default.json was skipped" $?
  fi

  # The purge flags are about shell-default.json, so seed the file explicitly.
  # Whether the installer creates it depends on Omarchy being present, and these
  # two cases must test the flag semantics rather than the environment.
  run_installer "$root" >/dev/null 2>&1
  printf '{"seeded":true}\n' >"$C/shell-default.json"

  # --keep-backups must be honoured wherever it appears in argv, not just as $1.
  run_uninstaller "$root" --purge-defaults --keep-backups
  check "uninstall with --keep-backups and --purge-defaults exits 0" $?
  # --keep-backups short-circuits the whole block, so nothing is printed; the
  # invariant is simply that the file survives despite --purge-defaults.
  check "--keep-backups wins over --purge-defaults regardless of order" \
    "$([[ -f "$C/shell-default.json" ]] && echo 0 || echo 1)"

  run_installer "$root" >/dev/null 2>&1
  printf '{"seeded":true}\n' >"$C/shell-default.json"
  run_uninstaller "$root" --purge-defaults
  check "--purge-defaults alone removes shell-default.json" \
    "$([[ -f "$C/shell-default.json" ]] && echo 1 || echo 0)"

  run_uninstaller "$root" --not-a-flag
  check "an unknown flag is rejected" "$([[ $? -ne 0 ]] && echo 0 || echo 1)"

  # The installed uninstaller must be self-contained. It runs from the theme's
  # data directory with the libs and payload it needs next to it, so it can
  # remove the boot/login themes and respect a custom shell.json even when the
  # repository is gone. It used to be a lone copy in ~/.local/bin.
  root2="$(new_sandbox tc4-installed)"
  build_shims "$root2/bin"
  run_installer "$root2" >/dev/null 2>&1
  payload="$root2/home/.local/share/virtual-paradise"
  check "installed uninstaller payload carries the boot-theme libs" \
    "$([[ -f "$payload/lib/sddm.sh" && -f "$payload/lib/plymouth.sh" \
      && -f "$payload/lib/shell-layout.sh" ]] && echo 0 || echo 1)"
  check "installed uninstaller wrapper execs the payload" \
    "$(grep -q 'exec .*uninstall.sh' "$root2/home/.local/bin/uninstall-virtual-paradise" && echo 0 || echo 1)"

  C2="$root2/home/.config/omarchy"
  printf '{"bar":{"layout":{"left":[{"id":"my.custom"}]}}}\n' >"$C2/shell.json"
  ( PATH="$root2/bin:$PATH" HOME="$root2/home" XDG_CONFIG_HOME="$root2/home/.config" \
    XDG_STATE_HOME="$root2/home/.local/state" XDG_DATA_HOME="$root2/home/.local/share" \
    SHIM_LOG="$root2/shim.log" timeout 900 \
    bash "$root2/home/.local/bin/uninstall-virtual-paradise" \
    >"$root2/uninstall-installed.log" 2>&1 )
  check "installed uninstaller exits 0" "$?" \
    "$(strip_ansi "$root2/uninstall-installed.log" | tail -3)"
  check "installed uninstaller preserves a custom shell.json" \
    "$(grep -q 'my.custom' "$C2/shell.json" && echo 0 || echo 1)"
  check "installed uninstaller removes its payload" \
    "$([[ ! -d "$payload" ]] && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-5  XDG_CONFIG_HOME: paths follow XDG, not a hardcoded ~/.config.
# ─────────────────────────────────────────────────────────────────────────────
if want tc5; then
  section "TC-5  Custom XDG_CONFIG_HOME"

  root="$(new_sandbox tc5)"
  mkdir -p "$root/xdg"
  build_shims "$root/bin"

  ( cd "$REPO_DIR" && PATH="$root/bin:$PATH" HOME="$root/home" \
      XDG_CONFIG_HOME="$root/xdg" XDG_STATE_HOME="$root/xdg-state" XDG_DATA_HOME="$root/xdg-data" SHIM_LOG="$root/shim.log" \
      timeout 900 bash ./install.sh --user-only --no-boot >"$root/install.log" 2>&1 )
  check "install honours XDG_CONFIG_HOME" $? "$(strip_ansi "$root/install.log" | tail -3)"

  check "theme landed under XDG_CONFIG_HOME" \
    "$([[ -d "$root/xdg/omarchy/themes/virtual-paradise" ]] && echo 0 || echo 1)"
  check "nothing was written to the default ~/.config" \
    "$([[ -d "$root/home/.config/omarchy/themes" ]] && echo 1 || echo 0)"
  # The theme is a payload, not a second checkout: repo boilerplate must not
  # leak into it. This is asserted while the theme exists, which is why it lives
  # here rather than in TC-4 where uninstall has already removed it.
  stray=""
  for junk in install.sh uninstall.sh README.md LICENSE .gitignore tests .github .githooks tools CONTRIBUTING.md \
              plugins bars bin lib shell systemd sddm plymouth micro cava fastfetch; do
    [[ -e "$root/xdg/omarchy/themes/virtual-paradise/$junk" ]] && stray="$stray $junk"
  done
  check "theme payload has no repo boilerplate" \
    "$([[ -z $stray ]] && echo 0 || echo 1)" "found:$stray"

  check "systemd units landed under XDG_CONFIG_HOME" \
    "$([[ -f "$root/xdg/systemd/user/paradise-audio-watchdog.timer" ]] && echo 0 || echo 1)"
  check "theme-set hook landed under XDG_CONFIG_HOME" \
    "$([[ -f "$root/xdg/omarchy/hooks/theme-set.d/virtual-paradise.sh" ]] && echo 0 || echo 1)"

  hook="$root/xdg/omarchy/hooks/theme-set.d/virtual-paradise.sh"
  if [[ -f $hook ]]; then
    bash -n "$hook" 2>/dev/null
    check "generated hook parses" $?
    grep -q 'XDG_CONFIG_HOME' "$hook"
    check "generated hook resolves its config dir from XDG_CONFIG_HOME" $?
  fi

  ( cd "$REPO_DIR" && PATH="$root/bin:$PATH" HOME="$root/home" \
      XDG_CONFIG_HOME="$root/xdg" XDG_STATE_HOME="$root/xdg-state" XDG_DATA_HOME="$root/xdg-data" SHIM_LOG="$root/shim.log" \
      timeout 900 bash ./uninstall.sh >"$root/uninstall.log" 2>&1 )
  check "uninstall honours XDG_CONFIG_HOME" $?
  check "uninstall removes the units it installed under XDG" \
    "$([[ -z "$(find "$root/xdg/systemd/user" -name 'paradise-*' -print -quit 2>/dev/null)" ]] && echo 0 || echo 1)"
  check "uninstall removes the theme under XDG" \
    "$([[ -d "$root/xdg/omarchy/themes/virtual-paradise" ]] && echo 1 || echo 0)"

  # Regression: the override layer caches its paths at source time, so it must
  # be initialised after the target user's home is known. Sourcing it at the top
  # of install.sh made a plain `sudo ./install.sh` patch /root/.config and leave
  # the user's plugins untouched.
  cfg_line="$(grep -n 'export PARADISE_CONFIG_DIR=' "$REPO_DIR/install.sh" | head -1 | cut -d: -f1)"
  src_line="$(grep -nF '. "$REPO_DIR/lib/plugin-overrides.sh"' "$REPO_DIR/install.sh" | head -1 | cut -d: -f1)"
  check "the override layer initialises after the user home is known" \
    "$([[ -n $cfg_line && -n $src_line && $cfg_line -lt $src_line ]] && echo 0 || echo 1)" \
    "config=$cfg_line source=$src_line"
  check "the override state honours XDG_STATE_HOME" \
    "$(grep -q 'XDG_STATE_HOME' "$REPO_DIR/lib/plugin-overrides.sh" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-6  No pristine Omarchy layout: the default snapshot must not be faked.
#
# Where the regression lived: with /usr/share/omarchy/config/omarchy/shell.json
# absent, the installer used to fall back to copying whatever shell.json it found
# - which by then was its own Paradise layout. shell-default.json then held the
# rice, and uninstall "restored" it. Every CI run reproduced this; no machine
# with a complete Omarchy install ever would.
# ─────────────────────────────────────────────────────────────────────────────
if want tc6; then
  section "TC-6  Missing Omarchy default layout"

  root="$(new_sandbox tc6)"
  build_shims "$root/bin"
  C="$root/home/.config/omarchy"

  ( cd "$REPO_DIR" && PATH="$root/bin:$PATH" HOME="$root/home" \
      XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" SHIM_LOG="$root/shim.log" \
      OMARCHY_SHELL_DEFAULT_SRC="$root/nonexistent/omarchy/shell.json" \
      timeout 900 bash ./install.sh --user-only --no-boot >"$root/install.log" 2>&1 )
  check "install succeeds with no Omarchy layout to snapshot" $? \
    "$(strip_ansi "$root/install.log" | tail -3)"

  check "the Paradise layout is in place" \
    "$(grep -q 'woogy7.vitals' "$C/shell.json" && echo 0 || echo 1)"

  if [[ -f "$C/shell-default.json" ]]; then
    grep -qE '__USER__\.|woogy7\.vitals' "$C/shell-default.json"
    if [[ $? -eq 0 ]]; then
      fail "shell-default.json is not seeded from our own layout" \
        "it is a copy of the Paradise template"
    else
      ok "shell-default.json is not seeded from our own layout"
    fi
  else
    ok "shell-default.json not created rather than faked"
    install_plain="$(strip_ansi "$root/install.log")"
    grep -q 'No pristine Omarchy shell.json found' <<<"$install_plain"
    check "installer explains why there is no shell-default.json" $?
  fi

  cp "$C/shell.json" "$root/before-uninstall"
  ( cd "$REPO_DIR" && PATH="$root/bin:$PATH" HOME="$root/home" \
      XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" SHIM_LOG="$root/shim.log" \
      timeout 900 bash ./uninstall.sh >"$root/uninstall.log" 2>&1 )
  check "uninstall succeeds" $?
  uninstall_plain="$(strip_ansi "$root/uninstall.log")"
  grep -q 'Preserving' <<<"$uninstall_plain"
  check "uninstall says it preserved shell.json" $?
  diff -q "$root/before-uninstall" "$C/shell.json" >/dev/null
  check "preserved shell.json is untouched" $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-7  User config is restored on uninstall.
#
# The installer overwrites ~/.zshrc and edits ghostty/fcitx5/micro in place. It
# made backups, but uninstall never restored them, so uninstalling left the
# rice's shell/terminal/input/editor settings behind and an orphaned .bak that
# nobody would think to look for.
# ─────────────────────────────────────────────────────────────────────────────
if want tc7; then
  section "TC-7  Uninstall restores user config"

  root="$(new_sandbox tc7)"
  build_shims "$root/bin"
  H="$root/home"
  C="$H/.config"

  # Pre-seed files with recognisable content so restoration is provable.
  mkdir -p "$C/ghostty" "$C/fcitx5" "$C/micro/colorschemes" "$C/hypr" "$C/yazi" "$C/tmux"
  printf 'export ORIGINAL_ZSHRC=1\n' >"$H/.zshrc"
  printf '# user ghostty config\ntheme = user-theme\n' >"$C/ghostty/config"
  printf '[Groups/0]\nName=UserProfile\n' >"$C/fcitx5/profile"
  printf '{"user":"micro"}\n' >"$C/micro/settings.json"
  printf '# user yazi theme\n' >"$C/yazi/theme.toml"
  printf '# user tmux config\n' >"$C/tmux/tmux.conf"
  printf '# user look and feel\n' >"$C/hypr/looknfeel.lua"
  printf -- '-- user bindings\n' >"$C/hypr/bindings.lua"
  printf -- '-- user input tuning\n' >"$C/hypr/input.lua"
  printf -- '-- user autostart\n' >"$C/hypr/autostart.lua"
  # The note contains "GNOME Network Displays": an older guard keyed on that
  # string and skipped installing the window rules because of a user comment.
  printf -- '-- user hyprland config\n-- my own GNOME Network Displays note\nrequire("default.hypr.omarchy")\n' \
    >"$C/hypr/hyprland.lua"

  run_installer "$root" >/dev/null 2>&1
  check "install exits 0" $?

  # Sanity: the installer really did take over these files.
  ! grep -q 'ORIGINAL_ZSHRC' "$H/.zshrc"
  check "installer replaced ~/.zshrc" $?
  check "installer backed up ghostty config" \
    "$([[ -f "$C/ghostty/config.paradise.bak" ]] && echo 0 || echo 1)"
  check "installer backed up fcitx5 profile" \
    "$([[ -f "$C/fcitx5/profile.paradise.bak" ]] && echo 0 || echo 1)"
  check "installer backed up micro settings" \
    "$([[ -f "$C/micro/settings.json.paradise.bak" ]] && echo 0 || echo 1)"
  check "installer backed up the yazi theme" \
    "$([[ -f "$C/yazi/theme.toml.paradise.bak" ]] && echo 0 || echo 1)"
  check "installer replaced the yazi theme" \
    "$(grep -q '#00ffdd' "$C/yazi/theme.toml" 2>/dev/null && echo 0 || echo 1)"
  check "installer added the bat theme" \
    "$([[ -f "$C/bat/themes/VirtualParadise.tmTheme" ]] && echo 0 || echo 1)"
  check "installer sourced the tmux theme" \
    "$(grep -q 'Virtual☆Paradise tmux theme' "$C/tmux/tmux.conf" 2>/dev/null \
      && [[ -f "$C/tmux/paradise.conf" ]] && echo 0 || echo 1)"
  check "installer added the window-rule block despite the user's note" \
    "$(grep -q 'Virtual Paradise Add-on Window Rules' "$C/hypr/hyprland.lua" && echo 0 || echo 1)"

  # A second run must be safe. Uninstall used to restore the newest snapshot
  # (which is the themed file from the re-install), leaving Paradise bindings
  # behind after the theme was removed — the SUPER+RETURN double-terminal bug.
  run_installer "$root" >/dev/null 2>&1
  check "a second install exits 0" $?
  check "re-install keeps a single window-rule block" \
    "$([[ $(grep -c 'Virtual Paradise Add-on Window Rules' "$C/hypr/hyprland.lua") -eq 1 ]] && echo 0 || echo 1)"

  run_uninstaller "$root" >/dev/null 2>&1
  check "uninstall exits 0" $?

  grep -q 'ORIGINAL_ZSHRC' "$H/.zshrc" 2>/dev/null
  check "the zshrc is restored to the original" $?
  grep -q 'user-theme' "$C/ghostty/config" 2>/dev/null
  check "ghostty config restored to the original" $?
  grep -q 'UserProfile' "$C/fcitx5/profile" 2>/dev/null
  check "fcitx5 profile restored to the original" $?
  grep -q '"user":"micro"' "$C/micro/settings.json" 2>/dev/null
  check "micro settings restored to the original" $?
  grep -q 'user yazi theme' "$C/yazi/theme.toml" 2>/dev/null
  check "yazi theme restored to the original" $?
  check "the bat theme is removed" \
    "$([[ ! -f "$C/bat/themes/VirtualParadise.tmTheme" ]] && echo 0 || echo 1)"
  grep -q 'user tmux config' "$C/tmux/tmux.conf" 2>/dev/null
  check "tmux config restored to the original" $?
  check "the tmux theme file is removed" \
    "$([[ ! -f "$C/tmux/paradise.conf" ]] && echo 0 || echo 1)"
  grep -q 'user look and feel' "$C/hypr/looknfeel.lua" 2>/dev/null
  check "hypr looknfeel restored to the original" $?
  grep -q -- '-- user bindings' "$C/hypr/bindings.lua" 2>/dev/null
  check "hypr bindings restored to the original after a re-install" $?
  grep -q -- '-- user input tuning' "$C/hypr/input.lua" 2>/dev/null
  check "hypr input restored to the original after a re-install" $?
  check "the wallpaper hook is gone from the user's autostart" \
    "$(grep -q -- '-- user autostart' "$C/hypr/autostart.lua" 2>/dev/null \
       && ! grep -q 'toggle_live_wallpaper' "$C/hypr/autostart.lua" && echo 0 || echo 1)"
  check "the login chime hook is gone from the user's autostart" \
    "$(grep -q 'vp-sound.sh' "$C/hypr/autostart.lua" 2>/dev/null && echo 1 || echo 0)"
  check "the window-rule block is removed" \
    "$(grep -q 'Virtual Paradise Add-on Window Rules' "$C/hypr/hyprland.lua" && echo 1 || echo 0)"
  check "the user's own hyprland line survives" \
    "$(grep -q 'my own GNOME Network Displays note' "$C/hypr/hyprland.lua" && echo 0 || echo 1)"
  check "the hypr snapshot state file is removed" \
    "$([[ ! -f "$H/.local/state/virtual-paradise/hypr-backup-dir" ]] && echo 0 || echo 1)"

  # Backups are ours to clean up once consumed.
  check "consumed .paradise.bak files are removed" \
    "$([[ -z "$(find "$C" -name '*.paradise.bak' -print -quit 2>/dev/null)" ]] && echo 0 || echo 1)"
  check "the zshrc.zwc cache is removed" \
    "$([[ -f "$H/.zshrc.zwc" ]] && echo 1 || echo 0)"

  # A zshrc the installer created from nothing must be removed, not left behind.
  root2="$(new_sandbox tc7b)"
  build_shims "$root2/bin"
  run_installer "$root2" >/dev/null 2>&1
  run_uninstaller "$root2" >/dev/null 2>&1
  check "a zshrc created by the installer is removed" \
    "$([[ -f "$root2/home/.zshrc" ]] && echo 1 || echo 0)"

  # Files the installer drops in with no user original must also be taken back
  # out: a btop theme, the fastfetch config and logos, and the hypr files it
  # ships verbatim would otherwise survive uninstall unnoticed.
  check "the btop theme is removed" \
    "$([[ -f "$root2/home/.config/btop/themes/virtual-paradise.theme" ]] && echo 1 || echo 0)"
  check "the fastfetch config is removed" \
    "$([[ -f "$root2/home/.config/fastfetch/config.jsonc" ]] && echo 1 || echo 0)"
  check "the fastfetch logos are removed" \
    "$([[ -f "$root2/home/.config/fastfetch/logo.txt" ]] && echo 1 || echo 0)"
  check "a hypr config created by the installer is removed" \
    "$([[ -f "$root2/home/.config/hypr/looknfeel.lua" ]] && echo 1 || echo 0)"

  # Without a snapshot, a hypr file the user edited must survive uninstall. The
  # old code treated "no snapshot" as "the file is ours" and deleted it.
  root3="$(new_sandbox tc7c)"
  build_shims "$root3/bin"
  run_installer "$root3" >/dev/null 2>&1
  printf -- '-- user addition\n' >>"$root3/home/.config/hypr/bindings.lua"
  rm -rf "$root3/home/.config/hypr"/backup_*
  rm -f "$root3/home/.local/state/virtual-paradise/hypr-backup-dir"
  run_uninstaller "$root3" >/dev/null 2>&1
  check "a user-edited hypr file with no snapshot is preserved" \
    "$(grep -q -- '-- user addition' "$root3/home/.config/hypr/bindings.lua" 2>/dev/null && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-8  The theme-set hook, both directions.
#
# This is the most intricate code in the repo - ~150 lines generated through a
# quoted heredoc - and the only place that decides which widgets exist on the
# bar. It had a live bug: leaving the theme chained
# `disable ssupt.audio-control || enable omarchy.audio`, so the stock widget was
# only enabled when the disable *failed*, and switching away from Virtual
# Paradise left the bar with no audio widget at all.
# ─────────────────────────────────────────────────────────────────────────────
if want tc8; then
  section "TC-8  Theme-set hook"

  root="$(new_sandbox tc8)"
  build_shims "$root/bin"
  run_installer "$root" >/dev/null 2>&1

  hook="$root/home/.config/omarchy/hooks/theme-set.d/virtual-paradise.sh"
  check "hook was generated" "$([[ -f $hook ]] && echo 0 || echo 1)"
  bash -n "$hook" 2>/dev/null
  check "hook parses" $?

  # Run the hook as Omarchy would, with the shimmed omarchy recording argv.
  run_hook() {
    : >"$root/shim.log"
    ( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
        SHIM_LOG="$root/shim.log" timeout 120 bash "$hook" "$1" >/dev/null 2>&1 )
  }

  run_hook "virtual-paradise"
  grep -q 'plugin enable ssupt.audio-control' "$root/shim.log"
  check "entering the theme enables the custom audio widget" $?
  grep -q 'plugin disable omarchy.audio' "$root/shim.log"
  check "entering the theme disables the stock audio widget" $?
  grep -q 'plugin enable crmne.hyprmoncfg' "$root/shim.log"
  check "entering the theme enables hyprmoncfg behind the Tools menu" $?

  run_hook "Catppuccin"
  grep -q 'plugin disable ssupt.audio-control' "$root/shim.log"
  check "leaving the theme disables the custom audio widget" $?
  # The regression: with `disable A || enable B`, B only ran when A failed, so
  # this line never appeared while the disable succeeded.
  grep -q 'plugin enable omarchy.audio' "$root/shim.log"
  check "leaving the theme enables the stock audio widget" $?
  grep -q 'plugin enable omarchy.bar' "$root/shim.log"
  check "leaving the theme restores the stock bar" $?

  run_hook "Tokyo Night"
  grep -q 'plugin enable omarchy.audio' "$root/shim.log"
  check "the restore path also runs for other themes" $?

  # Data-loss regression: the user's fastfetch and GTK files must come back
  # after leaving the theme, instead of being deleted or left overwritten.
  mkdir -p "$root/home/.config/fastfetch" "$root/home/.config/gtk-4.0"
  printf '{"custom":true}\n' >"$root/home/.config/fastfetch/config.jsonc"
  printf '/* user gtk */\n' >"$root/home/.config/gtk-4.0/gtk.css"
  run_hook "virtual-paradise"
  run_hook "Catppuccin"
  grep -q '"custom":true' "$root/home/.config/fastfetch/config.jsonc"
  check "leaving the theme restores the user's fastfetch config" $?
  grep -q 'user gtk' "$root/home/.config/gtk-4.0/gtk.css"
  check "leaving the theme restores the user's GTK css" $?
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-9  Wallpaper playlist.
#
# get_live_items used to echo the array joined onto one line. That was fine
# while callers split with `items=($(...))`, but a shellcheck fix moved them to
# `mapfile`, which splits on newlines - so every caller saw a single item and
# the cycle only ever played the last wallpaper. The output format and the
# reader have to agree.
# ─────────────────────────────────────────────────────────────────────────────
if want tc9; then
  section "TC-9  Wallpaper playlist"

  root="$(new_sandbox tc9)"
  bg="$root/home/.config/omarchy/themes/virtual-paradise/backgrounds"
  mkdir -p "$bg" "$root/home/.local/state/omarchy/current"
  echo virtual-paradise >"$root/home/.local/state/omarchy/current/theme.name"
  for f in Miku_live.mp4 Miku_missing.mp4 Miku_animated_full.mp4 \
           Miku_animated1.mp4 Miku_animated2.mp4 Miku_animated3.mp4 \
           Miku_animated4.mp4; do
    : >"$bg/$f"
  done

  out=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" \
    bash "$REPO_DIR/bin/toggle_live_wallpaper.sh" list 2>&1 )
  count=$(printf '%s\n' "$out" | grep -c '•')
  check "the playlist reports all 7 files, not just the last (got $count)" \
    "$([[ $count -eq 7 ]] && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-10  SDDM theme: installed on its own, never patched into Omarchy's theme.
#
# install.sh used to copy its QML and a 13 MB gif over
# /usr/share/sddm/themes/omarchy, a directory owned by the omarchy-settings
# package. Package updates reverted half of it, and uninstall.sh had nothing to
# restore, so users were left with a broken login screen. The theme now lives in
# /usr/share/sddm/themes/virtual-paradise and the selection in a drop-in; these
# checks run the real lib/sddm.sh against a throwaway system root.
# ─────────────────────────────────────────────────────────────────────────────
if want tc10; then
  section "TC-10  SDDM theme install/remove"

  root="$(new_sandbox tc10)"
  sys="$root/sys"
  theme="$sys/usr/share/sddm/themes/virtual-paradise"
  conf="$sys/etc/sddm.conf.d/zz-virtual-paradise-theme.conf"
  stock_dir="$sys/usr/share/omarchy/default/sddm/omarchy"
  legacy_dir="$sys/usr/share/sddm/themes/omarchy"

  mkdir -p "$stock_dir" "$legacy_dir" "$sys/etc/sddm.conf.d" "$sys/usr/lib/sddm/sddm.conf.d"
  printf '// stock omarchy theme\n' >"$stock_dir/Main.qml"
  cp "$stock_dir/Main.qml" "$legacy_dir/Main.qml"
  printf '[General]\n' >"$legacy_dir/theme.conf"
  printf '[Theme]\nCurrent=omarchy\n' >"$sys/etc/sddm.conf.d/99-omarchy-login.conf"

  # Reproduce what the old installer left behind: our QML and the gif copied
  # into the package-owned omarchy theme.
  cp "$REPO_DIR/sddm/Main.qml" "$legacy_dir/Main.qml"
  printf 'gif\n' >"$legacy_dir/Miku_animated_full.gif"

  vp_sddm() { ( . "$REPO_DIR/lib/sddm.sh"; "$@" ); }

  vp_sddm sddm_theme_install "$sys" "$REPO_DIR" >"$root/sddm-install.log" 2>&1
  check "SDDM theme install exits 0" $? "$(tail -3 "$root/sddm-install.log")"

  check "the theme is installed in its own directory" \
    "$([[ -f $theme/Main.qml ]] && echo 0 || echo 1)"
  check "theme.conf and metadata.desktop are installed" \
    "$([[ -f $theme/theme.conf && -f $theme/metadata.desktop ]] && echo 0 || echo 1)"
  check "the splash picture is installed" \
    "$([[ -f $theme/still.png ]] && echo 0 || echo 1)"
  check "the Plymouth backdrop and frame come along" \
    "$([[ -f $theme/backdrop.png && -f $theme/frame.png ]] && echo 0 || echo 1)"
  check "every asset referenced by Main.qml exists" \
    "$(vp_sddm sddm_theme_verify "$sys" >/dev/null 2>&1 && echo 0 || echo 1)"
  check "Main.qml is marked as ours (so uninstall can be safe)" \
    "$(grep -qF 'Virtual☆Paradise SDDM theme' "$theme/Main.qml" && echo 0 || echo 1)"
  check "the drop-in selects virtual-paradise" \
    "$(grep -qx 'Current=virtual-paradise' "$conf" && echo 0 || echo 1)"

  # The greeter has to continue the Plymouth splash, not start a new picture.
  check "the greeter uses the Plymouth backdrop" \
    "$(grep -q 'source: "backdrop.png"' "$theme/Main.qml" && echo 0 || echo 1)"
  check "the greeter uses the Plymouth frame" \
    "$(grep -q 'source: "frame.png"' "$theme/Main.qml" && echo 0 || echo 1)"
  check "the greeter uses the splash still" \
    "$(grep -q 'source: "still.png"' "$theme/Main.qml" && echo 0 || echo 1)"
  check "the greeter fades in and out" \
    "$(grep -q 'onLoginSucceeded' "$theme/Main.qml" && echo 0 || echo 1)"
  # The password field is the one thing the user has to look at.
  check "the password field is a labelled neon panel" \
    "$(grep -q 'ENTER PASSWORD' "$theme/Main.qml" && grep -q 'border.color' "$theme/Main.qml" && echo 0 || echo 1)"

  # A rebuild of the boot image that fails silently leaves the old splash on
  # screen, and the installer used to report success anyway.
  check "the installer tries both boot image rebuilds" \
    "$(grep -q 'limine-mkinitcpio' "$REPO_DIR/lib/step-boot.sh" && grep -q 'mkinitcpio -P' "$REPO_DIR/lib/step-boot.sh" && echo 0 || echo 1)"
  check "the installer checks the boot image was really rebuilt" \
    "$(grep -q 'boot_image_age' "$REPO_DIR/lib/step-boot.sh" && echo 0 || echo 1)"
  check "the installer shows the rebuild output" \
    "$(grep -qE 'run_privileged (limine-mkinitcpio|mkinitcpio -P)[;"]' "$REPO_DIR/lib/step-boot.sh" && echo 0 || echo 1)"

  # The greeter is on screen for less than a second while Omarchy logs in
  # automatically, so the login screen needs a way to be shown.
  check "the installer can turn the autologin off" \
    "$(grep -q 'disable_autologin' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the uninstaller restores the autologin" \
    "$(grep -q 'autologin.conf.paradise.bak' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # --boot-only must report failure when neither theme can be installed,
  # instead of printing success. Stub both installers and the privileged
  # helpers, then call the real function.
  boot_rc=$( BOOT_ONLY=1 ENABLE_BOOT=1 NO_AUTOLOGIN=0 TOTAL_STEPS=10 \
    bash -c '
      REPO_DIR="$1"
      . "$1/lib/step-boot.sh"
      INSTALL_SDDM_THEME() { return 1; }
      INSTALL_PLYMOUTH_THEME() { return 1; }
      run_privileged() { return 0; }
      limine-mkinitcpio() { return 0; }
      mkinitcpio() { return 0; }
      boot_image_age() { printf "/boot/EFI/Linux/x.efi 1\n"; }
      log_step() { :; }; log_sub() { :; }; log_warn() { :; }; log_info() { :; }
      INSTALL_BOOT_ANIMATIONS >/dev/null 2>&1
      echo $?
    ' _ "$REPO_DIR" 2>&1 )
  check "--boot-only reports failure when neither theme installs" \
    "$([[ "$boot_rc" == "1" ]] && echo 0 || echo 1)" "rc=$boot_rc"

  # The Plymouth prompt must not cover the neon frame.
  check "the Plymouth password row sits below the picture" \
    "$(grep -q 'entry.y = global.top + global.frame_height' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"
  check "the Plymouth splash fades in" \
    "$(grep -q 'global.fade_frame' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"

  # The transition has to be seen, and it has to be usable for the way out.
  check "the wallpaper transition stays visible for a moment" \
    "$(grep -q 'minimumVisible' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "there is a transition for logout, reboot and shutdown" \
    "$([[ -f $REPO_DIR/bin/transition.sh ]] && grep -q 'omarchy system' "$REPO_DIR/bin/transition.sh" && echo 0 || echo 1)"
  check "the menu offers the transitions" \
    "$(grep -q 'paradise.shutdown' "$REPO_DIR/install.sh" && grep -q 'paradise.logout' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the greeter fades in like the splash" \
    "$(grep -q 'opacity = 1' "$REPO_DIR/sddm/Main.qml" && echo 0 || echo 1)"

  got_theme="$(vp_sddm sddm_effective_theme "$sys")"
  check "SDDM would load virtual-paradise, not omarchy (got ${got_theme:-none})" \
    "$([[ $got_theme == virtual-paradise ]] && echo 0 || echo 1)"

  check "the old in-place patch was repaired (gif removed)" \
    "$([[ ! -e $legacy_dir/Miku_animated_full.gif ]] && echo 0 || echo 1)"
  check "the stock omarchy Main.qml was restored" \
    "$(cmp -s "$stock_dir/Main.qml" "$legacy_dir/Main.qml" && echo 0 || echo 1)"

  # Repeated installs must converge: the theme is swapped in, not appended to.
  first="$(find "$theme" -type f -print0 | sort -z | xargs -0 sha256sum | sed "s|$theme/||" | sha256sum)"
  vp_sddm sddm_theme_install "$sys" "$REPO_DIR" >/dev/null 2>&1
  check "a second SDDM install exits 0" $?
  second="$(find "$theme" -type f -print0 | sort -z | xargs -0 sha256sum | sed "s|$theme/||" | sha256sum)"
  check "a second SDDM install rewrites nothing" \
    "$([[ $first == "$second" ]] && echo 0 || echo 1)"

  vp_sddm sddm_theme_remove "$sys" >"$root/sddm-remove.log" 2>&1
  check "SDDM theme remove exits 0" $?
  check "the theme directory is removed" "$([[ ! -e $theme ]] && echo 0 || echo 1)"
  check "the drop-in is removed" "$([[ ! -e $conf ]] && echo 0 || echo 1)"
  check "the stock omarchy theme is still stock" \
    "$(cmp -s "$stock_dir/Main.qml" "$legacy_dir/Main.qml" && echo 0 || echo 1)"

  got_theme="$(vp_sddm sddm_effective_theme "$sys")"
  check "uninstall restores the previous theme selection (got ${got_theme:-none})" \
    "$([[ $got_theme == omarchy ]] && echo 0 || echo 1)"

  # A foreign file at our drop-in path is preserved and put back.
  sys2="$root/sys2"
  mkdir -p "$sys2/etc/sddm.conf.d" "$sys2/usr/share/omarchy/default/sddm/omarchy"
  printf '# local admin override\n[Theme]\nCurrent=elarun\n' \
    >"$sys2/etc/sddm.conf.d/zz-virtual-paradise-theme.conf"
  vp_sddm sddm_theme_install "$sys2" "$REPO_DIR" >/dev/null 2>&1
  check "install backs up a foreign drop-in with the same name" \
    "$(grep -q 'Current=elarun' "$sys2/var/lib/virtual-paradise/sddm/previous-theme.conf" && echo 0 || echo 1)"
  vp_sddm sddm_theme_remove "$sys2" >/dev/null 2>&1
  check "remove restores the foreign drop-in" \
    "$(grep -q 'Current=elarun' "$sys2/etc/sddm.conf.d/zz-virtual-paradise-theme.conf" && echo 0 || echo 1)"

  # A directory with our theme name that we did not create is never deleted.
  sys3="$root/sys3"
  mkdir -p "$sys3/usr/share/sddm/themes/virtual-paradise"
  printf '// not ours\n' >"$sys3/usr/share/sddm/themes/virtual-paradise/Main.qml"
  vp_sddm sddm_theme_remove "$sys3" >/dev/null 2>&1
  check "remove leaves a theme it does not own alone" \
    "$([[ -f $sys3/usr/share/sddm/themes/virtual-paradise/Main.qml ]] && echo 0 || echo 1)"

  vp_sddm sddm_theme_install "$sys3" "$REPO_DIR" >"$root/sddm-foreign.log" 2>&1
  rc=$?
  check "install refuses to replace a theme it does not own" \
    "$([[ $rc -ne 0 ]] && echo 0 || echo 1)" "$(tail -2 "$root/sddm-foreign.log")"
  check "the foreign theme survives the refused install" \
    "$(grep -qx '// not ours' "$sys3/usr/share/sddm/themes/virtual-paradise/Main.qml" && echo 0 || echo 1)"

  check "install.sh installs SDDM through lib/sddm.sh" \
    "$(grep -q 'lib/sddm.sh' "$REPO_DIR/lib/step-boot.sh" && echo 0 || echo 1)"
  check "install.sh no longer patches the omarchy theme" \
    "$(grep -vE '^[[:space:]]*#' "$REPO_DIR/install.sh" | grep -q 'sddm/themes/omarchy' && echo 1 || echo 0)"
  check "uninstall.sh removes the SDDM theme" \
    "$(grep -q 'sddm_theme_remove' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # --sddm-only must reach the installer without touching Plymouth or the
  # initramfs. sudo is a shim here, so this checks the wiring, not the files.
  # Skipped as root: run_privileged would then execute the real install
  # against /, which the suite must never do.
  if (( EUID != 0 )); then
    mkdir -p "$root/bin" "$root/home-sddm"
    build_shims "$root/bin"
    ( cd "$REPO_DIR" \
      && PATH="$root/bin:$PATH" HOME="$root/home-sddm" \
         XDG_CONFIG_HOME="$root/home-sddm/.config" XDG_STATE_HOME="$root/home-sddm/.local/state" XDG_DATA_HOME="$root/home-sddm/.local/share" SHIM_LOG="$root/shim-sddm.log" \
         timeout 300 bash ./install.sh --sddm-only >"$root/sddm-only.log" 2>&1 )
    check "install.sh --sddm-only exits 0" $? "$(tail -3 "$root/sddm-only.log")"
    check "--sddm-only does not invoke Plymouth or mkinitcpio" \
      "$(grep -qE 'plymouth-set-default-theme|mkinitcpio|limine-mkinitcpio' "$root/shim-sddm.log" && echo 1 || echo 0)"
  else
    printf '  %sSKIP%s --sddm-only runs privileged commands (root)\n' "$DIM" "$OFF"
  fi

  # The login shell must be a path PAM accepts verbatim. `command -v zsh` can
  # return /usr/sbin/zsh, which pam_shells rejects when only the canonical path
  # is listed — a real login loop on this machine.
  if [[ -x /usr/bin/zsh ]]; then
    printf '/usr/sbin/zsh\n' >"$root/shells-sbin"
    got_shell="$( . "$REPO_DIR/lib/system.sh"; resolve_login_shell "$root/shells-sbin" )"
    check "the login-shell resolver never picks /usr/sbin/zsh (got ${got_shell:-none})" \
      "$([[ $got_shell == /usr/bin/zsh ]] && echo 0 || echo 1)"

    printf '/bin/zsh\n/usr/bin/zsh\n' >"$root/shells-ok"
    got_shell="$( . "$REPO_DIR/lib/system.sh"; resolve_login_shell "$root/shells-ok" )"
    check "a registered canonical zsh is kept (got ${got_shell:-none})" \
      "$([[ $got_shell == /usr/bin/zsh ]] && echo 0 || echo 1)"
  else
    printf '  %sSKIP%s zsh not installed\n' "$DIM" "$OFF"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-11  Plymouth theme: installed on its own, never patched into Omarchy's.
#
# install.sh used to overwrite /usr/share/plymouth/themes/omarchy/omarchy.script
# and drop ~330 generated PNGs into that package-owned directory. A package
# update reverted the animation, and uninstall.sh had nothing to restore. The
# theme now lives in /usr/share/plymouth/themes/virtual-paradise and is
# selected by name in /etc/plymouth/plymouthd.conf; these checks run the real
# lib/plymouth.sh against a throwaway system root.
# ─────────────────────────────────────────────────────────────────────────────
if want tc11; then
  section "TC-11  Plymouth theme install/remove"

  root="$(new_sandbox tc11)"
  sys="$root/sys"
  theme="$sys/usr/share/plymouth/themes/virtual-paradise"
  legacy_dir="$sys/usr/share/plymouth/themes/omarchy"
  stock_dir="$sys/usr/share/omarchy/default/plymouth"
  conf="$sys/etc/plymouth/plymouthd.conf"

  mkdir -p "$stock_dir" "$legacy_dir" "$sys/etc/plymouth"
  printf '# stock omarchy script\n' >"$stock_dir/omarchy.script"
  for asset in bullet.png entry.png lock.png logo.png progress_bar.png progress_box.png; do
    printf 'png' >"$stock_dir/$asset"
  done

  # Reproduce what the old installer left behind: our script and the generated
  # frames inside the package-owned omarchy theme.
  cp "$REPO_DIR/plymouth/virtual-paradise.script" "$legacy_dir/omarchy.script"
  printf 'png' >"$legacy_dir/intro-1.png"
  printf 'png' >"$legacy_dir/intro-259.png"
  printf 'png' >"$legacy_dir/outro-1.png"
  printf 'png' >"$legacy_dir/outro-72.png"
  printf 'png' >"$legacy_dir/background.png"
  printf '[Daemon]\nTheme=omarchy\n' >"$conf"

  vp_plymouth() { ( . "$REPO_DIR/lib/plymouth.sh"; "$@" ); }

  vp_plymouth plymouth_theme_install "$sys" "$REPO_DIR" >"$root/plymouth-install.log" 2>&1
  check "Plymouth theme install exits 0" $? "$(tail -3 "$root/plymouth-install.log")"

  check "the theme is installed in its own directory" \
    "$([[ -f $theme/virtual-paradise.plymouth ]] && echo 0 || echo 1)"
  check "the theme script is installed" \
    "$([[ -f $theme/virtual-paradise.script ]] && echo 0 || echo 1)"
  check "the animation frames are installed" \
    "$([[ -f $theme/intro-259.png && -f $theme/outro-72.png ]] && echo 0 || echo 1)"
  check "the stock assets are installed next to the frames" \
    "$([[ -f $theme/lock.png && -f $theme/progress_bar.png && -f $theme/entry.png ]] && echo 0 || echo 1)"
  check "the installed theme verifies" \
    "$(vp_plymouth plymouth_theme_verify "$sys" >/dev/null 2>&1 && echo 0 || echo 1)"
  check "the theme is marked as ours (so uninstall can be safe)" \
    "$(grep -qF 'Virtual☆Paradise Plymouth theme' "$theme/virtual-paradise.marker" && echo 0 || echo 1)"
  check "the selection points at virtual-paradise" \
    "$(grep -qx 'Theme=virtual-paradise' "$conf" && echo 0 || echo 1)"
  check "the descriptor points at the installed script" \
    "$(grep -qF "ScriptFile=$theme/virtual-paradise.script" "$theme/virtual-paradise.plymouth" && echo 0 || echo 1)"

  check "the old in-place patch was repaired (stock script restored)" \
    "$(cmp -s "$stock_dir/omarchy.script" "$legacy_dir/omarchy.script" && echo 0 || echo 1)"
  check "the generated frames were removed from the package theme" \
    "$([[ ! -e $legacy_dir/intro-259.png && ! -e $legacy_dir/background.png ]] && echo 0 || echo 1)"

  # Repeated installs must converge: the theme is swapped in, not appended to.
  first="$(find "$theme" -type f -print0 | sort -z | xargs -0 sha256sum | sed "s|$theme/||" | sha256sum)"
  vp_plymouth plymouth_theme_install "$sys" "$REPO_DIR" >/dev/null 2>&1
  check "a second Plymouth install exits 0" $?
  second="$(find "$theme" -type f -print0 | sort -z | xargs -0 sha256sum | sed "s|$theme/||" | sha256sum)"
  check "a second Plymouth install rewrites nothing" \
    "$([[ $first == "$second" ]] && echo 0 || echo 1)"

  vp_plymouth plymouth_theme_remove "$sys" >"$root/plymouth-remove.log" 2>&1
  check "Plymouth theme remove exits 0" $?
  check "the theme directory is removed" "$([[ ! -e $theme ]] && echo 0 || echo 1)"
  check "uninstall restores the previous theme selection" \
    "$(grep -qx 'Theme=omarchy' "$conf" && echo 0 || echo 1)"

  # A directory with our theme name that we did not create is never deleted.
  sys2="$root/sys2"
  mkdir -p "$sys2/usr/share/plymouth/themes/virtual-paradise"
  printf 'not ours\n' >"$sys2/usr/share/plymouth/themes/virtual-paradise/virtual-paradise.script"
  vp_plymouth plymouth_theme_remove "$sys2" >/dev/null 2>&1
  check "remove leaves a theme it does not own alone" \
    "$([[ -f $sys2/usr/share/plymouth/themes/virtual-paradise/virtual-paradise.script ]] && echo 0 || echo 1)"

  vp_plymouth plymouth_theme_install "$sys2" "$REPO_DIR" >"$root/plymouth-foreign.log" 2>&1
  rc=$?
  check "install refuses to replace a theme it does not own" \
    "$([[ $rc -ne 0 ]] && echo 0 || echo 1)" "$(tail -2 "$root/plymouth-foreign.log")"

  check "install.sh installs Plymouth through lib/plymouth.sh" \
    "$(grep -q 'lib/plymouth.sh' "$REPO_DIR/lib/step-boot.sh" && echo 0 || echo 1)"
  check "install.sh no longer patches the omarchy Plymouth theme" \
    "$(grep -vE '^[[:space:]]*#' "$REPO_DIR/install.sh" | grep -q 'plymouth/themes/omarchy' && echo 1 || echo 0)"
  check "uninstall.sh removes the Plymouth theme" \
    "$(grep -q 'plymouth_theme_remove' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"
  check "uninstall.sh removes the Plymouth systemd drop-in" \
    "$(grep -q 'plymouth-poweroff.service' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # Hyprland 0.5x loads a Lua config, and the keyword subcommand refuses to
  # work with it: "keyword can't work with non-legacy parsers. Use eval."
  # Every setting the theme scripts make has to go through hyprctl eval,
  # otherwise the effect silently does nothing. Comments are not calls.
  legacy_hyprctl="$(grep -rn 'hyprctl keyword' "$REPO_DIR/bin" "$REPO_DIR/lib" 2>/dev/null \
    | grep -vE ':[[:space:]]*#' || true)"
  check "no script uses the no-op hyprctl keyword subcommand" \
    "$([[ -z $legacy_hyprctl ]] && echo 0 || echo 1)" "$legacy_hyprctl"

  # The legacy dispatcher syntax is rejected by the Lua dispatcher too.
  legacy_dispatch="$(grep -rnE 'hyprctl dispatch (workspace|movewindowpixel|resizewindowpixel|setopacity)' \
    "$REPO_DIR/bin" "$REPO_DIR/lib" 2>/dev/null | grep -vE ':[[:space:]]*#' || true)"
  check "no script uses the rejected legacy dispatcher syntax" \
    "$([[ -z $legacy_dispatch ]] && echo 0 || echo 1)" "$legacy_dispatch"

  # The theme switcher edited a hyprland.conf that Omarchy 4 does not read.
  check "the theme switcher no longer edits hyprland.conf" \
    "$(grep -q 'hyprland\.conf' "$REPO_DIR/bin/theme-switcher.sh" && echo 1 || echo 0)"
  check "the theme switcher re-applies the theme through omarchy" \
    "$(grep -q 'omarchy theme refresh' "$REPO_DIR/bin/theme-switcher.sh" && echo 0 || echo 1)"
  check "theme writes share the live palette lock" \
    "$(grep -q 'with_state_lock' "$REPO_DIR/bin/theme-switcher.sh" \
      && grep -q 'palette.lock' "$REPO_DIR/bin/theme-switcher.sh" \
      && grep -q 'VP_SKIP_PALETTE_WRITE' "$REPO_DIR/bin/theme-switcher.sh" && echo 0 || echo 1)"
  check "vp-palette accepts ordered writes" \
    "$(grep -q -- '--seq' "$REPO_DIR/bin/vp-palette.sh" \
      && grep -q 'existing_seq > seq' "$REPO_DIR/bin/vp-palette.sh" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-12  Palette switching: the theme files and the colors.toml stay in sync.
#
# The theme ships its own ghostty.conf, foot.ini, alacritty.toml, shell.toml,
# btop.theme, vscode-theme.json and gtk.css. Omarchy only renders a template
# when the theme does not ship that file, so those static copies are what the
# terminal, the bar, btop, VS Code and GTK really use. Editing colors.toml
# alone changed almost nothing on screen; the switcher now rewrites every
# palette-carrying file and can restore the original again.
# ─────────────────────────────────────────────────────────────────────────────
if want tc12; then
  section "TC-12  Theme variant switching"

  root="$(new_sandbox tc12)"
  home="$root/home"
  theme="$home/.config/omarchy/themes/virtual-paradise"
  mkdir -p "$theme/config"

  cp "$REPO_DIR/theme/colors.toml" "$theme/colors.toml"
  cp "$REPO_DIR/config/terminal/ghostty.conf" "$theme/ghostty.conf"
  cp "$REPO_DIR/config/gtk.css" "$theme/config/gtk.css"

  run_switcher() {
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      bash "$REPO_DIR/bin/theme-switcher.sh" "$@" >"$root/switch.log" 2>&1
  }

  run_switcher catppuccin
  check "the theme switcher exits 0" $? "$(tail -3 "$root/switch.log")"
  check "colors.toml got the variant accent" \
    "$(grep -q '^accent = "#89b4fa"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "the terminal config got the same accent" \
    "$(grep -q '^palette = 4=#89b4fa' "$theme/ghostty.conf" && echo 0 || echo 1)"
  check "the GTK stylesheet got the same accent" \
    "$(grep -q '@define-color blue #89b4fa' "$theme/config/gtk.css" && echo 0 || echo 1)"
  check "the cursor followed the accent" \
    "$(grep -q '^cursor = "#89b4fa"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "the semantic green role followed the variant" \
    "$(grep -q '^green = "#a6e3a1"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "the semantic background role followed the variant" \
    "$(grep -q '^bg = "#1e1e2e"' "$theme/colors.toml" && echo 0 || echo 1)"

  listout=$(HOME="$home" XDG_CONFIG_HOME="$home/.config" bash "$REPO_DIR/bin/theme-switcher.sh" list 2>&1)
  check "the switcher lists the Omarchy palettes" \
    "$(grep -q 'catppuccin' <<<"$listout" && grep -q 'hackerman' <<<"$listout" \
      && grep -q 'dracula' <<<"$listout" && ! grep -qE 'sakura|cozy' <<<"$listout" \
      && echo 0 || echo 1)" "$listout"

  python3 - "$home/.local/state/virtual-paradise/palette.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
raise SystemExit(0 if d.get("accent") == "#89b4fa" and d.get("tertiary") == "#a6e3a1"
                 and d.get("hot") == "#f38ba8" else 1)
PY
  check "the QML palette follows the variant" $?

  run_switcher custom 12ab34 223344 334455 445566 556677 667788 0a0b0c ddeeff
  check "a custom accent is applied" \
    "$(grep -q '^accent = "#12ab34"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "custom secondary and tertiary are applied" \
    "$(grep -q '^color1 = "#223344"' "$theme/colors.toml" \
      && grep -q '^color2 = "#334455"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "custom background and text are applied" \
    "$(grep -q '^background = "#0a0b0c"' "$theme/colors.toml" \
      && grep -q '^foreground = "#ddeeff"' "$theme/colors.toml" && echo 0 || echo 1)"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if d.get("name")=="custom" and d.get("accent")=="#12ab34" and d.get("secondary")=="#223344" and d.get("hot")=="#667788" and d.get("background")=="#0a0b0c" and d.get("foreground")=="#ddeeff" else 1)' \
    "$home/.local/state/virtual-paradise/palette.json"
  check "the custom palette records every role" $?
  check "the custom variant is recorded" \
    "$(grep -qx 'custom' "$home/.local/state/virtual-paradise/current_variant" && echo 0 || echo 1)"
  check "the bar exposes the palette to its widgets" \
    "$(grep -q 'palette.json' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && grep -q 'readonly property color accentColor' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && for w in clock cputemp weather microphone; do \
           grep -q 'root.bar.accentColor' "$REPO_DIR/plugins/$w/BarWidget.qml" || exit 1; \
         done; echo 0)"
  check "the bar API forwards the palette to every widget" \
    "$(grep -q 'property color accentColor' "$REPO_DIR/bars/island-bar/VpPluginBarApi.qml" \
      && for role in secondary green warm pink hot paletteForeground; do \
           grep -q "property color $role" "$REPO_DIR/bars/island-bar/VpPluginBarApi.qml" || exit 1; \
           grep -q "api.$role = Qt.binding" "$REPO_DIR/bars/island-bar/Bar.qml" || exit 1; \
         done; echo 0)"
  check "the bar applies palette writes without a restart" \
    "$(grep -q 'function applyPalette' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && grep -q 'if (value === root.paletteRaw) return' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && echo 0 || echo 1)"

  # The live path: the panel calls vp-palette.sh on every swatch click, so the
  # bar recolors from palette.json without waiting for the debounced theme files
  # or a shell restart.
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" \
    bash "$REPO_DIR/bin/vp-palette.sh" \
    abcdef 111111 222222 333333 444444 555555 010203 040506 >"$root/palette.log" 2>&1
  check "vp-palette writes the live palette" $? "$(tail -3 "$root/palette.log")"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if d.get("name")=="custom" and d.get("accent")=="#abcdef" and d.get("secondary")=="#111111" and d.get("tertiary")=="#222222" and d.get("warm")=="#333333" and d.get("pink")=="#444444" and d.get("hot")=="#555555" and d.get("background")=="#010203" and d.get("foreground")=="#040506" else 1)' \
    "$home/.local/state/virtual-paradise/palette.json"
  check "vp-palette records all eight roles" $?
  check "vp-palette marks the variant custom" \
    "$(grep -qx 'custom' "$home/.local/state/virtual-paradise/current_variant" && echo 0 || echo 1)"
  check "vp-palette leaves no temp files" \
    "$(find "$home/.local/state/virtual-paradise" -maxdepth 1 -name '.palette.*' | grep -q . && echo 1 || echo 0)"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" \
    bash "$REPO_DIR/bin/vp-palette.sh" 12345 111111 222222 333333 444444 555555 010203 040506 >/dev/null 2>&1
  check "vp-palette rejects a bad colour" "$([[ $? -ne 0 ]] && echo 0 || echo 1)"

  palette_file="$home/.local/state/virtual-paradise/palette.json"
  inode_before="$(stat -c %i "$palette_file")"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-palette.sh" abcdef 111111 222222 333333 444444 555555 010203 040506 >/dev/null 2>&1
  check "vp-palette leaves an identical palette untouched" \
    "$([[ "$inode_before" == "$(stat -c %i "$palette_file")" ]] && echo 0 || echo 1)"

  # Concurrent clicks spawn several writers. flock must keep the file valid,
  # and the last one to finish still writes a complete palette.
  for value in 111111 222222 333333 444444 555555 666666 777777 888888; do
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      bash "$REPO_DIR/bin/vp-palette.sh" "$value" 111111 222222 333333 444444 555555 010203 040506 >/dev/null 2>&1 &
  done
  wait
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); roles=("accent","secondary","tertiary","warm","pink","hot","background","foreground"); raise SystemExit(0 if d.get("name")=="custom" and all(isinstance(d.get(r),str) and len(d.get(r))==7 and d[r][0]=="#" for r in roles) else 1)' \
    "$palette_file"
  check "concurrent live writes leave a valid palette" $?
  live_osc="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-terminal-palette.sh" --dry-run 2>/dev/null || true)"
  check "the live terminal palette emits OSC colours" \
    "$(grep -q '\\x1b\]4;4;' <<<"$live_osc" \
      && grep -q '\\x1b\]11;' <<<"$live_osc" \
      && grep -q '\\x1b\]12;' <<<"$live_osc" && echo 0 || echo 1)"

  # Portable custom themes: save the live palette, prove the JSON survives a
  # different palette, then round-trip an export/import.
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-palette.sh" a1b2c3 d4e5f6 112233 445566 778899 aabbcc 010101 efefef >/dev/null 2>&1
  themes_dir="$home/.local/state/virtual-paradise/themes"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" save "Phase Two" >/dev/null 2>&1
  check "vp-theme saves a portable palette" \
    "$([[ -f "$themes_dir/phase-two.json" ]] && echo 0 || echo 1)"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" list >"$root/theme-list.log" 2>&1
  check "vp-theme lists saved palettes" \
    "$(grep -qx 'phase-two' "$root/theme-list.log" && echo 0 || echo 1)"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-palette.sh" 999999 888888 777777 666666 555555 444444 030303 020202 >/dev/null 2>&1
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" load phase-two >/dev/null 2>&1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if d.get("accent")=="#a1b2c3" and d.get("foreground")=="#efefef" else 1)' \
    "$home/.local/state/virtual-paradise/palette.json"
  check "vp-theme load restores all eight roles" $?
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" export phase-two "$root/phase-two.json" >/dev/null 2>&1
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" import "$root/phase-two.json" "Imported Two" >/dev/null 2>&1
  check "vp-theme imports an exported palette" \
    "$([[ -f "$themes_dir/imported-two.json" ]] && echo 0 || echo 1)"
  printf '{"colors":{"accent":"nope"}}\n' >"$root/bad-theme.json"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" import "$root/bad-theme.json" bad >/dev/null 2>&1
  check "vp-theme rejects an invalid import" "$([[ $? -ne 0 ]] && echo 0 || echo 1)"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" delete imported-two >/dev/null 2>&1
  check "vp-theme deletes a saved palette" \
    "$([[ ! -f "$themes_dir/imported-two.json" ]] && echo 0 || echo 1)"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    bash "$REPO_DIR/bin/vp-theme.sh" export-current "$root/current-export.json" "Current" >/dev/null 2>&1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); c=d.get("colors",{}); raise SystemExit(0 if d.get("schemaVersion")==1 and c.get("accent")=="#a1b2c3" and len(c)==8 else 1)' \
    "$root/current-export.json"
  check "vp-theme exports the live palette to a path" $?

  # Cava used to be hardcoded cyberpunk. It now follows the active colors.toml.
  mkdir -p "$home/.config/cava"
  cp "$REPO_DIR/cava/config" "$home/.config/cava/config"
  HOME="$home" XDG_CONFIG_HOME="$home/.config" VP_SYNC_CAVA_NO_SIGNAL=1 \
    python3 "$REPO_DIR/bin/sync_cava_theme.py" virtual-paradise >/dev/null 2>&1
  python3 - "$home/.config/omarchy/themes/virtual-paradise/colors.toml" \
    "$home/.config/cava/config" <<'PY'
import re
import sys

theme = open(sys.argv[1], encoding="utf-8").read()
cava = open(sys.argv[2], encoding="utf-8").read()
accent = re.search(r'^accent = "([^"]+)"', theme, re.M)
gradient = re.search(r"^gradient_color_1 = '([^']+)'", cava, re.M)
raise SystemExit(0 if accent and gradient and accent.group(1) == gradient.group(1) else 1)
PY
  check "cava follows the active palette" $?
  check "the theme pass reloads live consumers" \
    "$(grep -q 'VP_RELOAD_CONSUMERS' "$REPO_DIR/bin/theme-switcher.sh" \
      && grep -q 'VP_RELOAD_CONSUMERS' "$REPO_DIR/plugins/tools/Panel.qml" \
      && grep -q 'cava' "$REPO_DIR/bin/sync_cava_theme.py" && echo 0 || echo 1)"

  # ImageMagick is optional in CI; the dry-run still proves the request path
  # and, when magick exists, that the generated file is a JPEG.
  tint_rc=0
  if command -v magick >/dev/null 2>&1; then
    tint_out="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      VP_WALLPAPER_SOURCE="$REPO_DIR/backgrounds/Glitch.jpg" \
      bash "$REPO_DIR/bin/vp-wallpaper-tint.sh" --dry-run 2>/dev/null)" || tint_rc=$?
    python3 -c 'import sys; f=open(sys.argv[1], "rb"); raise SystemExit(0 if f.read(2) == b"\xff\xd8" else 1)' \
      "$tint_out" || tint_rc=1
  fi
  check "palette wallpaper generates a valid still" "$tint_rc"

  login_rc=0
  if command -v magick >/dev/null 2>&1; then
    login_out="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      VP_LOGIN_BACKDROP="$REPO_DIR/plymouth/backdrop.png" \
      VP_LOGIN_STILL="$REPO_DIR/sddm/assets/still.png" \
      VP_LOGIN_FRAME="$REPO_DIR/plymouth/frame.png" \
      bash "$REPO_DIR/bin/vp-login-art.sh" --dry-run 2>/dev/null)" || login_rc=$?
    python3 -c 'import os, sys
root = sys.argv[1]
for name in ("backdrop.png", "still.png", "frame.png"):
    path = os.path.join(root, name)
    if os.path.getsize(path) < 1000:
        raise SystemExit(1)
    if open(path, "rb").read(8) != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(1)' \
      "$login_out" || login_rc=1
  fi
  check "palette login artwork generates valid PNGs" "$login_rc"

  plymouth_rc=0
  if command -v magick >/dev/null 2>&1; then
    plymouth_theme="$root/plymouth-theme"
    mkdir -p "$plymouth_theme"
    cp "$REPO_DIR/plymouth/backdrop.png" "$REPO_DIR/plymouth/frame.png" \
      "$REPO_DIR/sddm/assets/still.png" "$plymouth_theme"/
    plymouth_out="$(HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      VP_PLYMOUTH_THEME_DIR="$plymouth_theme" \
      bash "$REPO_DIR/bin/vp-plymouth-art.sh" --dry-run 2>/dev/null)" || plymouth_rc=$?
    python3 -c 'import os, sys
root = sys.argv[1]
files = [name for name in os.listdir(root) if name.endswith(".png")]
if len(files) != 3:
    raise SystemExit(1)
for name in files:
    path = os.path.join(root, name)
    if os.path.getsize(path) < 1000:
        raise SystemExit(1)
    if open(path, "rb").read(8) != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(1)' \
      "$plymouth_out" || plymouth_rc=1
  fi
  check "palette Plymouth artwork generates valid frames" "$plymouth_rc"

  wallpaper_rc=0
  wallpaper_variant_rc=0
  if command -v magick >/dev/null 2>&1; then
    mkdir -p "$home/.local/state/omarchy/current"
    ln -sfn "$REPO_DIR/backgrounds/Glitch.jpg" "$home/.local/state/omarchy/current/background"
    run_switcher wallpaper || wallpaper_rc=$?
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if d.get("name")=="wallpaper" and d.get("accent","").startswith("#") else 1)' \
      "$home/.local/state/virtual-paradise/palette.json" || wallpaper_rc=1
    grep -qx 'wallpaper' "$home/.local/state/virtual-paradise/current_variant" || wallpaper_variant_rc=1
  fi
  check "wallpaper palette follows an extensionless background symlink" "$wallpaper_rc"
  check "the wallpaper variant is recorded" "$wallpaper_variant_rc"

  image_theme_rc=0
  if command -v magick >/dev/null 2>&1; then
    HOME="$home" XDG_CONFIG_HOME="$home/.config" \
      bash "$REPO_DIR/bin/vp-theme-from-image.sh" "$REPO_DIR/backgrounds/Glitch.jpg" >/dev/null 2>&1 \
      || image_theme_rc=$?
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); raise SystemExit(0 if d.get("name")=="wallpaper" and d.get("accent","").startswith("#") else 1)' \
      "$home/.local/state/virtual-paradise/palette.json" || image_theme_rc=1
  fi
  check "palette can be derived from an image path" "$image_theme_rc"
  check "the bar watches palette writes instead of polling" \
    "$(grep -q 'id: paletteView' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && ! grep -q 'paletteView.reload' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && echo 0 || echo 1)"
  check "both palette writers notify the in-place watcher" \
    "$(grep -q 'printf .%s. .\$payload. >\"\$STATE_DIR/palette.json\"' "$REPO_DIR/bin/theme-switcher.sh" \
      && grep -q 'handle.write(payload)' "$REPO_DIR/bin/vp-palette.sh" && echo 0 || echo 1)"
  check "palette readers share the writer lock" \
    "$(for f in vp-theme.sh vp-terminal-palette.sh vp-wallpaper-tint.sh \
                vp-login-art.sh vp-plymouth-art.sh; do \
         grep -q 'flock -s' "$REPO_DIR/bin/$f" || exit 1; \
       done; echo 0)"

  # A second switch must start from the original palette, not from the one the
  # first switch wrote.
  run_switcher neon
  check "a second switch starts from the original palette" \
    "$(grep -q '^accent = "#00ffff"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "the terminal config followed the second switch" \
    "$(grep -q '^palette = 4=#00ffff' "$theme/ghostty.conf" && echo 0 || echo 1)"

  run_switcher reset
  check "reset restores the original colors.toml" \
    "$(grep -q '^accent = "#00ffdd"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "reset restores the original terminal config" \
    "$(grep -q '^palette = 4=#00ffdd' "$theme/ghostty.conf" && echo 0 || echo 1)"
  check "reset restores the original GTK stylesheet" \
    "$(grep -q '@define-color blue #00ffdd' "$theme/config/gtk.css" && echo 0 || echo 1)"

  # The effects have to speak the Lua config language.
  check "the effects script writes through hyprctl eval" \
    "$(grep -q 'hyprctl eval' "$REPO_DIR/bin/effects.sh" && echo 0 || echo 1)"
  check "the effects script uses the Lua config API" \
    "$(grep -q 'hl.config' "$REPO_DIR/bin/effects.sh" && echo 0 || echo 1)"

  # Hyprland reports a gradient stop as AARRGGBB, its config syntax wants
  # RRGGBBAA. Restoring the border without swapping the bytes brings it back
  # with its red and blue channels exchanged.
  mkdir -p "$root/bin"
  cat >"$root/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HYPRCTL_LOG"
STUB
  chmod +x "$root/bin/hyprctl"
  HYPRCTL_LOG="$root/hyprctl.log" PATH="$root/bin:$PATH" \
    bash -c '. "$1/bin/effects.sh"; restore_active_border "ee00ffdd cc00ff88 eeffb7d5 45deg"' \
    _ "$REPO_DIR" >/dev/null 2>&1
  check "the border gradient is restored with the right channel order" \
    "$(grep -q 'rgba(00ffddee)' "$root/hyprctl.log" 2>/dev/null && echo 0 || echo 1)" \
    "$(cat "$root/hyprctl.log" 2>/dev/null)"
  check "every gradient stop is restored" \
    "$(grep -q 'rgba(ffb7d5ee)' "$root/hyprctl.log" 2>/dev/null && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-13  Responsive typography and display layout.
#
# Three things the theme must not do:
#   - pin a font size. Ghostty applies a config-file include after the file
#     that pulls it in, so a size in the theme's ghostty.conf beats the
#     user's own config: a fresh install turned 9pt text into 12pt text.
#   - own the display layout. hyprmoncfg applies a profile per monitor setup
#     and switches between them on hotplug; static rules for eDP-1/HDMI-A-1/
#     DP-1/DP-2 with a fixed scale of 1.0 kept the laptop panel alive and
#     made every HiDPI display render at 1x.
#   - move the pointer on its own. Warping it to the focused window on a
#     workspace change read as the cursor jumping, and with follow_mouse on
#     the focus jumped with it.
# ─────────────────────────────────────────────────────────────────────────────
if want tc13; then
  section "TC-13  Responsive typography and display layout"

  # 1. No terminal config may pin a font size or inflate the line box.
  for terminal in ghostty.conf kitty.conf foot.ini alacritty.toml; do
    check "$terminal does not pin a font size" \
      "$(grep -qEi '^(font-size|font_size|size)[[:space:]]*=' "$REPO_DIR/config/terminal/$terminal" && echo 1 || echo 0)"
  done
  check "no terminal config inflates the line box" \
    "$(grep -rqEi '^(adjust-cell-height|adjust_line_height)' "$REPO_DIR/config/terminal" && echo 1 || echo 0)"

  # 2. The theme must not ship rules for a specific output.
  check "the theme ships no rule for a named output" \
    "$(grep -qE 'output[[:space:]]*=[[:space:]]*"(eDP-1|HDMI-A-1|DP-1|DP-2)"' "$REPO_DIR/hypr/monitors.lua" && echo 1 || echo 0)"
  check "the theme does not pin a scale for an output" \
    "$(grep -qE 'scale[[:space:]]*=[[:space:]]*1\.0' "$REPO_DIR/hypr/monitors.lua" && echo 1 || echo 0)"

  # 3. The pointer must not be warped on a workspace change. Warping it to the
  #    focused window read as the cursor jumping on its own, and with
  #    follow_mouse on, the focus jumped with it.
  check "the theme does not warp the cursor on workspace change" \
    "$(grep -qE 'warp_on_change_workspace[[:space:]]*=[[:space:]]*0' "$REPO_DIR/hypr/input.lua" && echo 0 || echo 1)"

  # 4. Functional: a machine that ran the old installer has the static
  #    presets in monitors.lua and the window rules behind hyprmoncfg's
  #    "load last" line. Both have to be repaired.
  root="$(new_sandbox tc13)"
  build_shims "$root/bin"
  mkdir -p "$root/home/.config/hypr"
  cat >"$root/home/.config/hypr/hyprland.lua" <<'EOF'
require("default.hypr.omarchy")

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end

-- Virtual Paradise Add-on Window Rules
o.window({ initial_title = "Btop Monitor" }, { float = true, size = { 1050, 650 }, center = true })
o.window({ class = "org.gnome.Nautilus", title = ".*Properties.*" }, { float = true })
EOF
  cat >"$root/home/.config/hypr/monitors.lua" <<'EOF'
-- BEGIN hyprmoncfg wake settings
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
-- END hyprmoncfg wake settings

hl.monitor({
  output = "eDP-1",
  mode = "preferred",
  position = "0x0",
  scale = 1.0,
  transform = 0,
})

hl.monitor({
  output = "HDMI-A-1",
  mode = "preferred",
  position = "auto-right",
  scale = 1.0,
})

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})
EOF

  run_installer "$root" >/dev/null 2>&1
  check "the installer exits 0" $?

  installed_monitors="$root/home/.config/hypr/monitors.lua"
  check "the static eDP-1 preset was removed" \
    "$(grep -q 'transform = 0' "$installed_monitors" && echo 1 || echo 0)"
  check "the static HDMI preset was removed" \
    "$(grep -q 'auto-right' "$installed_monitors" && echo 1 || echo 0)"
  check "hyprmoncfg's own wake rule was kept" \
    "$(grep -q 'BEGIN hyprmoncfg wake settings' "$installed_monitors" && echo 0 || echo 1)"
  check "the generic output fallback was kept" \
    "$(grep -q 'position = "auto"' "$installed_monitors" && echo 0 || echo 1)"

  installed_hyprland="$root/home/.config/hypr/hyprland.lua"
  rules_line="$(grep -n 'Virtual Paradise Add-on Window Rules' "$installed_hyprland" | head -n 1 | cut -d: -f1)"
  moncfg_line="$(grep -n 'hyprmoncfg-monitors.lua' "$installed_hyprland" | head -n 1 | cut -d: -f1)"
  check "the window rules load before hyprmoncfg's rules (rules line ${rules_line:-none}, hyprmoncfg line ${moncfg_line:-none})" \
    "$([[ -n $rules_line && -n $moncfg_line && $rules_line -lt $moncfg_line ]] && echo 0 || echo 1)"
  check "the window rules are still installed" \
    "$(grep -q 'o.window({ initial_title = "Btop Monitor"' "$installed_hyprland" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-14  Omarchy environment: the installer works with a reset environment.
#
# Omarchy sets OMARCHY_PATH in the user's shell. sudo resets the environment,
# and the systemd user manager does not carry it either, so `sudo ./install.sh`
# and the daily plugin-update timer both ran every `omarchy ...` command
# without it. The answers are "OMARCHY_PATH is not set" and "shell config not
# found: /shell", and the installer ignored those errors - the run looked
# successful while no plugin was enabled and the shell never restarted.
# ─────────────────────────────────────────────────────────────────────────────
if want tc14; then
  section "TC-14  Omarchy environment under sudo and systemd"

  root="$(new_sandbox tc14)"

  # The resolver: the packaged path by default, the dev checkout when
  # /etc/omarchy.conf points somewhere else.
  check "the resolver falls back to the packaged Omarchy" \
    "$( . "$REPO_DIR/lib/omarchy-env.sh"; omarchy_resolve_path | grep -qx '/usr/share/omarchy' && echo 0 || echo 1)"

  # install.sh and uninstall.sh must hand the variable to the commands they
  # start, because sudo strips it.
  check "the installer exports OMARCHY_PATH" \
    "$(grep -q 'omarchy_export_env' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the uninstaller exports OMARCHY_PATH" \
    "$(grep -q 'omarchy_export_env' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"
  check "the installer hands OMARCHY_PATH to the user commands" \
    "$(grep -q 'OMARCHY_PATH="\$OMARCHY_PATH"' "$REPO_DIR/lib/install-helpers.sh" && echo 0 || echo 1)"
  check "the plugin updater resolves OMARCHY_PATH for the timer" \
    "$(grep -q 'omarchy-env.sh' "$REPO_DIR/bin/update-plugins.sh" && echo 0 || echo 1)"

  # sudo resets the Hyprland instance and the session bus as well: without
  # them `hyprctl reload` cannot find the compositor and the theme's Hyprland
  # changes would only land at the next login.
  check "the installer restores the session variables" \
    "$(grep -q 'omarchy_resolve_session_env' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the uninstaller restores the session variables" \
    "$(grep -q 'omarchy_resolve_session_env' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  runtime="/run/user/$(id -u)"
  if [[ -d "$runtime/hypr" ]]; then
    got_signature="$( . "$REPO_DIR/lib/omarchy-env.sh"; omarchy_resolve_session_env "$(id -un)" >/dev/null 2>&1; printf '%s' "${HYPRLAND_INSTANCE_SIGNATURE:-}" )"
    check "the resolver finds the running Hyprland instance" \
      "$([[ -n $got_signature ]] && echo 0 || echo 1)" "got ${got_signature:-none}"
  else
    printf '  %sSKIP%s no Hyprland runtime directory\n' "$DIM" "$OFF"
  fi

  # Functional: run the installer with a completely stripped environment and
  # an omarchy that records the variable it was given.
  mkdir -p "$root/bin"
  cat >"$root/bin/omarchy" <<'STUB'
#!/usr/bin/env bash
printf '%s OMARCHY_PATH=%s\n' "$*" "${OMARCHY_PATH:-<UNSET>}" >>"${SHIM_LOG:-/dev/null}"
exit 0
STUB
  cat >"$root/bin/omarchy-shell" <<'STUB'
#!/usr/bin/env bash
printf 'omarchy-shell %s OMARCHY_PATH=%s\n' "$*" "${OMARCHY_PATH:-<UNSET>}" >>"${SHIM_LOG:-/dev/null}"
exit 0
STUB
  chmod +x "$root/bin/omarchy" "$root/bin/omarchy-shell"

  ( cd "$REPO_DIR" \
    && env -i PATH="$root/bin:/usr/bin:/bin" HOME="$root/home" \
       XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/home/.local/state" XDG_DATA_HOME="$root/home/.local/share" SHIM_LOG="$root/shim.log" \
       timeout 600 bash ./install.sh --user-only --no-boot \
       >"$root/install.log" 2>&1 )
  check "the installer runs with a stripped environment" $? "$(strip_ansi "$root/install.log" | tail -2)"

  check "the installer ran the omarchy commands" \
    "$([[ -s $root/shim.log ]] && echo 0 || echo 1)"
  check "every omarchy command got OMARCHY_PATH" \
    "$([[ -s $root/shim.log ]] && ! grep -q 'OMARCHY_PATH=<UNSET>' "$root/shim.log" && echo 0 || echo 1)" \
    "$(grep -m3 'OMARCHY_PATH=<UNSET>' "$root/shim.log" 2>/dev/null)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-15  The compositor can read the config the theme writes.
#
# A mktemp file is created with mode 600 and `mv` keeps that mode, so moving
# a freshly built Hyprland config into place turned it into -rw-------. In a
# `sudo ./install.sh` run the file was root-owned on top of that, and the
# compositor answered "cannot open ~/.config/hypr/hyprland.lua: Permission
# denied" in its error overlay.
# ─────────────────────────────────────────────────────────────────────────────
if want tc15; then
  section "TC-15  Hyprland config permissions"

  root="$(new_sandbox tc15)"
  build_shims "$root/bin"
  mkdir -p "$root/home/.config/hypr"
  printf 'require("default.hypr.omarchy")\n\n-- Added by hyprmoncfg: its generated monitor rules load last.\ndo local path = "x"; dofile(path)\n' \
    >"$root/home/.config/hypr/hyprland.lua"
  chmod 644 "$root/home/.config/hypr/hyprland.lua"

  run_installer "$root" >/dev/null 2>&1
  check "the installer exits 0" $?

  for hypr_file in hyprland.lua bindings.lua looknfeel.lua input.lua monitors.lua autostart.lua; do
    mode="$(stat -c '%a' "$root/home/.config/hypr/$hypr_file" 2>/dev/null || echo 000)"
    check "hypr/$hypr_file is readable by the compositor (mode ${mode})" \
      "$([[ $mode == 644 ]] && echo 0 || echo 1)"
  done

  # The window rules still have to be there: the file is rebuilt to move them
  # in front of hyprmoncfg's line.
  check "the window rules survived the rewrite" \
    "$(grep -q 'Virtual Paradise Add-on Window Rules' "$root/home/.config/hypr/hyprland.lua" && echo 0 || echo 1)"

  # The helper itself: replacing a file must not change its mode. A mktemp
  # file is 600, and `mv` keeps that mode - which is how the Hyprland config
  # became unreadable.
  probe="$root/probe.txt"
  staged="$root/staged.txt"
  printf 'before\n' >"$probe"
  chmod 640 "$probe"
  printf 'after\n' >"$staged"
  ( . "$REPO_DIR/lib/file-ops.sh"; replace_file_preserving "$probe" "$staged" ) >/dev/null 2>&1
  check "replacing a file keeps its mode" \
    "$([[ $(stat -c '%a' "$probe" 2>/dev/null) == 640 ]] && echo 0 || echo 1)" \
    "mode $(stat -c '%a' "$probe" 2>/dev/null)"
  check "replacing a file keeps its content" \
    "$(grep -qx 'after' "$probe" && echo 0 || echo 1)"

  # The installer has to go through the helper: a plain `mv` of a mktemp file
  # is what made the config unreadable in the first place.
  check "the installer replaces the config through the helper" \
    "$(grep -q 'replace_file_preserving' "$REPO_DIR/lib/step-shell.sh" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-16  Boot and login performance.
#
# Three things that used to cost seconds on every login and every theme
# switch:
#   - the wallpapers (~95 MB of video) lived in the theme directory, and
#     Omarchy stages the whole theme on every theme switch;
#   - the animated GIFs were wallpapers, and Omarchy picks the bar's text
#     colour with ImageMagick, which rendered 250 animation frames;
#   - the terminal banner was drawn by Python on every interactive shell.
# ─────────────────────────────────────────────────────────────────────────────
if want tc16; then
  section "TC-16  Boot and login performance"

  check "the wallpapers are installed outside the theme directory" \
    "$(grep -q 'WALLPAPER_DEST="\$CONFIG_DIR/omarchy/backgrounds/\$THEME_NAME"' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the theme directory does not carry the wallpapers" \
    "$(grep -A4 'THEME_STRIP=(' "$REPO_DIR/install.sh" | grep -q 'backgrounds' && echo 0 || echo 1)"
  check "the live wallpaper reads the new location" \
    "$(grep -q 'omarchy/backgrounds/virtual-paradise' "$REPO_DIR/bin/toggle_live_wallpaper.sh" && echo 0 || echo 1)"
  check "the uninstaller removes the new wallpaper directory" \
    "$(grep -q 'omarchy/backgrounds/\$THEME_NAME' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # The animated GIFs are the SDDM animation, not wallpapers: as wallpapers
  # they made ImageMagick render every frame of them for the bar's text colour.
  # They must not be converted into a JPG either - the repository ships a
  # sharp 1920x1080 JPG with the same name, and the conversion replaced it
  # with a blurry 480x270 frame.
  check "the animated GIFs are removed from the wallpapers" \
    "$(grep -q 'for gif in "\$REPO_DIR"/backgrounds/\*.gif' "$REPO_DIR/install.sh" \
      && ! grep -q 'rm -f "\$WALLPAPER_DEST"/\*.gif' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the GIFs are not converted over the sharp wallpapers" \
    "$(grep -q 'wallpaper_gif' "$REPO_DIR/install.sh" && echo 1 || echo 0)"

  # Every static wallpaper has to be full resolution.
  wallpaper_ok=1
  for wallpaper in "$REPO_DIR"/backgrounds/*.jpg; do
    bytes="$(od -An -tu1 -j16 -N4 "$wallpaper" 2>/dev/null | tr -s ' ' | sed 's/^ //')"
    set -- $bytes
    pixels=$(( $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 ))
    [[ $pixels -ge 1920000 ]] || wallpaper_ok=0
  done
  check "every static wallpaper is full resolution" \
    "$([[ $wallpaper_ok -eq 1 ]] && echo 0 || echo 1)"

  # Omarchy 4.5 renders video wallpapers itself (owe); the theme's script is a
  # picker that hands the path to `omarchy theme bg set` and plays the curtain,
  # so there is exactly one decoder. Running mpvpaper alongside it decoded the
  # same frames twice (~360 MB of RSS between them).
  check "the live wallpaper rides Omarchy's background engine" \
    "$(grep -q 'omarchy theme bg set' "$REPO_DIR/bin/toggle_live_wallpaper.sh" \
      && ! grep -vE '^[[:space:]]*#' "$REPO_DIR/bin/toggle_live_wallpaper.sh" | grep -q 'mpvpaper' \
      && echo 0 || echo 1)"
  check "the theme no longer starts a second wallpaper decoder" \
    "$(! grep -q 'toggle_live_wallpaper' "$REPO_DIR/hypr/autostart.lua" && echo 0 || echo 1)"

  # The session splash covers the gap between the greeter handing the screen
  # to the session and the desktop having something to show.
  check "there is a session splash" \
    "$([[ -f $REPO_DIR/bin/session_splash.sh ]] && echo 0 || echo 1)"
  check "the session splash uses the glitch curtain" \
    "$(grep -q 'glitch_transition.qml' "$REPO_DIR/bin/session_splash.sh" && echo 0 || echo 1)"
  check "the curtain can wait for the shell instead of a file" \
    "$(grep -q 'VP_TRANSITION_WAIT_SHELL' "$REPO_DIR/bin/glitch_transition.qml" && grep -q 'VP_TRANSITION_WAIT_SHELL' "$REPO_DIR/bin/session_splash.sh" && echo 0 || echo 1)"
  check "the curtain can use a different picture" \
    "$(grep -q 'VP_TRANSITION_IMAGE' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the session has its own picture for the curtain" \
    "$([[ -f $REPO_DIR/plymouth/session_base.png ]] && echo 0 || echo 1)"
  check "the curtain has a TV static layer" \
    "$([[ -f $REPO_DIR/plymouth/noise.jpg && -f $REPO_DIR/plymouth/scanlines.png ]] && echo 0 || echo 1)"
  check "the curtain jitters the picture" \
    "$(grep -q 'Math.random()' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the amount of noise is configurable" \
    "$(grep -q 'VP_TRANSITION_NOISE' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the session splash uses the full noise" \
    "$(grep -q 'VP_TRANSITION_NOISE="1.0"' "$REPO_DIR/bin/session_splash.sh" && echo 0 || echo 1)"
  # The HUD sat in the middle of the picture and covered Miku's face.
  check "the curtain draws no HUD over the picture" \
    "$(grep -q 'WALLPAPER LINK' "$REPO_DIR/bin/glitch_transition.qml" && echo 1 || echo 0)"
  # The picture and the static end at once, the way they always did. Only the
  # glitch itself lingers for a moment over the desktop.
  check "the curtain keeps a fading afterglow" \
    "$(grep -q 'id: afterglow' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the picture ends at once, the glitch lingers" \
    "$(grep -q 'glitchRoot.visible = false' "$REPO_DIR/bin/glitch_transition.qml" \
      && grep -q 'property real remnant' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the session splash is started from the Hyprland autostart" \
    "$(grep -q 'session_splash.sh' "$REPO_DIR/hypr/autostart.lua" && echo 0 || echo 1)"
  check "the installer hooks the session splash" \
    "$(grep -q 'session_splash.sh' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the session splash selects its own glitch style" \
    "$(grep -q 'VP_TRANSITION_STYLE="session"' "$REPO_DIR/bin/session_splash.sh" && echo 0 || echo 1)"
  check "the session glitch stacks three solid signal blocks" \
    "$(grep -q 'id: trioA' "$REPO_DIR/bin/glitch_transition.qml" \
      && grep -q 'id: trioACyan' "$REPO_DIR/bin/glitch_transition.qml" \
      && grep -q 'id: trioAPurple' "$REPO_DIR/bin/glitch_transition.qml" \
      && grep -q 'id: trioB' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the session glitch tears the picture horizontally" \
    "$(grep -q 'id: tearGap1' "$REPO_DIR/bin/glitch_transition.qml" \
      && grep -q 'property bool sessionStyle' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  # Hyprland 0.56.x spells the spring key `dampening`; the wiki's "Latest git"
  # pages spell it `damping`, and the config loader rejects that spelling,
  # silently dropping every curve and animation leaf that uses it.
  check "spring curves use the 0.56.x 'dampening' key" \
    "$(grep -q 'type = "spring"' "$REPO_DIR/hypr/looknfeel.lua" \
      && ! grep 'type = "spring"' "$REPO_DIR/hypr/looknfeel.lua" | grep -q 'damping =' \
      && grep 'type = "spring"' "$REPO_DIR/hypr/looknfeel.lua" | grep -q 'dampening =' \
      && echo 0 || echo 1)"
  # A fullscreen ambient overlay must never eat the desktop's clicks: the
  # empty input mask makes every pointer event pass through.
  for vp_overlay in ambient_glitch scanline_overlay; do
    check "the $vp_overlay overlay is click-through" \
      "$(grep -q 'mask: Region {}' "$REPO_DIR/bin/$vp_overlay.qml" \
        && grep -q 'ShellRoot {' "$REPO_DIR/bin/$vp_overlay.qml" && echo 0 || echo 1)"
  done
  # The active window's shadow carries the same three-stop gradient as its
  # border, so the glow reads as the border's light instead of a flat halo
  # that drowns the gradient.
  check "the active shadow carries the border's three-stop gradient" \
    "$(grep -q 'rgba(00ffddbb)' "$REPO_DIR/hypr/looknfeel.lua" \
      && grep -q 'rgba(ffb7d5bb)' "$REPO_DIR/hypr/looknfeel.lua" && echo 0 || echo 1)"
  # Every window carries the palette, not just the focused one: inactive
  # windows keep the same three stops at a low alpha, on both the border
  # and the shadow. A flat grey inactive border read as "some windows
  # glow, some do not".
  check "inactive windows keep the dim three-stop gradient" \
    "$(grep -q 'rgba(00ffdd3c)' "$REPO_DIR/hypr/looknfeel.lua" \
      && grep -q 'rgba(00ffdd1a)' "$REPO_DIR/hypr/looknfeel.lua" && echo 0 || echo 1)"
  # The focused border cycles its colours: borderangle spins the gradient a
  # full turn every three seconds, linearly, forever.
  check "the focused border cycles its colours rainbow-style" \
    "$(grep -q 'leaf = "borderangle"' "$REPO_DIR/hypr/looknfeel.lua" \
      && grep -q 'style = "loop"' "$REPO_DIR/hypr/looknfeel.lua" && echo 0 || echo 1)"
  # The shadow is the window's glow, so it has to spin on the same clock as
  # the border; a static shadow next to a travelling border read as two
  # unrelated effects. glowangle covers decoration:glow if it is ever enabled.
  check "the shadow and glow spin with the border gradient" \
    "$(grep -q 'leaf = "shadowangle"' "$REPO_DIR/hypr/looknfeel.lua" \
      && grep -q 'leaf = "glowangle"' "$REPO_DIR/hypr/looknfeel.lua" \
      && [[ $(grep -c 'bezier = "linearSpin", style = "loop"' "$REPO_DIR/hypr/looknfeel.lua") -ge 3 ]] \
      && echo 0 || echo 1)"
  # Hyprland caps a gradient at ten colours and spaces stops evenly, so the
  # theme's 45/20/45 travel is built from four cyan, two green, four pink.
  check "the gradient bands respect Hyprland's ten-colour cap" \
    "$(grep -q 'return { cyan, cyan, cyan, cyan, green, green, pink, pink, pink, pink }' \
      "$REPO_DIR/hypr/looknfeel.lua" && echo 0 || echo 1)"
  # Closing a window burns a neon glitch burst in its place. Omarchy closes on
  # SUPER + Q and SUPER + W; both are unbound first and then own the effect, so
  # exactly one action runs and the custom close is what either chord does.
  check "both close chords run the window death effect" \
    "$(grep -A2 'hl.unbind("SUPER + Q")' "$REPO_DIR/hypr/bindings.lua" \
        | grep -q 'o.bind("SUPER + Q", "Close Window (Red Glitch Death)"' \
      && grep -A1 'hl.unbind("SUPER + W")' "$REPO_DIR/hypr/bindings.lua" \
        | grep -q 'window_death.sh' && echo 0 || echo 1)"
  check "the window death burst is click-through" \
    "$(grep -q 'mask: Region {}' "$REPO_DIR/bin/window_death.qml" && echo 0 || echo 1)"
  # A glitch that slides in reads as a panel, not as signal loss: the death
  # burst's namespace is in the no_anim layer rule so it appears in one frame.
  check "the death burst appears in one frame, no slide" \
    "$(grep 'no_anim = true' "$REPO_DIR/hypr/looknfeel.lua" | grep -q 'vp-window-death' && echo 0 || echo 1)"
  # The burst tears the window's own captured frame - border pixels jump
  # with the slices, so the window reads as shaking itself apart.
  check "the death burst tears the window's own captured frame" \
    "$(grep -q 'VP_DEATH_IMAGE' "$REPO_DIR/bin/window_death.qml" \
      && grep -q 'grim -g' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # The border burns neon while the window is still alive, so the
  # captured corpse - and the death - is neon from the very first frame.
  check "the window burns neon before it dies" \
    "$(grep -q 'active_border_color' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # `hyprctl dispatch closewindow address:...` is parsed as Lua on 0.56 and
  # silently no-ops; the dispatcher object is the supported spelling.
  check "the death script closes with the 0.56 dispatcher spelling" \
    "$(grep -q 'hl.dsp.window.close' "$REPO_DIR/bin/window_death.sh" \
      && ! grep -q 'dispatch closewindow' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # A late burst must never make a late close: polling the layer tree for
  # the burst surface added a third of a second to every close. The
  # resident daemon maps the burst in one frame, so the script only
  # announces the death and closes.
  check "the window closes without waiting on the burst" \
    "$(grep -q 'hl.dsp.window.close' "$REPO_DIR/bin/window_death.sh" \
      && ! grep -q 'hyprctl layers' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # A watched FileView keeps its old text until reload() runs; the daemon
  # must reload on every change or the burst never arms.
  check "the death daemon reloads the trigger it watches" \
    "$(grep -q 'trigger.reload()' "$REPO_DIR/bin/vp_death_daemon.qml" \
      && grep -q 'onTextChanged' "$REPO_DIR/bin/vp_death_daemon.qml" && echo 0 || echo 1)"
  # Loading a leftover trigger at startup must not fire a stale burst.
  check "the death daemon ignores the initial trigger load" \
    "$(grep -q 'if (!root.pending) return' "$REPO_DIR/bin/vp_death_daemon.qml" && echo 0 || echo 1)"
  # The script hands the death to the daemon, so burst and close land in
  # the same breath instead of the burst trailing the window.
  check "the death script announces the death to the daemon" \
    "$(grep -q 'vp_death_trigger' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # The glitch must lead: the trigger is written before the close is
  # dispatched, so the burst is already on screen when the window goes.
  check "the glitch is announced before the close" \
    "$(awk '/vp_death_trigger/{if (!t) t=NR} /hl\.dsp\.window\.close/{if (!c) c=NR} END {exit !(t && c && t < c)}' \
      "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # The burst surfaces stay mapped for the whole session: mapping them on
  # the death costs a compositor roundtrip the glitch cannot afford.
  check "the death daemon keeps its burst surfaces mapped" \
    "$(grep -q 'visible: true' "$REPO_DIR/bin/vp_death_daemon.qml" \
      && grep -q 'visible: win.hit' "$REPO_DIR/bin/vp_death_daemon.qml" && echo 0 || echo 1)"
  # The corpse is positioned inside that always-mapped fullscreen surface,
  # so a death never resizes or remaps it.
  check "the corpse is positioned inside the mapped surface" \
    "$(grep -q 'x: root.rx - win.geo.x' "$REPO_DIR/bin/vp_death_daemon.qml" && echo 0 || echo 1)"
  # grim -T grabs the toplevel's own surface tree: the overlay already
  # covering the window is not in the corpse.
  check "the corpse capture takes the window, not the screen" \
    "$(grep -q 'grim -T' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # JPEG encoding is ~50 ms cheaper than PNG; the burst tears the frame
  # apart anyway, so the artefacts are part of the look.
  check "the corpse capture is JPEG for speed" \
    "$(grep -q -- '-t jpeg' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # The toplevel grab has no compositor border, so the corpse draws its
  # own neon edge: four gradient sides, violet at two corners and sakura
  # at the other two.
  check "the corpse carries its own neon gradient border" \
    "$(grep -q 'anchors { top: parent.top; left: parent.left; right: parent.right }' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && grep -q 'anchors { bottom: parent.bottom; left: parent.left; right: parent.right }' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && grep -q 'GradientStop { position: 1.0; color: "#ffb7d5" }' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && echo 0 || echo 1)"
  # The warm overlay is found through its PID file and /proc, not pgrep: a
  # pgrep per close cost ~30 ms and matched unrelated shells.
  check "the death script finds the warm overlay without pgrep" \
    "$(grep -q 'vp_death_ready' "$REPO_DIR/bin/window_death.sh" \
      && ! grep -q 'pgrep' "$REPO_DIR/bin/window_death.sh" && echo 0 || echo 1)"
  # The plugin writes its shell PID on load and removes the file on a clean
  # shutdown; a stale file fails the liveness check and the script falls back
  # to the one-shot burst instead of closing silently.
  check "the overlay announces readiness by PID" \
    "$(grep -q 'vp_death_ready' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && grep -q 'Quickshell.processId' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && grep -q 'Component.onDestruction' "$REPO_DIR/plugins/window-death/WindowDeath.qml" \
      && echo 0 || echo 1)"
  check "the death burst ships as a warm overlay plugin" \
    "$([[ -f "$REPO_DIR/plugins/window-death/WindowDeath.qml" ]] \
      && grep -q '"overlay"' "$REPO_DIR/plugins/window-death/manifest.json" \
      && grep -q 'keepLoaded' "$REPO_DIR/plugins/window-death/manifest.json" && echo 0 || echo 1)"
  check "the installer retires the old death daemon" \
    "$(! grep -q 'vp_death_daemon.sh' "$REPO_DIR/hypr/autostart.lua" \
      && grep -q 'vp_death_daemon.qml' "$REPO_DIR/lib/step-plugins.sh" && echo 0 || echo 1)"
  # The first beat's payload names a file that is never written; binding the
  # slices to it logged a failed load per slice on every close.
  check "the corpse ignores the pending placeholder path" \
    "$(grep -q 'frame.indexOf(".pending.") !== -1 ? "" : frame' \
      "$REPO_DIR/plugins/window-death/WindowDeath.qml" && echo 0 || echo 1)"
  check "the uninstaller removes the death daemon" \
    "$(grep -q 'vp_death_daemon.qml' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"
  # The ambient tear is a whisper: one or two pixels at a fifth of full
  # opacity. Anything heavier reads as a fault, not atmosphere.
  check "the ambient tear stays a whisper" \
    "$(grep -A2 'property: "tearOpacity"' "$REPO_DIR/bin/ambient_glitch.qml" | grep -q 'to: 0.2' \
      && grep -q 'tearHeight = 1 + Math.random() \* 1' "$REPO_DIR/bin/ambient_glitch.qml" && echo 0 || echo 1)"
  check "the curtain fades out when it is done" \
    "$(grep -q 'exitAnim' "$REPO_DIR/bin/glitch_transition.qml" && grep -q 'Qt.quit()' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "the uninstaller removes the splash" \
    "$(grep -q 'session_splash' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # A theme without a preview falls back to its first wallpaper, which is the
  # slow path the theme just avoided.
  check "the theme gets a preview image" \
    "$(grep -q 'preview.jpg' "$REPO_DIR/install.sh" && echo 0 || echo 1)"

  # The banner: a cached shell wrapper instead of a Python render per shell.
  check "the banner has a shell wrapper" \
    "$([[ -f $REPO_DIR/bin/paradise_banner.sh ]] && echo 0 || echo 1)"
  check "the shell uses the cached banner" \
    "$(grep -q 'paradise_banner.sh' "$REPO_DIR/install.sh" && echo 0 || echo 1)"

  root="$(new_sandbox tc16)"
  mkdir -p "$root/home/.local/state/omarchy/current/theme"
  printf 'virtual-paradise' >"$root/home/.local/state/omarchy/current/theme.name"
  printf 'accent = "#00ffdd"\n' >"$root/home/.local/state/omarchy/current/theme/colors.toml"

  banner_out="$root/banner.out"
  HOME="$root/home" XDG_CACHE_HOME="$root/cache" \
    bash "$REPO_DIR/bin/paradise_banner.sh" >"$banner_out" 2>/dev/null
  check "the banner prints something" \
    "$([[ -s $banner_out ]] && echo 0 || echo 1)"
  check "the banner is cached" \
    "$([[ -f $root/cache/virtual-paradise/banner.txt ]] && echo 0 || echo 1)"

  # The cached copy has to be what the wrapper prints afterwards.
  second_out="$root/banner2.out"
  HOME="$root/home" XDG_CACHE_HOME="$root/cache" \
    bash "$REPO_DIR/bin/paradise_banner.sh" >"$second_out" 2>/dev/null
  check "the cached banner matches the rendered one" \
    "$(cmp -s "$banner_out" "$second_out" && echo 0 || echo 1)"

  # A theme change has to invalidate the cache. The picture can stay the same
  # (our theme always uses the same neon colors), so the cache key is what
  # has to change.
  old_key="$(head -n1 "$root/cache/virtual-paradise/banner.txt" 2>/dev/null)"
  printf 'accent = "#ff00ff"\n' >"$root/home/.local/state/omarchy/current/theme/colors.toml"
  touch -d '2030-01-01' "$root/home/.local/state/omarchy/current/theme/colors.toml"
  third_out="$root/banner3.out"
  HOME="$root/home" XDG_CACHE_HOME="$root/cache" \
    bash "$REPO_DIR/bin/paradise_banner.sh" >"$third_out" 2>/dev/null
  new_key="$(head -n1 "$root/cache/virtual-paradise/banner.txt" 2>/dev/null)"
  check "a theme change invalidates the banner cache" \
    "$([[ -n $old_key && -n $new_key && $old_key != "$new_key" ]] && echo 0 || echo 1)" \
    "old=${old_key:-none} new=${new_key:-none}"

  # The plugin state is read once, and only the difference is applied: about
  # thirty no-op `omarchy plugin` calls were three seconds of every login.
  check "the theme-set hook reads the plugin state once" \
    "$(grep -q 'omarchy plugin list --json' "$REPO_DIR/lib/theme-set-hook.sh" && echo 0 || echo 1)"
  check "the theme-set hook skips plugins that are already in place" \
    "$(grep -q '_plugin_state_of' "$REPO_DIR/lib/theme-set-hook.sh" && echo 0 || echo 1)"

  # The boot image carried ~97 MB of 1920x1080 frames; 1600x900 with a
  # palette is the same picture and a third of the data.
  check "the Plymouth frames are smaller" \
    "$(grep -q 'VP_PLYMOUTH_FRAME_WIDTH=1600' "$REPO_DIR/lib/plymouth.sh" && echo 0 || echo 1)"
  check "the Plymouth frames use a palette" \
    "$(grep -q 'VP_PLYMOUTH_FRAME_PIXEL_FORMAT="pal8"' "$REPO_DIR/lib/plymouth.sh" && echo 0 || echo 1)"

  # The picture is centred and the bars around it are decorated, so a smaller
  # frame does not leave a black rectangle around the animation.
  check "the Plymouth script centres the picture" \
    "$(grep -q 'global.left = global.screen_w / 2 - global.frame_width / 2' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"
  check "the Plymouth script draws the neon frame" \
    "$(grep -q 'Image("frame.png")' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"
  check "the Plymouth script draws the cyber backdrop" \
    "$(grep -q 'Image("backdrop.png")' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"
  check "the neon frame ships with the theme" \
    "$([[ -f $REPO_DIR/plymouth/frame.png ]] && echo 0 || echo 1)"
  check "the cyber backdrop ships with the theme" \
    "$([[ -f $REPO_DIR/plymouth/backdrop.png ]] && echo 0 || echo 1)"
  check "no caption is drawn over the splash" \
    "$(grep -q 'caption.png' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 1 || echo 0)"
  check "no leftover pattern tile in the script" \
    "$(grep -q 'tile.png' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 1 || echo 0)"
  check "the decoration is installed with the theme" \
    "$(grep -q 'VP_PLYMOUTH_DECORATION' "$REPO_DIR/lib/plymouth.sh" && echo 0 || echo 1)"
  # The frame and the picture have to be the same size, or the neon border
  # does not sit on the edge of the animation. The size is read from the PNG
  # header: ImageMagick is not installed in CI.
  if [[ -f $REPO_DIR/plymouth/frame.png ]]; then
    frame_size="$( . "$REPO_DIR/lib/plymouth.sh"; plymouth_image_size "$REPO_DIR/plymouth/frame.png" 2>/dev/null || echo none )"
    check "the neon frame matches the animation size (${frame_size})" \
      "$([[ $frame_size == "1600x900" ]] && echo 0 || echo 1)"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-17  Shell layout ownership.
#
# shell.json is user data. install.sh, the theme-set hook and the post-update
# hook all have to agree on when it may be replaced: missing, stock, the previous
# theme layout, or the layout this theme applied last. Anything else is a user
# edit and must survive a theme round-trip.
# ─────────────────────────────────────────────────────────────────────────────
if want tc17; then
  section "TC-17  Shell layout ownership"

  root="$(new_sandbox tc17)"
  cfg="$root/home/.config/omarchy"
  state="$root/home/.local/state/virtual-paradise"
  mkdir -p "$cfg" "$state"
  # The stock default and the live file have the same bar, but different
  # runtime plugin state. That difference must not look like a user edit.
  cat >"$cfg/shell-default.json" <<'EOF'
{
  "bar": {
    "id": "omarchy.bar",
    "position": "top",
    "layout": { "left": [], "center": [], "right": [] }
  },
  "plugins": [{ "id": "stock.plugin" }],
  "disabledPlugins": ["stock.disabled"]
}
EOF
  cat >"$cfg/shell.json" <<'EOF'
{
  "bar": {
    "id": "omarchy.bar",
    "position": "top",
    "layout": { "left": [], "center": [], "right": [] }
  },
  "plugins": [{ "id": "user.keep" }],
  "disabledPlugins": ["user.disabled"]
}
EOF
  cat >"$root/theme.json" <<'EOF'
{
  "bar": {
    "id": "tester.island-bar",
    "position": "bottom",
    "layout": { "left": [{ "id": "theme.widget" }], "center": [], "right": [] }
  },
  "plugins": [{ "id": "theme.plugin" }],
  "disabledPlugins": []
}
EOF
  cat >"$root/user.json" <<'EOF'
{
  "bar": {
    "id": "tester.island-bar",
    "position": "left",
    "layout": { "left": [{ "id": "user.widget" }], "center": [], "right": [] }
  },
  "plugins": [{ "id": "user.keep" }],
  "disabledPlugins": ["user.disabled"]
}
EOF

  layout_install() {
    ( VP_CONFIG_DIR="$root/home/.config" VP_STATE_DIR="$state" \
      bash -c '. "$1"; vp_layout_install_from "$2" "${3:-0}"' \
        _ "$REPO_DIR/lib/shell-layout.sh" "$1" "${2:-0}" 2>/dev/null )
  }
  layout_enter() {
    ( VP_CONFIG_DIR="$root/home/.config" VP_STATE_DIR="$state" \
      bash -c '. "$1"; vp_layout_enter' _ "$REPO_DIR/lib/shell-layout.sh" 2>/dev/null )
  }
  layout_leave() {
    ( VP_CONFIG_DIR="$root/home/.config" VP_STATE_DIR="$state" \
      bash -c '. "$1"; vp_layout_leave' _ "$REPO_DIR/lib/shell-layout.sh" 2>/dev/null )
  }

  check "a stock layout is replaced" \
    "$([[ $(layout_install "$root/theme.json") == applied ]] && echo 0 || echo 1)"
  check "the theme layout becomes live" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" && echo 0 || echo 1)"
  check "the theme layout is recorded for the next run" \
    "$(grep -q 'theme.widget' "$cfg/shell-paradise.json" && echo 0 || echo 1)"
  check "the applied layout is recorded" \
    "$([[ -f $state/shell-layout.applied.json ]] && echo 0 || echo 1)"
  check "the runtime plugin list survives the layout write" \
    "$(grep -q 'user.keep' "$cfg/shell.json" && grep -q 'user.disabled' "$cfg/shell.json" \
      && echo 0 || echo 1)"
  check "the theme template does not overwrite the plugin list" \
    "$(grep -q 'theme.plugin' "$cfg/shell.json" && echo 1 || echo 0)"

  # Omarchy's activeBarId fallback changes the bar id when the first-party bar
  # cannot load. That transient state must be treated as ours, not as a user
  # edit that pins the stock bar forever.
  cat >"$root/fallback.json" <<'EOF'
{
  "bar": {
    "id": "omarchy.bar",
    "position": "top",
    "layout": { "left": [], "center": [{ "id": "omarchy.bluetooth" }], "right": [] }
  },
  "plugins": [{ "id": "user.keep" }],
  "disabledPlugins": ["user.disabled"]
}
EOF
  cp "$root/fallback.json" "$cfg/shell.json"
  check "a host bar fallback is not a user edit" \
    "$([[ $(layout_install "$root/theme.json") == applied ]] && echo 0 || echo 1)"
  check "the fallback is replaced by the theme bar" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" \
      && ! grep -q 'omarchy.bluetooth' "$cfg/shell.json" && echo 0 || echo 1)"
  check "the fallback replacement preserves plugin state" \
    "$(grep -q 'user.keep' "$cfg/shell.json" && echo 0 || echo 1)"

  # Entering and leaving must recognise the same host fallback. Otherwise a
  # theme switch could pin the stock bar or leave the theme plugin state behind.
  cp "$root/fallback.json" "$cfg/shell.json"
  check "entering the theme repairs a host bar fallback" \
    "$([[ $(layout_enter) == applied ]] && grep -q 'theme.widget' "$cfg/shell.json" \
      && echo 0 || echo 1)"
  cp "$root/fallback.json" "$cfg/shell.json"
  check "leaving the theme restores the stock bar after a fallback" \
    "$([[ $(layout_leave) == restored ]] && ! grep -q 'theme.widget' "$cfg/shell.json" \
      && grep -q 'stock.plugin' "$cfg/shell.json" && echo 0 || echo 1)"

  # A user edit is not one of the replaceable states.
  cp "$root/user.json" "$cfg/shell.json"
  check "a user-customised layout is preserved" \
    "$([[ $(layout_install "$root/theme.json") == preserved ]] && echo 0 || echo 1)"
  check "the user edit survives a reinstall" \
    "$(grep -q 'user.widget' "$cfg/shell.json" && echo 0 || echo 1)"
  check "entering the theme preserves a user edit" \
    "$([[ $(layout_enter) == preserved ]] && echo 0 || echo 1)"
  check "leaving the theme preserves a user edit" \
    "$([[ $(layout_leave) == preserved ]] && echo 0 || echo 1)"
  check "the user edit is still live after leaving" \
    "$(grep -q 'user.widget' "$cfg/shell.json" && echo 0 || echo 1)"

  # --force-shell-layout is the explicit escape hatch.
  check "--force replaces a user-customised layout" \
    "$([[ $(layout_install "$root/theme.json" 1) == applied ]] && echo 0 || echo 1)"
  check "the forced layout is live" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" && echo 0 || echo 1)"
  check "the forced layout still preserves the plugin list" \
    "$(grep -q 'user.keep' "$cfg/shell.json" && echo 0 || echo 1)"

  # Auto-added widgets land in centerBegin/centerEnd/tray; that scrambled
  # layout is the plugin registry talking, not a user edit, so the theme
  # layout is re-applied instead of being preserved.
  cat >"$root/scrambled.json" <<'EOF'
{
  "bar": {
    "id": "tester.island-bar",
    "position": "top",
    "layout": {
      "left": [],
      "center": [{ "id": "theme.widget" }],
      "centerEnd": [{ "id": "auto.added" }],
      "right": []
    }
  },
  "plugins": [{ "id": "user.keep" }]
}
EOF
  cp "$root/scrambled.json" "$cfg/shell.json"
  check "an auto-add scrambled layout is re-applied" \
    "$([[ $(layout_install "$root/theme.json") == applied ]] && echo 0 || echo 1)"
  check "the auto-added section is gone" \
    "$(! grep -q 'auto.added' "$cfg/shell.json" && echo 0 || echo 1)"
  check "the repaired layout is the theme layout" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" && echo 0 || echo 1)"

  # Leaving restores the stock file only while the live file is still ours.
  check "leaving restores the stock layout" \
    "$([[ $(layout_leave) == restored ]] && echo 0 || echo 1)"
  check "the stock layout is live again" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" && echo 1 || echo 0)"
  check "leaving restores the stock plugin list" \
    "$(grep -q 'stock.plugin' "$cfg/shell.json" && grep -q 'stock.disabled' "$cfg/shell.json" \
      && ! grep -q 'user.keep' "$cfg/shell.json" && echo 0 || echo 1)"
  check "the applied-layout marker is cleared" \
    "$([[ ! -f $state/shell-layout.applied.json ]] && echo 0 || echo 1)"

  # A missing file is ours to create; a second leave is a no-op.
  rm -f "$cfg/shell.json"
  check "a missing layout is installed" \
    "$([[ $(layout_install "$root/theme.json") == applied ]] && echo 0 || echo 1)"
  check "leaving the installed layout restores the stock layout" \
    "$([[ $(layout_leave) == restored ]] && echo 0 || echo 1)"
  check "leaving an already-stock layout is a no-op" \
    "$([[ $(layout_leave) == already ]] && echo 0 || echo 1)"
  check "the no-op leave keeps the stock layout" \
    "$(grep -q 'theme.widget' "$cfg/shell.json" && echo 1 || echo 0)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-18  Post-update repair hook.
#
# `omarchy update` can leave the first-party bar half-copied or missing. The
# hook must repair it from the user-owned copy when it can, and otherwise leave
# shell.json alone and let Omarchy's activeBarId fall back to the stock bar.
# ─────────────────────────────────────────────────────────────────────────────
if want tc18; then
  section "TC-18  Post-update repair hook"

  root="$(new_sandbox tc18)"
  cfg="$root/home/.config/omarchy"
  data="$root/home/.local/share/virtual-paradise"
  state="$root/home/.local/state/virtual-paradise"
  plugins="$root/plugins"
  bar="$plugins/tester.island-bar"
  mkdir -p "$cfg" "$data/island-bar" "$state" "$plugins" "$root/bin"

  cat >"$cfg/shell.json" <<'EOF'
{
  "bar": {
    "id": "tester.island-bar",
    "layout": { "left": [], "center": [], "right": [] }
  }
}
EOF
  shell_before="$(md5sum "$cfg/shell.json" | cut -d' ' -f1)"

  cat >"$data/island-bar/manifest.json" <<'EOF'
{"schemaVersion":1,"id":"tester.island-bar","kinds":["bar"],"entryPoints":{"bar":"Bar.qml"}}
EOF
  printf '// repaired bar\n' >"$data/island-bar/Bar.qml"
  printf 'Bar.qml\nmanifest.json\n' >"$data/island-bar/.paradise-files"

  # The first-party copy is present but broken: the manifest is valid and the
  # entry file is missing. This is the half-copied state an update can leave.
  mkdir -p "$bar"
  cp "$data/island-bar/manifest.json" "$bar/manifest.json"
  printf 'Bar.qml\nmanifest.json\n' >"$bar/.paradise-files"

  # A sudo that actually runs the command (with -n stripped), so the repair path
  # is exercised without touching the real /usr/share.
  cat >"$root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -n ]] && shift
exec "$@"
EOF
  chmod +x "$root/bin/sudo"

  cat >"$root/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${SHIM_LOG:-/dev/null}"
if [[ ${1:-} == plugin && ${2:-} == list && ${3:-} == --json ]]; then
  printf '[]\n'
  exit 0
fi
exit 0
EOF
  chmod +x "$root/bin/omarchy"

  for tool in omarchy-shell hyprctl notify-send; do
    cat >"$root/bin/$tool" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${SHIM_LOG:-/dev/null}"
exit 0
EOF
    chmod +x "$root/bin/$tool"
  done

  run_post_update() {
    ( PATH="$root/bin:$PATH" \
      HOME="$root/home" \
      XDG_CONFIG_HOME="$root/home/.config" \
      XDG_DATA_HOME="$root/home/.local/share" \
      XDG_STATE_HOME="$root/home/.local/state" \
      USER=tester \
      PARADISE_FIRST_PARTY_DIR="$plugins" \
      SHIM_LOG="$root/hook.log" \
      bash "$REPO_DIR/lib/post-update-hook.sh" >"$root/hook.out" 2>&1 )
  }

  : >"$root/hook.log"
  run_post_update
  check "post-update hook exits cleanly" $?
  check "post-update hook repairs a broken island bar" \
    "$([[ -f $bar/Bar.qml ]] && echo 0 || echo 1)"
  check "the repaired bar has the expected entry point" \
    "$(grep -qx '// repaired bar' "$bar/Bar.qml" && echo 0 || echo 1)"
  check "the repair enables the first-party bar" \
    "$(grep -q 'plugin enable tester.island-bar' "$root/hook.log" && echo 0 || echo 1)"
  check "the repair does not rewrite shell.json" \
    "$([[ $(md5sum "$cfg/shell.json" | cut -d' ' -f1) == "$shell_before" ]] && echo 0 || echo 1)"
  check "the repaired bar is no longer in fallback" \
    "$([[ ! -f $state/bar-missing ]] && echo 0 || echo 1)"

  # Now the repair is impossible: no usable sudo. The hook must still exit 0,
  # leave the broken copy for the host fallback, and not touch shell.json.
  rm -f "$bar/Bar.qml"
  cat >"$root/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$root/bin/sudo"
  : >"$root/hook.log"
  run_post_update
  check "post-update hook survives an unrepairable bar" $?
  check "the broken bar is left for the host fallback" \
    "$([[ ! -f $bar/Bar.qml ]] && echo 0 || echo 1)"
  check "fallback does not rewrite shell.json" \
    "$([[ $(md5sum "$cfg/shell.json" | cut -d' ' -f1) == "$shell_before" ]] && echo 0 || echo 1)"
  check "fallback records a notice once" \
    "$([[ -f $state/bar-missing ]] && echo 0 || echo 1)"
  check "fallback does not force-enable the broken bar" \
    "$(grep -q 'plugin enable tester.island-bar' "$root/hook.log" && echo 1 || echo 0)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-19  Stability guards.
#
# The stock tray is not patched, unit conditions live in [Unit], a stale-socket
# cleanup is a success, and the theme hook falls back to the stock widget when a
# replacement plugin is not installed.
# ─────────────────────────────────────────────────────────────────────────────
if want tc19; then
  section "TC-19  Stability guards"

  check "install.sh has no system tray patch" \
    "$(grep -q 'patch_system_tray\|Tray\.qml' "$REPO_DIR/install.sh" && echo 1 || echo 0)"
  check "uninstall.sh has no system tray patch" \
    "$(grep -q 'Tray\.qml' "$REPO_DIR/uninstall.sh" && echo 1 || echo 0)"

  for unit in paradise-plugin-check.service paradise-audio-watchdog.service; do
    condition_section="$(awk '
      /^\[Unit\]/{s="unit"}
      /^\[Service\]/{s="service"}
      /^ConditionPathExists=/{print s}
    ' "$REPO_DIR/systemd/$unit" | grep -qx unit && echo 0 || echo 1)"
    check "$unit keeps ConditionPathExists in [Unit]" "$condition_section"
  done

  check "the audio watchdog treats stale-socket cleanup as success" \
    "$(grep -A4 'no daemon process found' "$REPO_DIR/bin/audio-backend-watchdog.sh" \
      | grep -q 'exit 0' && echo 0 || echo 1)"

  # Theme-hook fallback: the replacement plugin is not installed, so the stock
  # audio widget must stay enabled. The old hook disabled it unconditionally,
  # which is how leaving the theme produced a bar with no audio widget.
  root="$(new_sandbox tc19)"
  cfg="$root/home/.config"
  data="$root/home/.local/share/virtual-paradise"
  mkdir -p "$cfg" "$data" "$root/bin"
  cat >"$root/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${SHIM_LOG:-/dev/null}"
if [[ ${1:-} == plugin && ${2:-} == list && ${3:-} == --json ]]; then
  cat "${PLUGIN_STATE_FILE:-/dev/null}" 2>/dev/null || printf '[]\n'
  exit 0
fi
exit 0
EOF
  chmod +x "$root/bin/omarchy"
  cat >"$root/bin/pkill" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$root/bin/pkill"
  cat >"$root/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$root/bin/pgrep"
  cat >"$data/plugin-overrides.sh" <<'EOF'
po_apply_all() { printf 'apply\n' >>"${VP_TEST_LOG:-/dev/null}"; }
po_revert_all() { printf 'revert\n' >>"${VP_TEST_LOG:-/dev/null}"; }
EOF

  : >"$root/hook.log"
  : >"$root/layer.log"
  # The stock background service is off and a stale fork copy is on (the state
  # an older install leaves behind): the hook must put the stock one back and
  # disable the leftover, which kept a second IPC handler on "background".
  printf '[{"id":"omarchy.audio","enabled":false},{"id":"omarchy.bluetooth","enabled":false},{"id":"omarchy.bar","enabled":false},{"id":"omarchy.background","enabled":false},{"id":"tester.background","enabled":true}]\n' \
    >"$root/plugin-state.json"
  ( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$cfg" \
    XDG_DATA_HOME="$root/home/.local/share" XDG_STATE_HOME="$root/home/.local/state" \
    USER=tester SHIM_LOG="$root/hook.log" VP_TEST_LOG="$root/layer.log" \
    PLUGIN_STATE_FILE="$root/plugin-state.json" \
    bash "$REPO_DIR/lib/theme-set-hook.sh" virtual-paradise >/dev/null 2>&1 )
  check "theme hook entering applies the tracked override layer" \
    "$(grep -qx apply "$root/layer.log" 2>/dev/null && echo 0 || echo 1)"
  check "theme hook entering keeps the stock audio widget" \
    "$(grep -q 'plugin enable omarchy.audio' "$root/hook.log" && echo 0 || echo 1)"
  check "theme hook entering does not disable the stock audio widget" \
    "$(grep -q 'plugin disable omarchy.audio' "$root/hook.log" && echo 1 || echo 0)"
  check "theme hook entering does not enable a missing replacement" \
    "$(grep -q 'plugin enable ssupt.audio-control' "$root/hook.log" && echo 1 || echo 0)"
  check "theme hook entering restores the stock background service" \
    "$(grep -q 'plugin enable omarchy.background' "$root/hook.log" \
      && grep -q 'plugin disable tester.background' "$root/hook.log" && echo 0 || echo 1)"

  : >"$root/hook.log"
  # Leaving does the same in reverse for a stale copy: the stock service stays
  # the one renderer.
  printf '[{"id":"omarchy.audio","enabled":false},{"id":"omarchy.bluetooth","enabled":false},{"id":"omarchy.bar","enabled":false},{"id":"omarchy.background","enabled":false},{"id":"tester.background","enabled":true}]\n' \
    >"$root/plugin-state.json"
  ( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$cfg" \
    XDG_DATA_HOME="$root/home/.local/share" XDG_STATE_HOME="$root/home/.local/state" \
    USER=tester SHIM_LOG="$root/hook.log" VP_TEST_LOG="$root/layer.log" \
    PLUGIN_STATE_FILE="$root/plugin-state.json" \
    bash "$REPO_DIR/lib/theme-set-hook.sh" catppuccin >/dev/null 2>&1 )
  check "theme hook leaving reverts the tracked override layer" \
    "$(grep -qx revert "$root/layer.log" 2>/dev/null && echo 0 || echo 1)"
  check "theme hook leaving enables the stock audio widget" \
    "$(grep -q 'plugin enable omarchy.audio' "$root/hook.log" && echo 0 || echo 1)"
  check "theme hook leaving keeps the stock background service" \
    "$(grep -q 'plugin enable omarchy.background' "$root/hook.log" \
      && grep -q 'plugin disable tester.background' "$root/hook.log" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-20  Hover glow.
#
# The per-widget halo is an opt-out effect: it follows the bar's gap-effects
# switch, hides while a widget is being dragged, and can be disabled on its own
# from shell.json. It must not depend on a new plugin or a package-owned file.
# ─────────────────────────────────────────────────────────────────────────────
if want tc20; then
  section "TC-20  Hover glow"

  glow="$REPO_DIR/bars/island-bar/HoverGlow.qml"
  check "HoverGlow.qml ships with the island bar" \
    "$([[ -f $glow ]] && echo 0 || echo 1)"
  check "the hover glow is a shape-following ramp halo" \
    "$(grep -q 'import QtQuick.Effects' "$glow" \
      && grep -q 'RectangularShadow' "$glow" && grep -q 'blur:' "$glow" \
      && grep -q 'root.accent' "$glow" \
      && grep -q 'Color.accent !== undefined' "$glow" && echo 0 || echo 1)"
  check "the hover glow fades instead of popping" \
    "$(grep -q 'Behavior on opacity' "$glow" && echo 0 || echo 1)"
  check "ModuleSlot instantiates the hover glow" \
    "$(grep -q 'HoverGlow {' "$REPO_DIR/bars/island-bar/Bar.qml" && echo 0 || echo 1)"
  check "the hover glow hides while a widget is dragged" \
    "$(grep -q '!slot.dragSource' "$REPO_DIR/bars/island-bar/Bar.qml" && echo 0 || echo 1)"
  check "the hover glow follows the bar effects switch" \
    "$(grep -q 'hoverEffectsEnabled: islandsEnabled && gapEffects && hoverGlow' \
      "$REPO_DIR/bars/island-bar/Bar.qml" && echo 0 || echo 1)"
  check "the hover glow defaults off" \
    "$(grep -q 'property bool hoverGlow: false' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && echo 0 || echo 1)"
  check "the hover glow is opt-in from shell.json" \
    "$(grep -q 'config.hoverGlow === true' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-21  Island chrome and gap effects.
#
# The bar reads as three floating pills, not one outlined plate: the hex layer
# is an underlay with no fill or border, the islands carry the only rims, the
# gap effect is a fixed comet stream, and the centre gets the focal treatment.
# ─────────────────────────────────────────────────────────────────────────────
if want tc21; then
  section "TC-21  Island chrome and gap effects"

  neon="$REPO_DIR/bars/island-bar/NeonBackdrop.qml"
  island="$REPO_DIR/bars/island-bar/IslandBackdrop.qml"
  gap="$REPO_DIR/bars/island-bar/GapGlow.qml"
  bar="$REPO_DIR/bars/island-bar/Bar.qml"

  check "the hex layer is an underlay, not a second plate" \
    "$(grep -q 'patternOpacity' "$neon" \
      && ! grep -q 'border.width' "$neon" \
      && ! grep -q 'Qt.rgba(root.base' "$neon" && echo 0 || echo 1)"
  # A full lattice repaint is ~15ms - the whole frame budget - so the drift
  # stuttered. The pattern is painted once and blitted at the drift offset.
  check "the hex drift blits a cached lattice" \
    "$(grep -q 'ctx.drawImage(lattice' "$neon" \
      && grep -q 'renderStrategy: Canvas.Immediate' "$neon" && echo 0 || echo 1)"
  check "the islands carry a glass gradient and a focal accent bloom" \
    "$(grep -q 'gradient: Gradient' "$island" \
      && grep -q 'glowStrength' "$island" \
      && grep -q 'Qt.lighter(root.base' "$island" && echo 0 || echo 1)"
  check "island width changes ease instead of snapping" \
    "$(grep -q 'animateWidth' "$island" \
      && grep -q 'Behavior on width' "$island" && echo 0 || echo 1)"
  check "the gap effect is a bar-independent comet stream" \
    "$(grep -q 'cometSpacing' "$gap" \
      && grep -q 'cometOffset' "$gap" \
      && grep -q 'var head = first + k \* root.cometSpacing' "$gap" \
      && grep -q 'createLinearGradient' "$gap" \
      && ! grep -q 'Date.now()' "$gap" \
      && ! grep -q 'slowSpacing' "$gap" && echo 0 || echo 1)"
  check "the centre island is the focal surface" \
    "$(grep -q 'glowStrength: 0.20' "$bar" \
      && grep -q 'animateWidth: true' "$bar" && echo 0 || echo 1)"
  check "turning off the effects freezes the hex drift" \
    "$(grep -q 'animated: root.gapEffects' "$bar" && echo 0 || echo 1)"
  check "the bar gives the islands a wider gutter" \
    "$(grep -q 'readonly property int islandPad: Style.space(8)' "$bar" \
      && grep -q 'spacing: Style.space(5)' "$bar" && echo 0 || echo 1)"
  check "the hover halo stays inside the island" \
    "$(grep -q 'Keep the halo inside the island' "$bar" \
      && grep -q 'radius: Math.min(width, height) / 2' "$bar" && echo 0 || echo 1)"
  # The tray drawer grows the right island's row; anchored to the outer edge
  # the row grows into the gap and the other icons stay put, instead of the
  # whole row sliding while the host width animation catches up.
  check "the right island row is anchored to the outer edge" \
    "$(grep -A10 'id: rightModules$' "$bar" | grep -q 'anchors.right: parent.right' \
      && ! grep -A10 'id: rightModules$' "$bar" | grep -q 'x: root.islandPad' \
      && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-22  Rotating gradient chrome.
#
# The bar rim, the centre bloom and the Super+Space menu border all ride the
# same slow spin and the same window-gradient token, so the chrome matches the
# compositor's window borders. The menu hook must stay guarded: it reaches
# into a package-owned plugin from the first-party bar, and an upstream rename
# has to disable the effect, not break the menu.
# ─────────────────────────────────────────────────────────────────────────────
if want tc22; then
  section "TC-22  Rotating gradient chrome"

  island="$REPO_DIR/bars/island-bar/IslandBackdrop.qml"
  ramp="$REPO_DIR/bars/island-bar/RimRamp.qml"
  bar="$REPO_DIR/bars/island-bar/Bar.qml"

  check "the shared ramp rides the window gradient token" \
    "$(grep -q 'Border.surfaceSpec("hyprland", "active-border"' "$ramp" \
      && echo 0 || echo 1)"
  check "the rim angle is animated slowly and linearly" \
    "$(grep -q 'property real rimAngle' "$bar" \
      && grep -q 'NumberAnimation on rimAngle' "$bar" \
      && grep -q 'duration: 15000' "$bar" \
      && grep -q 'easing.type: Easing.Linear' "$bar" && echo 0 || echo 1)"
  check "every island follows the bar rim angle" \
    "$([[ $(grep -c 'rimAngle: root.rimAngle' "$bar") -eq 6 ]] && echo 0 || echo 1)"
  check "the centre bloom samples the rim ramp" \
    "$(grep -q 'ramp.colorAt' "$island" && echo 0 || echo 1)"
  check "every panel border rides the same spin" \
    "$(grep -q 'function applyPanelRims' "$bar" \
      && grep -q 'panelLoaders' "$bar" \
      && grep -q 'running: root.anyPanelOpen' "$bar" && echo 0 || echo 1)"
  check "the panel hook fails soft on a missing property" \
    "$(grep -q '!("borderSpec" in item)' "$bar" \
      && grep -q '!spec.gradient.enabled' "$bar" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-23  Hover chrome.
#
# The hover effect is a miniature window: a rotating gradient rim, a bloom
# sampled from the shared ramp and a hex shimmer inside the pill. The chrome
# is created by a Loader only while the halo is visible, and the bar passes
# its own rim angle so the hover rim joins the same spin as the islands.
# ─────────────────────────────────────────────────────────────────────────────
if want tc23; then
  section "TC-23  Hover chrome"

  glow="$REPO_DIR/bars/island-bar/HoverGlow.qml"
  bar="$REPO_DIR/bars/island-bar/Bar.qml"
  ramp="$REPO_DIR/bars/island-bar/RimRamp.qml"

  check "RimRamp.qml ships with the island bar" \
    "$([[ -f $ramp ]] && echo 0 || echo 1)"
  check "the hover rim rides the shared ramp and the bar angle" \
    "$(grep -q 'RimRamp {' "$glow" \
      && grep -q 'angle: root.barAngle' "$glow" \
      && grep -q 'colors: ramp.colors' "$glow" && echo 0 || echo 1)"
  check "the hover bloom samples the ramp" \
    "$(grep -q 'ramp.colorAt' "$glow" && echo 0 || echo 1)"
  check "the hover pill carries a clipped hex shimmer" \
    "$(grep -q 'ctx.clip()' "$glow" \
      && grep -q 'ctx.arcTo' "$glow" \
      && grep -q 'hexW' "$glow" && echo 0 || echo 1)"
  check "the chrome only exists while the halo is visible" \
    "$(grep -q 'active: root.active || root.opacity > 0' "$glow" \
      && grep -q 'sourceComponent: chrome' "$glow" && echo 0 || echo 1)"
  check "the bar feeds its rim angle into the hover chrome" \
    "$(grep -q 'barAngle: root.rimAngle' "$bar" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-24  Bar border chrome.
#
# The bar border has to read as its own thing next to the hover chrome: one
# scanner spark orbiting the whole bar, an inner hairline and a faint ramp
# aura on every island. The empty omarchy.spacer must not come back into the
# centre layout, where it showed up as a hoverable hole.
# ─────────────────────────────────────────────────────────────────────────────
if want tc24; then
  section "TC-24  Bar border chrome"

  bar="$REPO_DIR/bars/island-bar/Bar.qml"
  island="$REPO_DIR/bars/island-bar/IslandBackdrop.qml"
  light="$REPO_DIR/bars/island-bar/RimLight.qml"
  shell="$REPO_DIR/shell/shell.json"

  check "RimLight.qml ships with the island bar" \
    "$([[ -f $light ]] && echo 0 || echo 1)"
  check "the bar border runs a scanner spark" \
    "$(grep -q 'RimLight {' "$bar" \
      && grep -q 'lightEnabled: root.islandsEnabled && root.gapEffects' "$bar" \
      && grep -q 'sparkSpeed' "$light" && echo 0 || echo 1)"
  check "the scanner walks the rounded-rect perimeter" \
    "$(grep -q 'function rimPoint' "$light" \
      && grep -q 'straightX' "$light" && echo 0 || echo 1)"
  check "the islands carry an inner hairline and a ramp aura" \
    "$(grep -q 'Inner hairline' "$island" \
      && grep -q 'glowStrength' "$island" \
      && grep -q 'glowStrength: 0.10' "$bar" \
      && grep -q 'glowStrength: 0.20' "$bar" && echo 0 || echo 1)"
  check "the bar rim is a two-pixel gradient line with a ramp hairline" \
    "$(grep -q 'widths: { top: 2' "$island" \
      && grep -q 'ramp.colorAt' "$island" && echo 0 || echo 1)"
  check "one spark orbits the whole bar" \
    "$(grep -q 'totalPerimeter' "$light" \
      && grep -q 'sparkOffset' "$light" \
      && ! grep -q 'spark < 2' "$light" && echo 0 || echo 1)"
  check "the empty omarchy.spacer is gone from the centre layout" \
    "$(grep -q 'omarchy.spacer' "$shell" && echo 1 || echo 0)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-25  Terminal hex spotlight.
#
# The terminal itself stays plain glass: no background image, so no hexes are
# visible at rest. The cursor spotlight paints the hex grid, and the grid must
# be anchored to the terminal window - one fixed cell size, and the phase
# taken from where the canvas actually sits, so the lit hexes do not slide
# while the pool animates towards the pointer.
# ─────────────────────────────────────────────────────────────────────────────
if want tc25; then
  section "TC-25  Terminal hex spotlight"

  gconf="$REPO_DIR/config/terminal/ghostty.conf"
  kconf="$REPO_DIR/config/terminal/kitty.conf"
  spot="$REPO_DIR/plugins/hex-spotlight/HexSpotlight.qml"

  check "the terminal stays plain glass (no hex background image)" \
    "$(! grep -q '^background-image' "$gconf" && echo 0 || echo 1)"
  check "kitty has no hex background image either" \
    "$(! grep -q '^background_image' "$kconf" && echo 0 || echo 1)"
  check "the hex tile is gone from the repo" \
    "$([[ ! -f "$REPO_DIR/assets/terminal-bg.png" ]] && echo 0 || echo 1)"
  check "the installer does not ship a terminal background image" \
    "$(! grep -q 'terminal-bg.png' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the spotlight paints one fixed hex size" \
    "$(grep -q 'readonly property int cell: 7' "$spot" && echo 0 || echo 1)"
  # A full lattice repaint is ~37ms, so the lattice is painted once into an
  # offscreen canvas and each frame blits it; the pool canvas is synchronous
  # because a threaded paint can be shown a frame late and slide the grid.
  check "the spotlight caches the lattice and blits it" \
    "$(grep -q 'ctx.drawImage(lattice' "$spot" \
      && grep -q 'renderStrategy: Canvas.Immediate' "$spot" && echo 0 || echo 1)"
  # The phase must come from the canvas' actual (animated) position, not from
  # the cursor target, and the vertical shift stays modulo two rows so the
  # row parity never flips.
  check "the spotlight anchors the grid to its own position" \
    "$(grep -q 'spotlight.x % spotlight.hexW' "$spot" \
      && grep -q '2 \* spotlight.rowStep' "$spot" && echo 0 || echo 1)"
  # The pool lives in screen coordinates so a focus change (which moves the
  # panel's origin) recomputes the item's offset instead of gliding across
  # it - that glide was the glow racing in from a corner of the terminal.
  check "the pool is screen-anchored and snaps on a jump" \
    "$(grep -q 'property real poolX' "$spot" \
      && grep -q 'x: poolX - modelData.x - root.winX' "$spot" \
      && grep -q 'Math.abs(x - poolX) > 600' "$spot" && echo 0 || echo 1)"
  # onThisScreen lives on the delegate (the PanelWindow), not on the outer
  # root item; `root.onThisScreen` is always undefined and leaves the panel
  # permanently invisible.
  check "the spotlight gates on the delegate's own onThisScreen" \
    "$(grep -q 'visible: !!(root.terminalFocused && onThisScreen' "$spot" \
      && ! grep -q 'root\.onThisScreen' "$spot" && echo 0 || echo 1)"
  # Focus must arrive the moment it changes: polling hyprctl made the glow
  # appear up to half a second after a terminal was focused.
  check "focus is tracked from the event socket, not a poll" \
    "$([[ -f "$REPO_DIR/bin/vp_window_track.py" ]] \
      && grep -q 'vp_window_track.py' "$spot" \
      && ! grep -q 'command: \["hyprctl"' "$spot" && echo 0 || echo 1)"
  # The spotlight maps and unmaps with focus, so the default layersIn
  # slidefade would read as the glow fading in late.
  check "the spotlight layer is excluded from the layer animation" \
    "$(grep -q 'vp-scanlines|vp-hex-spotlight' "$REPO_DIR/hypr/looknfeel.lua" \
      && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-26  Cooler Boost state.
#
# The embedded controller keeps the fan profile across reboots, so a state
# file alone lies: after a reboot /tmp is gone while the fans may still be at
# 100%. The toggle must answer from the hardware, repair the fallback file,
# and a bare toggle from a stale "off" file must turn the boost OFF, not
# re-enable it.
# ─────────────────────────────────────────────────────────────────────────────
if want tc26; then
  section "TC-26  Cooler Boost state"

  script="$REPO_DIR/bin/toggle_cooler_boost.sh"
  widget="$REPO_DIR/plugins/cputemp/BarWidget.qml"

  check "the toggle reads the fan state from the hardware" \
    "$(grep -q 'read_hw_state' "$script" \
      && grep -q 'pwm1_enable' "$script" && echo 0 || echo 1)"
  check "the bar widget asks the hardware instead of the stale file" \
    "$(grep -q 'toggle_cooler_boost.sh state' "$widget" \
      && ! grep -q 'cat /tmp/cooler_boost_state' "$widget" && echo 0 || echo 1)"
  check "the fallback state file survives a reboot" \
    "$(! grep -q '^STATE_FILE="/tmp/' "$script" \
      && grep -q '^STATE_DIR=' "$script" && echo 0 || echo 1)"

  # Functional: a fake EC that says turbo, a fallback file that says off -
  # exactly the post-reboot situation.
  root="$(new_sandbox tc26)"
  fake="$root/hwmon"
  state="$root/state/virtual-paradise"
  mkdir -p "$fake" "$state"
  printf 'acer_nitro_ec\n' > "$fake/name"
  printf '0\n' > "$fake/pwm1_enable"
  printf '0\n' > "$fake/pwm2_enable"
  printf 'off\n' > "$state/cooler_boost"

  out=$(COOLER_BOOST_HWMON="$fake" XDG_STATE_HOME="$root/state" \
    bash "$script" state 2>/dev/null)
  check "state answers from the EC, not the stale file" \
    "$([[ "$out" == "on" ]] && echo 0 || echo 1)" "got: $out"
  check "the stale file was re-synced to the hardware" \
    "$([[ "$(cat "$state/cooler_boost")" == "on" ]] && echo 0 || echo 1)"

  COOLER_BOOST_HWMON="$fake" XDG_STATE_HOME="$root/state" \
    bash "$script" >/dev/null 2>&1
  check "toggling from the stale-off state turns the boost off" \
    "$([[ "$(cat "$fake/pwm1_enable")" == "2" ]] && echo 0 || echo 1)"
  out=$(COOLER_BOOST_HWMON="$fake" XDG_STATE_HOME="$root/state" \
    bash "$script" state 2>/dev/null)
  check "state follows the hardware back down" \
    "$([[ "$out" == "off" ]] && echo 0 || echo 1)" "got: $out"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-27  Shared cursor server.
#
# Two overlays (pointer glow, hex spotlight) need the pointer at cursor rate.
# Each used to run its own Python poller; one server now broadcasts on
# `$XDG_RUNTIME_DIR/vp-cursor.sock` and both plugins read it, so the session
# pays for one process instead of two. A second copy must find the socket
# taken and exit at once instead of doubling the process count.
# ─────────────────────────────────────────────────────────────────────────────
if want tc27; then
  section "TC-27  Shared cursor server"

  pub="$REPO_DIR/bin/vp_cursor_track.py"
  spot="$REPO_DIR/plugins/hex-spotlight/HexSpotlight.qml"
  glow="$REPO_DIR/plugins/cursor-glow/CursorGlow.qml"

  check "one shared cursor server serves both overlays" \
    "$([[ -f "$pub" ]] \
      && grep -q 'vp_cursor_track.py' "$spot" \
      && grep -q 'vp_cursor_track.py' "$glow" \
      && grep -q 'vp-cursor.sock' "$spot" \
      && grep -q 'vp-cursor.sock' "$glow" \
      && ! grep -qF 'resolvedUrl("cursor_track.py")' "$spot" \
      && ! grep -qF 'resolvedUrl("cursor_track.py")' "$glow" && echo 0 || echo 1)"
  check "the server takes the socket only when it is free" \
    "$(grep -q 'probe.connect' "$pub" \
      && grep -q 'os.unlink' "$pub" && echo 0 || echo 1)"
  # Quickshell's Socket does not signal a failed first connect, so the feed
  # must retry on a timer or it stays dead for the whole session.
  check "the socket feed retries a failed first connect" \
    "$(grep -q 'if (!cursorFeed.connected) cursorFeed.connected = true' "$spot" \
      && grep -q 'if (!cursorFeed.connected) cursorFeed.connected = true' "$glow" \
      && echo 0 || echo 1)"

  # Functional: a fake Hyprland command socket answers cursorpos, the server
  # broadcasts it, and a client receives it.
  root="$(new_sandbox tc27)"
  fake_rt="$root/run"
  mkdir -p "$fake_rt/hypr/FAKESIG"
  cat > "$root/fake_hypr.py" <<'PY'
import os, socket, sys
path = sys.argv[1]
try:
    os.unlink(path)
except FileNotFoundError:
    pass
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path)
srv.listen(8)
while True:
    conn, _ = srv.accept()
    data = conn.recv(64)
    if b"cursorpos" in data:
        conn.sendall(b"321, 654\n")
    conn.close()
PY
  python3 "$root/fake_hypr.py" "$fake_rt/hypr/FAKESIG/.socket.sock" &
  fake_pid=$!
  sleep 0.4

  XDG_RUNTIME_DIR="$fake_rt" HYPRLAND_INSTANCE_SIGNATURE=FAKESIG \
    python3 "$pub" &
  pub_pid=$!
  sleep 0.6
  out=$(python3 - "$fake_rt/vp-cursor.sock" <<'PY'
import socket, sys
conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
conn.settimeout(2)
conn.connect(sys.argv[1])
print(conn.recv(64).decode().strip())
PY
)
  check "the server broadcasts the pointer to a client" \
    "$([[ "$out" == "321, 654" ]] && echo 0 || echo 1)" "got: $out"

  XDG_RUNTIME_DIR="$fake_rt" HYPRLAND_INSTANCE_SIGNATURE=FAKESIG \
    timeout 2 python3 "$pub" >/dev/null 2>&1
  rc=$?
  check "a second server yields to the first" \
    "$([[ $rc -eq 0 ]] && echo 0 || echo 1)" "rc=$rc"

  kill "$pub_pid" "$fake_pid" 2>/dev/null || true
  wait "$pub_pid" 2>/dev/null || true
  wait "$fake_pid" 2>/dev/null || true

  # --- the shared window server -------------------------------------------
  win_pub="$REPO_DIR/bin/vp_window_track.py"

  check "one shared window server serves both overlays" \
    "$([[ -f "$win_pub" ]] \
      && grep -q 'vp_window_track.py' "$spot" \
      && grep -q 'vp_window_track.py' "$glow" \
      && [[ ! -f "$REPO_DIR/plugins/hex-spotlight/window_track.py" ]] \
      && echo 0 || echo 1)"
  # The glow is a terminal effect: over a game or a browser it is a bright
  # spot with nothing to light up.
  check "the pointer glow only shows over a terminal" \
    "$(grep -q 'visible: root.overTerminal' "$glow" \
      && grep -q 'cursorX >= winX && cursorX < winX + winW' "$glow" \
      && echo 0 || echo 1)"

  # Functional: a fake Hyprland with both sockets; the server turns the active
  # window into a broadcast line.
  fake2_rt="$root/run2"
  mkdir -p "$fake2_rt/hypr/FAKESIG2"
  cat > "$root/fake_hypr2.py" <<'PY'
import json, os, socket, sys, threading, time
base = sys.argv[1]
cmd_path = os.path.join(base, ".socket.sock")
evt_path = os.path.join(base, ".socket2.sock")
for p in (cmd_path, evt_path):
    try:
        os.unlink(p)
    except FileNotFoundError:
        pass
win = {"class": "com.mitchellh.ghostty", "at": [100, 200], "size": [800, 600]}

def serve_cmd():
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(cmd_path)
    srv.listen(8)
    while True:
        conn, _ = srv.accept()
        data = conn.recv(64)
        if b"j/activewindow" in data:
            conn.sendall(json.dumps(win).encode())
        conn.close()

def serve_evt():
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(evt_path)
    srv.listen(8)
    while True:
        conn, _ = srv.accept()
        time.sleep(0.2)
        try:
            conn.sendall(b"activewindowv2>>deadbeef\n")
        except OSError:
            pass
        time.sleep(3)

threading.Thread(target=serve_cmd, daemon=True).start()
serve_evt()
PY
  python3 "$root/fake_hypr2.py" "$fake2_rt/hypr/FAKESIG2" &
  fake2_pid=$!
  sleep 0.4
  XDG_RUNTIME_DIR="$fake2_rt" HYPRLAND_INSTANCE_SIGNATURE=FAKESIG2 \
    python3 "$win_pub" &
  win_pub_pid=$!
  sleep 0.8
  out=$(python3 - "$fake2_rt/vp-window.sock" <<'PY'
import socket, sys
conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
conn.settimeout(2)
conn.connect(sys.argv[1])
print(conn.recv(256).decode().strip())
PY
)
  check "the window server broadcasts the focused terminal" \
    "$([[ "$out" == "com.mitchellh.ghostty|100,200 800x600" ]] && echo 0 || echo 1)" \
    "got: $out"
  kill "$win_pub_pid" "$fake2_pid" 2>/dev/null || true
  wait "$win_pub_pid" 2>/dev/null || true
  wait "$fake2_pid" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-28  Fork drift and the documented tree.
#
# Nine plugins under plugins/ are forks of omarchy.* first-party plugins, and
# upstream fixes do not reach a fork on their own (the background fork was
# missing the black-desktop workaround). check-upstream-drift.py records the
# upstream hashes and reports what changed; the fixture has to cover every
# fork, and the tool has to notice a change. The README tree must also name
# every top-level directory, or the map of the repo drifts from the repo.
# ─────────────────────────────────────────────────────────────────────────────
if want tc28; then
  section "TC-28  Fork drift and the documented tree"

  drift="$REPO_DIR/tools/check-upstream-drift.py"

  check "the drift tool ships with the repo" \
    "$([[ -f $drift ]] && echo 0 || echo 1)"

  # Every fork has to be in the recorded baseline, or the tool cannot warn
  # about it.
  forks=$(python3 - "$REPO_DIR" <<'PY'
import json, sys
from pathlib import Path
repo = Path(sys.argv[1])
fixture = repo / "tests/fixtures/upstream-hashes.json"
recorded = set(json.loads(fixture.read_text())["plugins"]) if fixture.is_file() else set()
forks = set()
for manifest in (repo / "plugins").glob("*/manifest.json"):
    data = json.loads(manifest.read_text())
    cloned = (data.get("omarchy") or {}).get("clonedFrom")
    if cloned:
        forks.add(str(cloned).split(".")[-1])
print(0 if forks and forks <= recorded else 1)
PY
)
  check "the drift baseline covers every fork" "$forks"

  # Every top-level directory is named in the README tree.
  missing=""
  for d in "$REPO_DIR"/*/; do
    name="$(basename "$d")"
    [[ $name == .git ]] && continue
    grep -q "── $name/" "$REPO_DIR/README.md" || missing="$missing $name"
  done
  check "the README tree names every top-level directory" \
    "$([[ -z $missing ]] && echo 0 || echo 1)" "missing:$missing"

  # Functional: a fixture upstream tree, recorded, then nudged.
  root="$(new_sandbox tc28)"
  stock="$root/stock"
  mkdir -p "$stock/background" "$stock/lock" "$stock/panels/clock" \
    "$stock/panels/weather" "$stock/panels/bluetooth" "$stock/panels/network" \
    "$stock/bar/widgets"
  for pair in "background/Background.qml" "lock/Lock.qml" "panels/clock/Clock.qml" \
              "panels/weather/Weather.qml" "panels/bluetooth/Bluetooth.qml" \
              "panels/network/Network.qml" "bar/widgets/Indicators.qml" \
              "bar/widgets/ActiveWindow.qml" "bar/widgets/SystemUpdate.qml"; do
    printf '// upstream\n' >"$stock/$pair"
  done

  out=$(OMARCHY_PLUGINS_DIR="$stock" VP_UPSTREAM_HASHES="$root/hashes.json" \
    python3 "$drift" --update 2>&1)
  check "the drift tool records a baseline" \
    "$([[ -f "$root/hashes.json" ]] && echo 0 || echo 1)" "$out"
  out=$(OMARCHY_PLUGINS_DIR="$stock" VP_UPSTREAM_HASHES="$root/hashes.json" \
    python3 "$drift" 2>&1); rc=$?
  check "a recorded baseline reports no drift" \
    "$([[ $rc -eq 0 ]] && echo 0 || echo 1)" "$out"

  printf '// upstream changed\n' >>"$stock/bar/widgets/SystemUpdate.qml"
  out=$(OMARCHY_PLUGINS_DIR="$stock" VP_UPSTREAM_HASHES="$root/hashes.json" \
    python3 "$drift" 2>&1); rc=$?
  check "an upstream change is reported" \
    "$([[ $rc -eq 1 ]] && echo 0 || echo 1)" "$out"
  check "the report names the changed file" \
    "$(grep -q 'SystemUpdate.qml changed upstream' <<<"$out" && echo 0 || echo 1)" "$out"

  # ---- 4.5 parity: the new upstream surfaces are either forked or retired
  # with a guard, so a package update cannot bring the old behaviour back.
  for ind in PasswordlessSudo RemoteSession; do
    check "the indicators fork ships $ind" \
      "$([[ -f "$REPO_DIR/plugins/indicators/indicators/$ind.qml" ]] && echo 0 || echo 1)"
  done
  check "the indicators fork lists the 4.5 indicators" \
    "$(grep -q 'PasswordlessSudo.*RemoteSession' "$REPO_DIR/plugins/indicators/Indicators.qml" && echo 0 || echo 1)"
  check "the indicator manifest offers the 4.5 indicators" \
    "$(grep -q '"PasswordlessSudo"' "$REPO_DIR/plugins/indicators/manifest.json" \
      && grep -q '"RemoteSession"' "$REPO_DIR/plugins/indicators/manifest.json" && echo 0 || echo 1)"
  check "the indicator base supports revealWhenInactive" \
    "$(grep -q 'property bool revealWhenInactive' "$REPO_DIR/plugins/indicators/BarIndicator.qml" && echo 0 || echo 1)"

  # The clock fork owns the DST-safe WallClock instead of Quickshell's
  # SystemClock, which re-armed at 1 ms through the repeated DST hour.
  check "the clock fork ships WallClock" \
    "$([[ -f "$REPO_DIR/plugins/clock/WallClock.qml" ]] && echo 0 || echo 1)"
  check "the clock fork uses WallClock, not SystemClock" \
    "$(! grep -q 'SystemClock {' "$REPO_DIR/plugins/clock/BarWidget.qml" \
      && ! grep -q 'SystemClock {' "$REPO_DIR/plugins/clock/Panel.qml" \
      && grep -q 'WallClock {' "$REPO_DIR/plugins/clock/BarWidget.qml" && echo 0 || echo 1)"

  # Floating-window titlebars read `lighter_background`; without it they fell
  # back to the selection colour, a solid accent bar.
  check "the palette has a raised titlebar surface" \
    "$(grep -q '^lighter_background' "$REPO_DIR/theme/colors.toml" && echo 0 || echo 1)"

  # The notification bell is retired: installer removes a stale copy, the
  # hook does the same on a theme switch, and nothing re-adds it from git.
  check "the installer retires the third-party notification bell" \
    "$(grep -q 'plugin remove "jankeesvw.notification-center"' "$REPO_DIR/lib/step-plugins.sh" \
      && ! grep -q 'omarchy-notification-center.git' "$REPO_DIR/lib/step-plugins.sh" && echo 0 || echo 1)"
  check "the theme hook retires the notification bell too" \
    "$(grep -q 'plugin remove "jankeesvw.notification-center"' "$REPO_DIR/lib/theme-set-hook.sh" && echo 0 || echo 1)"
  check "the uninstaller removes the notification bell" \
    "$(grep -q 'plugin remove "jankeesvw.notification-center"' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # The world clock is merged into the clock's calendar dropdown, so the
  # standalone Elsewhen panel stays off while the theme is active.
  check "the theme hook keeps the standalone world clock off" \
    "$(grep -q '_plugin_disable "omarchy.elsewhen"' "$REPO_DIR/lib/theme-set-hook.sh" \
      && ! grep -q '_plugin_enable "omarchy.elsewhen"' "$REPO_DIR/lib/theme-set-hook.sh" && echo 0 || echo 1)"
  check "the clock panel carries the merged world clock" \
    "$(grep -q 'worldZones' "$REPO_DIR/plugins/clock/Panel.qml" \
      && grep -q 'WORLD CLOCK' "$REPO_DIR/plugins/clock/Panel.qml" && echo 0 || echo 1)"

  # The minimal bar keeps the specialized widgets installed but switched off:
  # enabling a bar-widget auto-adds it to shell.json, so the theme disables
  # them and drops any stale entry.
  check "the theme mounts the specialized widgets hidden for the Tools menu" \
    "$(grep -Fq 'omarchy plugin enable "$_tool"' "$REPO_DIR/lib/step-plugins.sh" \
      && grep -q 'io.github.randazraik.xray' "$REPO_DIR/lib/step-plugins.sh" \
      && grep -q '_plugin_enable "crmne.hyprmoncfg"' "$REPO_DIR/lib/theme-set-hook.sh" \
      && grep -q '_plugin_enable "io.github.kristoferlund.webcam"' "$REPO_DIR/lib/theme-set-hook.sh" \
      && echo 0 || echo 1)"
  check "stale specialized bar entries are rewritten hidden" \
    "$(grep -q 'for widget_id in ids' "$REPO_DIR/lib/step-plugins.sh" \
      && grep -q 'for widget_id in ids' "$REPO_DIR/lib/theme-set-hook.sh" \
      && grep -Fq '"hidden": True' "$REPO_DIR/lib/step-plugins.sh" && echo 0 || echo 1)"
  check "the Tools menu ships the plugin rows" \
    "$([[ -f "$REPO_DIR/plugins/tools/BarWidget.qml" ]] \
      && grep -q 'io.github.randazraik.xray' "$REPO_DIR/plugins/tools/Panel.qml" \
      && ! grep -q 'omarchy-dictation' "$REPO_DIR/plugins/tools/Panel.qml" \
      && echo 0 || echo 1)"

  # The stock Bluetooth widget stays off: ssuppt.bluetooth-audio is the one
  # hidden behind the Tools menu, and a stray omarchy.bluetooth entry kept
  # reappearing in centerEnd.
  check "the stock Bluetooth widget stays off the theme bar" \
    "$(grep -q '_plugin_disable "omarchy.bluetooth"' "$REPO_DIR/lib/theme-set-hook.sh" \
      && grep -q 'plugin disable "omarchy.bluetooth"' "$REPO_DIR/lib/step-plugins.sh" \
      && grep -q '"omarchy.bluetooth"' "$REPO_DIR/lib/theme-set-hook.sh" \
      && echo 0 || echo 1)"

  # Post-4.5 audit guards: null-bar reads, binding-loop-free service fetch,
  # and the feedback-free active-window measurement.
  check "the theme widgets guard a null bar" \
    "$(python3 - "$REPO_DIR" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
pat = re.compile(r'(?<!root\.)(?<!bar \? )\bbar\.(foreground|fontFamily|urgent)\b')
bad = []
for area in ("plugins", "overrides"):
    for qml in sorted((root / area).rglob("*.qml")):
        for i, line in enumerate(qml.read_text().splitlines(), 1):
            if pat.search(line):
                bad.append(f"{qml.relative_to(root)}:{i}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
)"
  check "the indicator services are fetched outside bindings" \
    "$(for f in StayAwake NightLight Dnd RemoteSession; do \
         grep -q 'onBarChanged: refreshService()' "$REPO_DIR/plugins/indicators/indicators/$f.qml" || exit 1; \
       done; echo 0)"
  check "the active-window label is measured without feedback" \
    "$(grep -q 'TextMetrics' "$REPO_DIR/plugins/active-window/ActiveWindow.qml" \
      && grep -q 'labelMetrics.advanceWidth' "$REPO_DIR/plugins/active-window/ActiveWindow.qml" \
      && echo 0 || echo 1)"

  # The package bar facade gates the first-party service proxies on the
  # widget manifest carrying the "bar" kind, which no widget does, so the
  # toggle indicators would go dead. The bar resolves them itself.
  check "the bar hands widgets their first-party service proxies" \
    "$([[ -f "$REPO_DIR/bars/island-bar/VpPluginBarApi.qml" ]] \
      && grep -q 'function firstPartyService' "$REPO_DIR/bars/island-bar/VpPluginBarApi.qml" \
      && grep -q 'VpPluginBarApi { }' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && grep -q 'pluginFirstPartyServiceFor' "$REPO_DIR/bars/island-bar/Bar.qml" \
      && echo 0 || echo 1)"
  check "the toggle indicators use the bar accessor" \
    "$(for f in StayAwake NightLight Dnd RemoteSession; do \
         grep -q 'root.firstPartyService(' "$REPO_DIR/plugins/indicators/indicators/$f.qml" || exit 1; \
       done; echo 0)"
  check "the dictation indicator falls back to the voxtype CLI" \
    "$(grep -q 'voxtype status' "$REPO_DIR/plugins/indicators/indicators/Dictation.qml" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-29  Shared frame clock, reduced motion, weather consent, accessibility
#        and the multi-user greeter.
# ─────────────────────────────────────────────────────────────────────────────
if want tc29; then
  section "TC-29  Motion, privacy, accessibility and multi-user login"

  bar="$REPO_DIR/bars/island-bar/Bar.qml"

  # One 16 ms clock drives both gap canvases. Each used to own a timer, so the
  # event loop woke twice per frame for the same picture.
  check "the bar owns one shared frame clock" \
    "$(grep -q 'property int frameTick' "$bar" \
      && grep -q 'id: frameClock' "$bar" && echo 0 || echo 1)"
  check "the rim scanner runs on the bar clock" \
    "$(grep -q 'property int clockTick: -1' "$REPO_DIR/bars/island-bar/RimLight.qml" \
      && grep -q 'running: root.active && !root.externallyDriven' "$REPO_DIR/bars/island-bar/RimLight.qml" \
      && grep -q 'clockTick: root.frameTick' "$bar" && echo 0 || echo 1)"
  check "the gap stream runs on the bar clock" \
    "$(grep -q 'property int clockTick: -1' "$REPO_DIR/bars/island-bar/GapGlow.qml" \
      && grep -q 'running: root.active && !root.externallyDriven' "$REPO_DIR/bars/island-bar/GapGlow.qml" \
      && grep -q 'clockTick: root.frameTick' "$bar" && echo 0 || echo 1)"

  # Reduced motion is opt-in: it stops the travel but keeps every effect and
  # every colour, and it can come from shell.json or the environment.
  check "reduced motion is read from shell.json or the environment" \
    "$(grep -q 'VP_REDUCED_MOTION' "$bar" \
      && grep -q 'config.reducedMotion === true' "$bar" && echo 0 || echo 1)"
  check "reduced motion freezes the frame clock and the rim spin" \
    "$(grep -q 'running: root.islandsEnabled && root.gapEffects && !root.reducedMotion' "$bar" \
      && grep -q 'running: root.islandsEnabled && !root.reducedMotion' "$bar" \
      && grep -q 'reducedMotion: root.reducedMotion' "$bar" && echo 0 || echo 1)"
  check "reduced motion skips the hover pulse" \
    "$(grep -q 'running: root.active && !root.reducedMotion' "$REPO_DIR/bars/island-bar/HoverGlow.qml" \
      && grep -q 'enabled: !root.reducedMotion' "$REPO_DIR/bars/island-bar/HoverGlow.qml" \
      && echo 0 || echo 1)"

  weather="$REPO_DIR/plugins/weather/Panel.qml"

  # Auto-detection sends a request wttr.in turns into an approximate location.
  # It has to be opted into; a configured city or coordinates does not.
  check "weather auto-location is opt-in" \
    "$(grep -Fq 'setting("autoLocation", false)' "$weather" \
      && grep -q 'needsLocationConsent: root.locationQuery === ""' "$weather" && echo 0 || echo 1)"
  check "a refresh without consent never starts a weather request" \
    "$(python3 - "$weather" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
start = text.index("function refresh()")
guard = text.index("if (root.needsLocationConsent)", start)
fetch = text.index("forecastProc.running = true", start)
loc = text.index("locationProc.running = true", start)
sys.exit(0 if start < guard < fetch and start < guard < loc else 1)
PY
)"
  check "the weather panel offers both consent paths" \
    "$(grep -q 'USE MY LOCATION' "$weather" \
      && grep -q 'SET CITY' "$weather" \
      && grep -q 'persistSettings({ autoLocation: true })' "$weather" \
      && echo 0 || echo 1)"
  check "the weather bar shows no invented temperature" \
    "$(! grep -q '27°C' "$REPO_DIR/plugins/weather/BarWidget.qml" \
      && ! grep -q 'Local Weather' "$REPO_DIR/plugins/weather/BarWidget.qml" \
      && echo 0 || echo 1)"
  check "the weather bar widget exposes a screen-reader name" \
    "$(grep -q 'Accessible.name: "Weather"' "$REPO_DIR/plugins/weather/BarWidget.qml" && echo 0 || echo 1)"

  # Accessibility: the theme's own bar widgets and the fields a keyboard user
  # lands in carry a name and a role.
  missingAcc=""
  for _w in clock weather cputemp microphone menu tools; do
    grep -q 'Accessible.name' "$REPO_DIR/plugins/$_w/BarWidget.qml" \
      && grep -q 'Accessible.role' "$REPO_DIR/plugins/$_w/BarWidget.qml" \
      || missingAcc="$missingAcc $_w"
  done
  check "every theme bar widget exposes a name and role" \
    "$([[ -z $missingAcc ]] && echo 0 || echo 1)" "missing:$missingAcc"
  check "the clock panel labels its fields" \
    "$(grep -q 'Accessible.name: "Birth year"' "$REPO_DIR/plugins/clock/Panel.qml" \
      && grep -q 'Accessible.name: "Life expectancy"' "$REPO_DIR/plugins/clock/Panel.qml" \
      && echo 0 || echo 1)"
  check "the weather panel labels its location field" \
    "$(grep -q 'Accessible.name: "Weather location search"' "$weather" && echo 0 || echo 1)"

  # Multi-user greeter: the account chips come from SDDM's user model and a
  # switch clears the half-typed password before it can reach another account.
  sddm="$REPO_DIR/sddm/Main.qml"
  check "the greeter lists every account" \
    "$(grep -q 'Repeater {' "$sddm" \
      && grep -q 'model: userModel' "$sddm" \
      && grep -q 'userModel.rowCount() > 1' "$sddm" && echo 0 || echo 1)"
  check "switching greeter account clears the password" \
    "$(python3 - "$sddm" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
start = text.index("function pickUser")
end = text.index("\n  }", start)
body = text[start:end]
sys.exit(0 if "password.text = \"\"" in body and "root.currentUser = name" in body else 1)
PY
)"
  check "the greeter labels the password for the selected account" \
    "$(grep -q 'Accessible.name: "Password for " + root.currentUser' "$sddm" && echo 0 || echo 1)"
  check "the greeter still logs in the selected account" \
    "$(grep -q 'sddm.login(root.currentUser, password.text, root.sessionIndex)' "$sddm" && echo 0 || echo 1)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-30  Settings panel and UI sound toggle.
# ─────────────────────────────────────────────────────────────────────────────
if want tc30; then
  section "TC-30  Settings panel and UI sound"

  panel="$REPO_DIR/plugins/tools/Panel.qml"
  tools_widget="$REPO_DIR/plugins/tools/BarWidget.qml"

  check "the tools panel carries a settings view" \
    "$(grep -q 'property bool showSettings' "$panel" \
      && grep -q 'SETTINGS' "$panel" && echo 0 || echo 1)"
  check "settings replaced the appearance toggles with a live color board" \
    "$(! grep -q 'label: "Gap effects"' "$panel" \
      && ! grep -q 'label: "Hover glow"' "$panel" \
      && ! grep -q 'label: "Reduced motion"' "$panel" \
      && grep -q 'CUSTOM THEME' "$panel" \
      && grep -q 'boardColors' "$panel" \
      && grep -q 'function pickColor' "$panel" \
      && grep -q 'vp-palette.sh' "$panel" \
      && grep -q 'paletteDebounce' "$panel" \
      && grep -q 'paletteWriteDirty' "$panel" \
      && grep -q 'themeDebounce' "$panel" \
      && ! grep -q 'PanelSlider' "$panel" \
      && ! grep -q 'Apply theme' "$panel" && echo 0 || echo 1)"
  check "settings validate and clamp palette input" \
    "$(grep -q 'function loadPalette' "$panel" \
      && grep -q 'defaultRoleColors' "$panel" \
      && grep -q '/\^#\[0-9a-fA-F\]{6}\$/' "$panel" && echo 0 || echo 1)"
  check "settings expose portable saved themes" \
    "$(grep -q 'vp-theme.sh' "$panel" \
      && grep -q 'savedThemes' "$panel" \
      && grep -q 'function deleteTheme' "$panel" \
      && grep -q 'function exportTheme' "$panel" \
      && grep -q 'export-current' "$panel" \
      && grep -q 'themeActionProc' "$panel" && echo 0 || echo 1)"
  check "settings expose undo, redo, reset, contrast and fix" \
    "$(for fn in undoPalette redoPalette resetPalette contrastRatio fixContrast; do \
         grep -q "function $fn" "$panel" || exit 1; \
       done && grep -q 'paletteContrast' "$panel" && echo 0 || echo 1)"
  check "settings keep the palette editor keyboard accessible" \
    "$(grep -q 'activeFocusOnTab' "$panel" \
      && grep -q 'Ctrl+Z' "$panel" \
      && grep -q 'Keys.onPressed' "$panel" && echo 0 || echo 1)"
  check "settings defer the shell refresh while editing" \
    "$(grep -q 'VP_NO_THEME_REFRESH' "$panel" \
      && grep -q 'flushTheme(true)' "$panel" \
      && grep -q 'flushTheme(false)' "$panel" && echo 0 || echo 1)"
  check "settings generate palettes from a seed" \
    "$(grep -q 'function generateHarmony' "$panel" \
      && grep -q 'function deriveNeutrals' "$panel" \
      && grep -q 'function harmonyOffsets' "$panel" && echo 0 || echo 1)"
  check "settings preview color-vision modes" \
    "$(grep -q 'function simulateVision' "$panel" \
      && grep -q 'visionMode' "$panel" \
      && grep -q 'Deutan' "$panel" && echo 0 || echo 1)"
  check "settings show a live palette preview" \
    "$(grep -q 'text: "PREVIEW"' "$panel" \
      && grep -q 'root.roleColor("background")' "$panel" \
      && grep -q 'root.roleColor("foreground")' "$panel" && echo 0 || echo 1)"
  check "settings drive the live terminal palette" \
    "$(grep -q 'liveTerminals' "$panel" \
      && grep -q -- '--terminals' "$panel" \
      && grep -q 'liveTerminals' "$REPO_DIR/bin/vp-setting.sh" && echo 0 || echo 1)"
  check "settings expose palette wallpaper controls" \
    "$(grep -q 'vp-wallpaper-tint.sh apply' "$panel" \
      && grep -q 'vp-wallpaper-tint.sh restore' "$panel" \
      && grep -q 'Tint wallpaper' "$panel" && echo 0 || echo 1)"
  check "settings expose SDDM login artwork controls" \
    "$(grep -q 'vp-login-art.sh apply' "$panel" \
      && grep -q 'vp-login-art.sh restore' "$panel" \
      && grep -q 'Tint login art' "$panel" && echo 0 || echo 1)"
  check "settings expose Plymouth boot artwork controls" \
    "$(grep -q 'vp-plymouth-art.sh apply' "$panel" \
      && grep -q 'vp-plymouth-art.sh restore' "$panel" \
      && grep -q 'Tint boot art' "$panel" && echo 0 || echo 1)"
  check "settings derive a palette from the wallpaper" \
    "$(grep -q 'function themeFromWallpaper' "$panel" \
      && grep -q 'theme-switcher.sh wallpaper' "$panel" \
      && grep -q 'function fromWallpaper' "$REPO_DIR/plugins/tools/BarWidget.qml" \
      && echo 0 || echo 1)"
  check "settings derive a palette from an image path" \
    "$(grep -q 'function themeFromImage' "$panel" \
      && grep -q 'vp-theme-from-image.sh' "$panel" \
      && grep -q 'function fromImage' "$REPO_DIR/plugins/tools/BarWidget.qml" \
      && grep -q 'From image' "$panel" && echo 0 || echo 1)"
  check "the manual UI smoke covers the palette workflow" \
    "$(grep -q 'doe.tools setRole' "$REPO_DIR/tools/ui-smoke.sh" \
      && grep -q 'doe.tools generateTheme' "$REPO_DIR/tools/ui-smoke.sh" \
      && grep -q 'doe.tools undoTheme' "$REPO_DIR/tools/ui-smoke.sh" \
      && grep -q 'doe.tools redoTheme' "$REPO_DIR/tools/ui-smoke.sh" \
      && grep -q 'doe.tools resetTheme' "$REPO_DIR/tools/ui-smoke.sh" \
      && grep -q -- '--baseline' "$REPO_DIR/tools/ui-smoke.sh" \
      && echo 0 || echo 1)"
  check "the UI smoke has a pixel-diff helper" \
    "$(grep -q 'magick compare' "$REPO_DIR/tools/ui-diff.sh" \
      && grep -q -- '--crop' "$REPO_DIR/tools/ui-diff.sh" && echo 0 || echo 1)"
  check "settings write bar options through vp-setting" \
    "$(grep -q 'function setBarOption' "$panel" \
      && grep -q 'vp-setting.sh set bar' "$panel" && echo 0 || echo 1)"
  check "settings own weather auto-location" \
    "$(grep -q 'function setWeatherAuto' "$panel" \
      && grep -q 'weather.autoLocation' "$panel" && echo 0 || echo 1)"
  check "settings offer diagnose, verify, repair and logs" \
    "$(for action in diagnose verifyPins repairBar openLogs; do \
         grep -q "function $action" "$panel" || exit 1; \
       done; echo 0)"
  check "the tools widget exposes the settings IPC" \
    "$(grep -q 'function settings(): void' "$tools_widget" && echo 0 || echo 1)"
  check "variant switches use the single-flight restart" \
    "$(grep -q 'vp-restart-shell.sh' "$panel" \
      && grep -q 'variantSwitching' "$panel" && echo 0 || echo 1)"

  root="$(new_sandbox tc30)"
  state="$root/home/.local/state/virtual-paradise"
  HOME="$root/home" bash "$REPO_DIR/bin/vp-sound.sh" toggle
  check "vp-sound toggle mutes the UI" \
    "$([[ -f "$state/sound-off" ]] && echo 0 || echo 1)"
  HOME="$root/home" bash "$REPO_DIR/bin/vp-sound.sh" toggle
  check "vp-sound toggle unmutes the UI" \
    "$([[ ! -f "$state/sound-off" ]] && echo 0 || echo 1)"

  # vp-setting is the write path behind the toggles. It has to preserve the
  # layout, update only the requested key, and never leave a temp file.
  setting_root="$root/settings"
  build_shims "$root/bin"
  mkdir -p "$setting_root/.config/omarchy" "$setting_root/.local/state"
  cat >"$setting_root/.config/omarchy/shell.json" <<'EOF'
{
  "bar": {
    "layout": {
      "left": [],
      "center": [{"id": "doe.weather", "unit": "metric"}],
      "right": []
    }
  }
}
EOF
  set_env=(HOME="$setting_root" XDG_CONFIG_HOME="$setting_root/.config"
    XDG_STATE_HOME="$setting_root/.local/state" PATH="$root/bin:$PATH"
    SHIM_LOG="$root/shim.log")
  out=$(env "${set_env[@]}" bash "$REPO_DIR/bin/vp-setting.sh" set bar.gapEffects false 2>&1)
  check "vp-setting sets a bar boolean" "$?" "$out"
  got=$(env "${set_env[@]}" bash "$REPO_DIR/bin/vp-setting.sh" get bar.gapEffects 2>&1)
  check "vp-setting reads the value back" \
    "$([[ "$got" == false ]] && echo 0 || echo 1)" "$got"
  out=$(env "${set_env[@]}" bash "$REPO_DIR/bin/vp-setting.sh" set weather.autoLocation true 2>&1)
  check "vp-setting updates the weather entry" "$?" "$out"
  python3 - "$setting_root/.config/omarchy/shell.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
w = next(e for e in d["bar"]["layout"]["center"] if e["id"].endswith(".weather"))
raise SystemExit(0 if d["bar"].get("gapEffects") is False and w.get("autoLocation") is True else 1)
PY
  check "vp-setting keeps the layout and both values" $?
  env "${set_env[@]}" bash "$REPO_DIR/bin/vp-setting.sh" set bar.nope true >/dev/null 2>&1
  check "vp-setting rejects an unknown key" \
    "$([[ $? -ne 0 ]] && echo 0 || echo 1)"
  check "vp-setting leaves no temp files" \
    "$([[ -z "$(find "$setting_root/.config/omarchy" -name '.shell.json.*' -print -quit)" ]] && echo 0 || echo 1)"
  check "vp-setting asks the shell to reload" \
    "$(grep -q 'omarchy-shell shell reloadConfig' "$root/shim.log" && echo 0 || echo 1)"

  # Two fast variant clicks used to spawn two supervisors and two bars. The
  # restart wrapper must serialise; the slow shim keeps the first lock held
  # while the second caller starts.
  restart_root="$root/restart"
  mkdir -p "$restart_root/bin" "$restart_root/run"
  cat >"$restart_root/bin/omarchy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SHIM_LOG"
sleep 1
EOF
  chmod +x "$restart_root/bin/omarchy"
  (
    SHIM_LOG="$restart_root/restart.log" XDG_RUNTIME_DIR="$restart_root/run" \
      PATH="$restart_root/bin:$PATH" bash "$REPO_DIR/bin/vp-restart-shell.sh" >/dev/null 2>&1 &
    SHIM_LOG="$restart_root/restart.log" XDG_RUNTIME_DIR="$restart_root/run" \
      PATH="$restart_root/bin:$PATH" bash "$REPO_DIR/bin/vp-restart-shell.sh" >/dev/null 2>&1 &
    wait
  )
  calls=$(grep -c 'restart shell' "$restart_root/restart.log" 2>/dev/null || echo 0)
  check "concurrent restarts collapse to one" \
    "$([[ "$calls" == 1 ]] && echo 0 || echo 1)" "calls=$calls"
fi

summary
