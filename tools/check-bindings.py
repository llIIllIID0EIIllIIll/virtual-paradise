#!/usr/bin/env python3
"""Check hypr/bindings.lua for chords that Hyprland would run twice.

Hyprland does not replace a binding when the same chord is bound again: every
matching bind runs. That is why SUPER + RETURN launched two terminals (Omarchy's
default plus this theme's copy). This script fails on:

  1. the same chord bound twice in our own file (per submap), and
  2. a chord we bind that Omarchy already binds, unless we hl.unbind() it first.

Upstream defaults are read from the installed Omarchy tree when available and
from tests/fixtures/omarchy-binds.txt otherwise (CI containers do not ship
Omarchy). Run with --write-fixture to refresh the fixture from an installed
Omarchy after a package update.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = Path(os.environ.get("VP_BINDINGS_FILE", REPO / "hypr" / "bindings.lua"))
DEFAULTS_DIR = Path(
    os.environ.get("OMARCHY_BINDINGS_DIR", "/usr/share/omarchy/default/hypr/bindings")
)
FIXTURE = REPO / "tests" / "fixtures" / "omarchy-binds.txt"

BIND_RE = re.compile(r'o\.bind(?:_toggle)?\(\s*"([^"]+)"')
UNBIND_RE = re.compile(r'hl\.unbind\(\s*"([^"]+)"')
SUBMAP_RE = re.compile(r'hl\.define_submap\(\s*"([^"]+)"')

# Chords that Hyprland treats as the same key even though the names differ.
ALIASES = {
    "ENTER": "RETURN",
    "ESC": "ESCAPE",
    "MINUS": "CODE:20",
    "EQUAL": "CODE:21",
}


def norm(chord: str) -> str:
    """Case-fold, alias and order the parts so equivalence is textual."""
    parts = [ALIASES.get(p.strip().upper(), p.strip().upper()) for p in chord.split("+")]
    return " + ".join(sorted(parts))


def read_ours() -> tuple[list[str], dict[str, list[str]], set[str]]:
    text = OURS.read_text()
    global_binds: list[str] = []
    submap_binds: dict[str, list[str]] = {}
    current: str | None = None

    for line in text.splitlines():
        submap = SUBMAP_RE.search(line)
        if submap:
            current = submap.group(1)
            submap_binds.setdefault(current, [])
            continue
        # Every submap in this file ends with a single `end)` line.
        if current is not None and line.strip() == "end)":
            current = None
            continue
        for match in BIND_RE.finditer(line):
            target = global_binds if current is None else submap_binds[current]
            target.append(norm(match.group(1)))

    unbound = {norm(m.group(1)) for m in UNBIND_RE.finditer(text)}
    return global_binds, submap_binds, unbound


def read_upstream() -> tuple[set[str], str]:
    files = sorted(DEFAULTS_DIR.glob("*.lua")) if DEFAULTS_DIR.is_dir() else []
    if files:
        keys: list[str] = []
        for path in files:
            keys.extend(BIND_RE.findall(path.read_text()))
        return {norm(k) for k in keys}, "installed Omarchy defaults"

    keys = [
        line.strip()
        for line in FIXTURE.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    return {norm(k) for k in keys}, f"fixture {FIXTURE.relative_to(REPO)}"


def write_fixture() -> int:
    files = sorted(DEFAULTS_DIR.glob("*.lua"))
    if not files:
        print(f"error: {DEFAULTS_DIR} not found; nothing to snapshot", file=sys.stderr)
        return 1

    raw: list[str] = []
    for path in files:
        raw.extend(BIND_RE.findall(path.read_text()))

    seen: set[str] = set()
    unique: list[str] = []
    for key in raw:
        normalized = norm(key)
        if normalized in seen:
            continue
        seen.add(normalized)
        unique.append(" + ".join(part.strip() for part in key.split("+")))

    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE.write_text(
        "# Omarchy default keybindings (literal o.bind / o.bind_toggle keys).\n"
        "# Used only when the Omarchy tree is not installed, e.g. in CI.\n"
        "# Refresh after an Omarchy update: tools/check-bindings.py --write-fixture\n"
        + "\n".join(sorted(unique, key=norm))
        + "\n"
    )
    print(f"wrote {len(unique)} bindings to {FIXTURE.relative_to(REPO)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write-fixture",
        action="store_true",
        help="regenerate tests/fixtures/omarchy-binds.txt from the installed Omarchy tree",
    )
    args = parser.parse_args()

    if args.write_fixture:
        return write_fixture()

    global_binds, submap_binds, unbound = read_ours()
    upstream, source = read_upstream()
    problems: list[str] = []

    def report_duplicates(scope: str, chords: list[str]) -> None:
        seen: set[str] = set()
        for chord in chords:
            if chord in seen:
                problems.append(f"{scope}: {chord} is bound twice")
            seen.add(chord)

    report_duplicates("global", global_binds)
    for submap, chords in submap_binds.items():
        report_duplicates(f"submap {submap}", chords)

    for chord in sorted(set(global_binds)):
        if chord in upstream and chord not in unbound:
            problems.append(
                f"global: {chord} is already bound by Omarchy; use a free chord "
                'or add hl.unbind("...") first'
            )

    if problems:
        print(f"keybinding conflicts ({source}):", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    print(f"keybindings OK ({len(global_binds)} global, {len(submap_binds)} submaps, against {source})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
