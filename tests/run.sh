#!/usr/bin/env bash
# Virtual Paradise test suite.
#
#   ./tests/run.sh            run everything
#   ./tests/run.sh tc2 tc4    run only the named cases
#
# Cases are numbered TC-1..TC-12 and each maps to one numbered section of the
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

  # The live wallpaper used to be on SUPER + ALT + arrows, then disappeared
  # because Omarchy binds the same chords. The pair has to be there, and it
  # has to be taken over on purpose.
  check "the live wallpaper is bound to the arrow keys" \
    "$(grep -q 'o.bind("SUPER + ALT + RIGHT", "Next Live Wallpaper"' "$REPO_DIR/hypr/bindings.lua" \
      && grep -q 'o.bind("SUPER + ALT + LEFT", "Previous Live Wallpaper"' "$REPO_DIR/hypr/bindings.lua" \
      && echo 0 || echo 1)"
  check "Omarchy's group bind on that chord is unbound first" \
    "$(grep -q 'hl.unbind("SUPER + ALT + LEFT")' "$REPO_DIR/hypr/bindings.lua" \
      && grep -q 'hl.unbind("SUPER + ALT + RIGHT")' "$REPO_DIR/hypr/bindings.lua" \
      && echo 0 || echo 1)"
  check "the group move survives on a free chord" \
    "$(grep -q 'o.bind("SUPER + ALT + CTRL + LEFT"' "$REPO_DIR/hypr/bindings.lua" && echo 0 || echo 1)"
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

  out=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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
  absent=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
            PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
            bash -c "set -euo pipefail; . '$REPO_DIR/lib/plugin-overrides.sh'; po_resolve_entrypoint '$root/home/.config/omarchy/plugins/nope' barWidget || true" 2>&1 )
  check "po_resolve_entrypoint on a missing plugin is survivable" 0 "$absent"

  # --pin records the installed revisions. `omarchy plugin add` clones upstream
  # HEAD with no pin, so without this a fresh install has no rollback target.
  G="$root/home/.config/omarchy/plugins/gitplugin"
  mkdir -p "$G"
  ( cd "$G" && git init -q && git config user.email t@t && git config user.name t \
    && echo a >a.qml && git add -A && git commit -qm one )
  pinout=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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
  po_cycle=$( PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
    PARADISE_REPO_DIR="$REPO_DIR" PARADISE_CONFIG_DIR="$root/home/.config" \
    bash -c ". '$REPO_DIR/lib/plugin-overrides.sh'; po_revert_all; po_apply_all; \
      diff -q '$REPO_DIR/overrides/ssupt.audio-control/Panel.qml' \
        '$A/runtime/$HASH/qml/panels/Panel.qml'" 2>&1 )
  check "override layer survives revert then re-apply" "$?" "$po_cycle"

  # Revert must put the runtime file back to its pristine content.
  before=$(md5sum "$A/runtime/$HASH/qml/panels/Panel.qml" | cut -d' ' -f1)
  PATH="$root/bin:$PATH" HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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
  check "--keep-backups wins over --purge-defaults regardless of order" \
    "$([[ -f "$C/shell-default.json" ]] && echo 0 || echo 1)"

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
  mkdir -p "$C/ghostty" "$C/fcitx5" "$C/micro/colorschemes" "$C/hypr"
  printf 'export ORIGINAL_ZSHRC=1\n' >"$H/.zshrc"
  printf '# user ghostty config\ntheme = user-theme\n' >"$C/ghostty/config"
  printf '[Groups/0]\nName=UserProfile\n' >"$C/fcitx5/profile"
  printf '{"user":"micro"}\n' >"$C/micro/settings.json"
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
  grep -q 'user look and feel' "$C/hypr/looknfeel.lua" 2>/dev/null
  check "hypr looknfeel restored to the original" $?
  grep -q -- '-- user bindings' "$C/hypr/bindings.lua" 2>/dev/null
  check "hypr bindings restored to the original after a re-install" $?
  grep -q -- '-- user input tuning' "$C/hypr/input.lua" 2>/dev/null
  check "hypr input restored to the original after a re-install" $?
  check "the wallpaper hook is gone from the user's autostart" \
    "$(grep -q -- '-- user autostart' "$C/hypr/autostart.lua" 2>/dev/null \
       && ! grep -q 'toggle_live_wallpaper' "$C/hypr/autostart.lua" && echo 0 || echo 1)"
  check "the window-rule block is removed" \
    "$(grep -q 'Virtual Paradise Add-on Window Rules' "$C/hypr/hyprland.lua" && echo 1 || echo 0)"
  check "the user's own hyprland line survives" \
    "$(grep -q 'my own GNOME Network Displays note' "$C/hypr/hyprland.lua" && echo 0 || echo 1)"
  check "the hypr snapshot state file is removed" \
    "$([[ ! -f "$H/.local/state/virtual-paradise/hypr-backup-dir" ]] && echo 0 || echo 1)"

  # Backups are ours to clean up once consumed.
  check "consumed .paradise.bak files are removed" \
    "$(find "$C" -name '*.paradise.bak' 2>/dev/null | grep -q . && echo 1 || echo 0)"
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

  out=$( HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" \
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
    "$(grep -q 'limine-mkinitcpio' "$REPO_DIR/install.sh" && grep -q 'mkinitcpio -P' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the installer checks the boot image was really rebuilt" \
    "$(grep -q 'boot_image_age' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the installer shows the rebuild output" \
    "$(grep -qE 'run_privileged (limine-mkinitcpio|mkinitcpio -P)[;"]' "$REPO_DIR/install.sh" && echo 0 || echo 1)"

  # The greeter is on screen for less than a second while Omarchy logs in
  # automatically, so the login screen needs a way to be shown.
  check "the installer can turn the autologin off" \
    "$(grep -q 'disable_autologin' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
  check "the uninstaller restores the autologin" \
    "$(grep -q 'autologin.conf.paradise.bak' "$REPO_DIR/uninstall.sh" && echo 0 || echo 1)"

  # The Plymouth prompt must not cover the neon frame.
  check "the Plymouth password row sits below the picture" \
    "$(grep -q 'entry.y = global.top + global.frame_height' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"
  check "the Plymouth splash fades in" \
    "$(grep -q 'global.fade_frame' "$REPO_DIR/plymouth/virtual-paradise.script" && echo 0 || echo 1)"

  # The transition has to be seen, and it has to be usable for the way out.
  check "the wallpaper transition stays visible for a moment" \
    "$(grep -q 'minimumVisible' "$REPO_DIR/bin/glitch_transition.qml" && echo 0 || echo 1)"
  check "there is a transition for logout, reboot and shutdown" \
    "$([[ -f $REPO_DIR/bin/transition.sh ]] && grep -q 'omarchy-system-shutdown' "$REPO_DIR/bin/transition.sh" && echo 0 || echo 1)"
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
    "$(grep -q 'lib/sddm.sh' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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
         XDG_CONFIG_HOME="$root/home-sddm/.config" SHIM_LOG="$root/shim-sddm.log" \
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
    "$(grep -q 'lib/plymouth.sh' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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

  run_switcher cozy
  check "the theme switcher exits 0" $? "$(tail -3 "$root/switch.log")"
  check "colors.toml got the variant accent" \
    "$(grep -q '^accent = "#ffa69e"' "$theme/colors.toml" && echo 0 || echo 1)"
  check "the terminal config got the same accent" \
    "$(grep -q '^palette = 4=#ffa69e' "$theme/ghostty.conf" && echo 0 || echo 1)"
  check "the GTK stylesheet got the same accent" \
    "$(grep -q '@define-color blue #ffa69e' "$theme/config/gtk.css" && echo 0 || echo 1)"
  check "the cursor followed the accent" \
    "$(grep -q '^cursor = "#ffa69e"' "$theme/colors.toml" && echo 0 || echo 1)"

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
# Two things the theme must not do:
#   - pin a font size. Ghostty applies a config-file include after the file
#     that pulls it in, so a size in the theme's ghostty.conf beats the
#     user's own config: a fresh install turned 9pt text into 12pt text.
#   - own the display layout. hyprmoncfg applies a profile per monitor setup
#     and switches between them on hotplug; static rules for eDP-1/HDMI-A-1/
#     DP-1/DP-2 with a fixed scale of 1.0 kept the laptop panel alive and
#     made every HiDPI display render at 1x.
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

  # 3. Functional: a machine that ran the old installer has the static
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
    "$(grep -q 'OMARCHY_PATH="\$OMARCHY_PATH"' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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
       XDG_CONFIG_HOME="$root/home/.config" SHIM_LOG="$root/shim.log" \
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
    "$(grep -q 'replace_file_preserving' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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
    "$(grep -q 'rm -f "\$WALLPAPER_DEST"/\*.gif' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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

  # The live wallpaper is drawn on the same layer as the static background and
  # a layer created later ends up on top: started too early, the video ended
  # up under the static picture and the login screen showed the static
  # wallpaper with the shell's diamond transition instead.
  check "the live wallpaper waits for the shell's background layer" \
    "$(grep -q 'wait_for_shell_background' "$REPO_DIR/bin/toggle_live_wallpaper.sh" && echo 0 || echo 1)"

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
  check "the session splash is started from the Hyprland autostart" \
    "$(grep -q 'session_splash.sh' "$REPO_DIR/hypr/autostart.lua" && echo 0 || echo 1)"
  check "the installer hooks the session splash" \
    "$(grep -q 'session_splash.sh' "$REPO_DIR/install.sh" && echo 0 || echo 1)"
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

summary
