#!/usr/bin/env python3
"""Report Omarchy first-party plugins whose upstream moved under our forks.

Nine plugins under `plugins/` are forks of `omarchy.*` plugins (the manifest
records `omarchy.clonedFrom`). Upstream fixes do not reach a fork on their own:
the background fork was missing the black-desktop workaround and the Style
refresh for months, and nothing said so.

This tool records a hash of every upstream file at the last review
(`tests/fixtures/upstream-hashes.json`) and reports what changed since. Run it
after an Omarchy update, rebase the fork where the change matters, then record
the review:

    tools/check-upstream-drift.py            # report drift (exit 1 if any)
    tools/check-upstream-drift.py --update   # re-record after reviewing

Upstream files are read from the installed Omarchy tree. When that tree is not
installed (CI containers), the tool says so and exits 0.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PLUGINS = Path(os.environ.get("VP_PLUGINS_DIR", REPO / "plugins"))
STOCK = Path(
    os.environ.get("OMARCHY_PLUGINS_DIR", "/usr/share/omarchy/shell/plugins")
)
FIXTURE = Path(
    os.environ.get("VP_UPSTREAM_HASHES", REPO / "tests" / "fixtures" / "upstream-hashes.json")
)

SKIP_DIRS = {"__pycache__"}


def forks() -> dict[str, str]:
    """Fork plugin dir name -> stock plugin dir name, from `clonedFrom`."""
    found: dict[str, str] = {}
    for manifest in sorted(PLUGINS.glob("*/manifest.json")):
        try:
            data = json.loads(manifest.read_text())
        except ValueError:
            continue
        cloned = (data.get("omarchy") or {}).get("clonedFrom")
        if not cloned:
            continue
        found[manifest.parent.name] = str(cloned).split(".")[-1]
    return found


def hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def upstream_files(stock_name: str) -> dict[str, str]:
    """Every upstream file that looks like it belongs to `stock_name`.

    Omarchy spreads one plugin across the tree - the clock lives in
    `plugins/panels/clock/`, `plugins/bar/widgets/Clock.qml` and its manifest -
    so the match is by base name (case-folded, extension dropped) anywhere
    under the stock root, plus everything inside a directory of that name.
    """
    wanted = re.sub(r"[^a-z0-9]", "", stock_name.lower())
    out: dict[str, str] = {}

    def normalized(text: str) -> str:
        return re.sub(r"[^a-z0-9]", "", text.lower())

    def keep(path: Path) -> bool:
        return path.is_file() and not any(p in SKIP_DIRS for p in path.parts)

    for path in sorted(STOCK.rglob("*")):
        if keep(path):
            stem = path.name.split(".")[0]
            if normalized(stem) == wanted or normalized(stem).startswith(wanted):
                out[str(path.relative_to(STOCK))] = hash_file(path)
        elif path.is_dir() and normalized(path.name) == wanted:
            for nested in sorted(path.rglob("*")):
                if keep(nested):
                    out[str(nested.relative_to(STOCK))] = hash_file(nested)
    return out


def load_recorded() -> dict:
    if not FIXTURE.is_file():
        return {}
    try:
        return json.loads(FIXTURE.read_text())
    except ValueError:
        return {}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update",
        action="store_true",
        help="re-record the upstream hashes after reviewing the drift",
    )
    args = parser.parse_args()

    if not STOCK.is_dir():
        print(f"upstream not installed at {STOCK}; nothing to compare")
        return 0

    current: dict[str, dict[str, str]] = {}
    missing: list[str] = []
    for fork, stock_name in forks().items():
        files = upstream_files(stock_name)
        if not files:
            missing.append(f"{fork} (no upstream files named {stock_name} anymore)")
            continue
        current[stock_name] = files

    if args.update:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(
            json.dumps(
                {"recorded": date.today().isoformat(), "plugins": current},
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )
        print(
            f"recorded {sum(len(files) for files in current.values())} upstream "
            f"files across {len(current)} forks in {FIXTURE.relative_to(REPO)}"
        )
        for note in missing:
            print(f"  note: {note}")
        return 0

    recorded = load_recorded().get("plugins", {})
    if not recorded:
        print(f"no recorded baseline in {FIXTURE.relative_to(REPO)}; run --update")
        return 0

    drifted: list[str] = []
    for stock_name, files in sorted(current.items()):
        before = recorded.get(stock_name, {})
        changed = [
            name for name, digest in sorted(files.items())
            if before.get(name) != digest
        ]
        if changed:
            drifted.append(
                f"  {stock_name}: " + ", ".join(
                    f"{name} changed upstream" if name in before
                    else f"{name} is new upstream"
                    for name in changed
                )
            )

    if drifted or missing:
        print(f"upstream drift since {load_recorded().get('recorded', 'unknown')}:")
        for line in drifted:
            print(line)
        for note in missing:
            print(f"  note: {note}")
        print("review the fork, then record with tools/check-upstream-drift.py --update")
        return 1

    print(
        f"forks in sync with upstream "
        f"({len(current)} plugins, recorded {load_recorded().get('recorded', 'unknown')})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
