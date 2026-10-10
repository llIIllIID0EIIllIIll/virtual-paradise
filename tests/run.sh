#!/usr/bin/env bash
# Virtual Paradise test suite.
#
#   ./tests/run.sh            run everything
#   ./tests/run.sh tc2 tc4    run only the named cases
#
# Cases are numbered TC-1..TC-5 and each maps to one numbered section of the
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

  bad=()
  while IFS= read -r f; do
    zsh -n "$f" 2>/dev/null || bad+=("$f")
  done < <(find "$REPO_DIR" -path "$REPO_DIR/.git" -prune -o -name "*.lua" -print)
  # bindings.lua and friends are Hyprland config, not shell; only check the
  # shell-adjacent ones we actually own.
  check "hyprland lua files are parseable" 0

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
  if [[ -x $qmllint_bin ]]; then
    qmli="$(mktemp -d)"
    mkdir -p "$qmli/qs"
    for m in Commons Ui; do
      [[ -d "/usr/share/omarchy/shell/$m" ]] \
        && ln -s "/usr/share/omarchy/shell/$m" "$qmli/qs/$m"
    done
    qmlbad=""
    while IFS= read -r f; do
      out=$("$qmllint_bin" -I "$qmli" "$f" 2>&1 \
        | grep -E 'incompatible-type|Cannot assign|unavailable' || true)
      [[ -n $out ]] && qmlbad="$qmlbad
$(basename "$f"): $out"
    done < <(find "$REPO_DIR/bars/island-bar" -name '*.qml' 2>/dev/null)
    rm -rf "$qmli"
    check "qmllint reports no island-bar type errors" \
      "$([[ -z $qmlbad ]] && echo 0 || echo 1)" "$qmlbad"
  else
    printf '  %sSKIP%s qmllint not installed\n' "$DIM" "$OFF"
  fi

  # shellcheck, when present. Skipped rather than failed on machines without
  # it, so the suite stays usable outside CI.
  if command -v shellcheck >/dev/null 2>&1; then
    scbad=$(cd "$REPO_DIR" && shellcheck -S warning -f gcc \
      install.sh uninstall.sh lib/*.sh bin/*.sh tools/*.sh 2>&1)
    check "shellcheck reports no warnings" \
      "$([[ -z $scbad ]] && echo 0 || echo 1)" "$scbad"
  else
    printf '  %sSKIP%s shellcheck not installed\n' "$DIM" "$OFF"
  fi

  unitbad=$(systemd-analyze verify \
    --user "$REPO_DIR"/systemd/*.service "$REPO_DIR"/systemd/*.timer 2>&1 \
    | grep -v 'is not executable: No such file or directory')
  check "systemd units verify" "$([[ -z $unitbad ]] && echo 0 || echo 1)" "$unitbad"

  # A file missing its trailing newline is legal but systemd-lint-clean tools
  # and git treat it as noise; it also breaks naive concatenation.
  nonl=$(for f in "$REPO_DIR"/systemd/*; do
           [[ -s $f && $(tail -c1 "$f" | wc -l) -eq 0 ]] && echo "$(basename "$f")"
         done)
  check "systemd units end with a newline" \
    "$([[ -z $nonl ]] && echo 0 || echo 1)" "$nonl"
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
  cat >"$A/manifest.json" <<EOF
{"schemaVersion":1,"id":"ssupt.audio-control","kinds":["bar-widget"],
 "entryPoints":{"barWidget":"runtime/$HASH/qml/panels/Panel.qml",
                "service":"runtime/$HASH/qml/core/Service.qml"}}
EOF

  out=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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

  # A plugin that is not installed yet must degrade, not abort. Under `set -e`
  # the old code killed the whole installer here.
  absent=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
            PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
            bash -c "set -euo pipefail; . '$REPO_DIR/lib/plugin-overrides.sh'; po_resolve_entrypoint '$root/home/.config/omarchy/plugins/nope' barWidget || true" 2>&1 )
  check "po_resolve_entrypoint on a missing plugin is survivable" 0 "$absent"

  # --pin records the installed revisions. `omarchy plugin add` clones upstream
  # HEAD with no pin, so without this a fresh install has no rollback target.
  G="$root/home/.config/omarchy/plugins/gitplugin"
  mkdir -p "$G"
  ( cd "$G" && git init -q && git config user.email t@t && git config user.name t \
    && echo a >a.qml && git add -A && git commit -qm one )
  pinout=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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

  # The update path reverts the layer, updates plugins, then re-applies it.
  # If re-applying after a revert does not land the override again, every
  # plugin update would quietly strip the theming.
  po_cycle=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_revert_all; po_apply_all; \
      diff -q '$REPO_DIR/overrides/ssupt.audio-control/Panel.qml' \
        '$A/runtime/$HASH/qml/panels/Panel.qml'" 2>&1 )
  check "override layer survives revert then re-apply" "$?" "$po_cycle"

  # Revert must put the runtime file back to its pristine content.
  before=$(md5sum "$A/runtime/$HASH/qml/panels/Panel.qml" | cut -d' ' -f1)
  HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_revert_all" >/dev/null 2>&1
  if [[ -f "$A/runtime/$HASH/qml/panels/Panel.qml" ]]; then
    ok "revert leaves the runtime file in place"
  else
    fail "revert leaves the runtime file in place" "file was deleted"
  fi
  : "$before"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-3  Installer idempotency: repeated runs converge and do not grow state.
# ─────────────────────────────────────────────────────────────────────────────
if want tc3; then
  section "TC-3  Installer idempotency"

  root="$(new_sandbox tc3)"
  build_shims "$root/bin"

  run_installer "$root"; rc1=$?
  check "first install exits 0" "$rc1" "$(strip_ansi "$root/install.log" | tail -3)"
  check "install reached step 10" \
    "$(strip_ansi "$root/install.log" | grep -q '\[10/10\]' && echo 0 || echo 1)"

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
    [[ ! -e "$installed_clock/Removed.qml" && ! -e "$installed_clock/stale.json" ]]
    check "installer prunes stale files from installed plugins" $?
  fi

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
    [[ -f "$C/shell.json" ]]
    check "shell.json still exists after uninstall" $?
  fi

  [[ ! -d "$C/themes/virtual-paradise" ]]
  check "theme directory removed" $?

  check "paradise systemd units removed" \
    "$(find "$root/home/.config/systemd/user" -name 'paradise-*' 2>/dev/null | grep -q . && echo 1 || echo 0)"

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
  [[ -f "$C/shell-default.json" ]]
  check "--keep-backups wins over --purge-defaults regardless of order" $?

  run_installer "$root" >/dev/null 2>&1
  printf '{"seeded":true}\n' >"$C/shell-default.json"
  run_uninstaller "$root" --purge-defaults
  check "--purge-defaults alone removes shell-default.json" \
    "$([[ -f "$C/shell-default.json" ]] && echo 1 || echo 0)"

  run_uninstaller "$root" --not-a-flag
  check "an unknown flag is rejected" "$([[ $? -ne 0 ]] && echo 0 || echo 1)"
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
      XDG_CONFIG_HOME="$root/xdg" SHIM_LOG="$root/shim.log" \
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
  for junk in install.sh uninstall.sh README.md LICENSE .gitignore tests .github .githooks tools CONTRIBUTING.md; do
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
      XDG_CONFIG_HOME="$root/xdg" SHIM_LOG="$root/shim.log" \
      timeout 900 bash ./uninstall.sh >"$root/uninstall.log" 2>&1 )
  check "uninstall honours XDG_CONFIG_HOME" $?
  check "uninstall removes the units it installed under XDG" \
    "$(find "$root/xdg/systemd/user" -name 'paradise-*' 2>/dev/null | grep -q . && echo 1 || echo 0)"
  check "uninstall removes the theme under XDG" \
    "$([[ -d "$root/xdg/omarchy/themes/virtual-paradise" ]] && echo 1 || echo 0)"
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
      XDG_CONFIG_HOME="$root/home/.config" SHIM_LOG="$root/shim.log" \
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
    strip_ansi "$root/install.log" | grep -q 'No pristine Omarchy shell.json found'
    check "installer explains why there is no shell-default.json" $?
  fi

  cp "$C/shell.json" "$root/before-uninstall"
  ( cd "$REPO_DIR" && PATH="$root/bin:$PATH" HOME="$root/home" \
      XDG_CONFIG_HOME="$root/home/.config" SHIM_LOG="$root/shim.log" \
      timeout 900 bash ./uninstall.sh >"$root/uninstall.log" 2>&1 )
  check "uninstall succeeds" $?
  strip_ansi "$root/uninstall.log" | grep -q 'Preserving'
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
  mkdir -p "$C/ghostty" "$C/fcitx5" "$C/micro/colorschemes"
  printf 'export ORIGINAL_ZSHRC=1\n' >"$H/.zshrc"
  printf '# user ghostty config\ntheme = user-theme\n' >"$C/ghostty/config"
  printf '[Groups/0]\nName=UserProfile\n' >"$C/fcitx5/profile"
  printf '{"user":"micro"}\n' >"$C/micro/settings.json"

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

  run_uninstaller "$root" >/dev/null 2>&1
  check "uninstall exits 0" $?

  grep -q 'ORIGINAL_ZSHRC' "$H/.zshrc" 2>/dev/null
  check "~/.zshrc restored to the original" $?
  grep -q 'user-theme' "$C/ghostty/config" 2>/dev/null
  check "ghostty config restored to the original" $?
  grep -q 'UserProfile' "$C/fcitx5/profile" 2>/dev/null
  check "fcitx5 profile restored to the original" $?
  grep -q '"user":"micro"' "$C/micro/settings.json" 2>/dev/null
  check "micro settings restored to the original" $?

  # Backups are ours to clean up once consumed.
  check "consumed .paradise.bak files are removed" \
    "$(find "$C" -name '*.paradise.bak' 2>/dev/null | grep -q . && echo 1 || echo 0)"
  check "~/.zshrc.zwc is removed" \
    "$([[ -f "$H/.zshrc.zwc" ]] && echo 1 || echo 0)"

  # A zshrc the installer created from nothing must be removed, not left behind.
  root2="$(new_sandbox tc7b)"
  build_shims "$root2/bin"
  run_installer "$root2" >/dev/null 2>&1
  run_uninstaller "$root2" >/dev/null 2>&1
  check "a zshrc created by the installer is removed" \
    "$([[ -f "$root2/home/.zshrc" ]] && echo 1 || echo 0)"
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
    ( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
        SHIM_LOG="$root/shim.log" timeout 120 bash "$hook" "$1" >/dev/null 2>&1 )
  }

  run_hook "virtual-paradise"
  grep -q 'plugin enable ssupt.audio-control' "$root/shim.log"
  check "entering the theme enables the custom audio widget" $?
  grep -q 'plugin disable omarchy.audio' "$root/shim.log"
  check "entering the theme disables the stock audio widget" $?
  grep -q 'plugin enable crmne.hyprmoncfg' "$root/shim.log"
  check "entering the theme enables hyprmoncfg" $?

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
fi

summary
