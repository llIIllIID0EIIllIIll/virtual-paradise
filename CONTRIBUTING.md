# Contributing

## Getting the test suite green first

```bash
git config core.hooksPath .githooks   # enables the commit-msg hook, once per clone
./tests/run.sh                        # ~3 minutes, touches nothing outside a temp HOME
```

The suite runs the installer and uninstaller against a throwaway `HOME` with a
`PATH` shim directory, so it never writes to your real config, `/usr/share`,
`systemctl` or `pacman`. If it fails, the failure names the case; run just that
one while iterating:

```bash
./tests/run.sh tc4 tc7
```

`shellcheck` is part of TC-1 when installed. CI installs it, so run it locally
too if you can:

```bash
shellcheck -S warning install.sh uninstall.sh lib/*.sh bin/*.sh tools/*.sh
```

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), enforced by
`.githooks/commit-msg`:

```
<type>[(scope)]: <summary>
```

| Type | For |
| :--- | :--- |
| `feat` | new behaviour |
| `fix` | a bug fix |
| `docs` | README and comments only |
| `test` | test suite only |
| `refactor` | no behaviour change |
| `chore` | tooling, dependencies |
| `perf`, `style`, `build`, `ci`, `revert` | the obvious |

Write the body as *why*, not what — the diff already says what. If a change
fixes something subtle, say what broke and what it looked like, because that is
what the next person searches for.

## Keeping the forks in sync

Eight plugins under `plugins/` are forks of Omarchy's first-party plugins; the
manifest records the source as `omarchy.clonedFrom`. An upstream fix does not
reach a fork on its own — the background fork ran for months without the
black-desktop workaround and the `Style` refresh — so the repo records a hash
of every upstream file at the last review:

```bash
tools/check-upstream-drift.py            # report what changed upstream
tools/check-upstream-drift.py --update   # re-record after rebasing a fork
```

Run the report after an Omarchy update, port what matters into the fork, then
record. TC-28 keeps the baseline honest: it fails when a fork has no recorded
entry and when the tool misses a change.

## Adding an override

`overrides/<plugin-id>/` carries our QML over a third-party widget. Two rules:

1. **Resolve entry points from the plugin's `manifest.json`.** Some plugins ship
   their QML inside a versioned `runtime/<hash>/` tree; a file copied to the
   plugin root loads nothing and fails silently. Register the override in
   `lib/plugin-overrides.sh` rather than hardcoding a path.
2. **Say why in a comment.** An override is a maintenance debt against an
   upstream that will move. `paradise-plugin-update --check` warns when upstream
   touches a file we patch, so the reason needs to be written down.

## Two traps this codebase has hit more than once

Worth knowing before you add shell here, because the test suite has caught
both:

- **`set -e -o pipefail` plus a glob that matches nothing aborts the script.**
  A command substitution like `x="$(ls dir/*.bak | head -1)"` returns non-zero
  when the glob is empty. Guard it (`|| true`) or use `shopt -s nullglob` in a
  subshell.
- **Backing up a file that is already ours.** Restore-on-uninstall derives the
  original from a `.bak` sibling. If a second run takes that backup after the
  first run already overwrote the file, the "original" is our own output and
  uninstall restores the rice. Only back up when the file is genuinely the
  user's — see the fcitx5 and `shell-default.json` cases.

### Manual UI smoke

With a live Omarchy session, drive the settings panel end to end:

```bash
./tools/ui-smoke.sh --screenshots /tmp/vp-ui
```

It opens Settings, sets an accent, generates a triad, checks undo/redo/reset
through `palette.json`, captures optional screenshots, and restores the palette
and variant on exit. It is intentionally not part of CI.

Compare a run against a saved baseline (crop out the live bar clock):

```bash
./tools/ui-diff.sh /tmp/vp-ui-baseline /tmp/vp-ui \
  --crop 620x900+1300+0 --threshold 50
```
