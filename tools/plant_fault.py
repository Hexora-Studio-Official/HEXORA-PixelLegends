#!/usr/bin/env python3
"""Introduce a deliberate fault into a file, for testing the checkers.

    python3 tools/plant_fault.py <file> "<old text>>>><new text>"

Used by .github/workflows/checks.yml: every check has to be shown to *fail* on
a known-bad input, because a checker that quietly stopped working looks exactly
like a repository with no problems. Restore the file with `git checkout --`.

Kept as a tool rather than an inline heredoc so the same fault can be planted
by hand while debugging a checker:

    python3 tools/plant_fault.py project.godot 'icon.svg>>>>missing.svg'
    python3 tools/check_refs.py          # expect a FAIL naming missing.svg
    git checkout -- project.godot

Restoring is `git checkout --`, so **commit first**: it throws away every
uncommitted change in that file, not just the planted one. (Learned the hard
way.)
"""

from __future__ import annotations

import sys
from pathlib import Path

SEPARATOR = ">>>>"


def main() -> int:
    if len(sys.argv) != 3 or SEPARATOR not in sys.argv[2]:
        print(__doc__)
        return 2
    path = Path(sys.argv[1])
    old, new = sys.argv[2].split(SEPARATOR, 1)
    if not path.is_file():
        print(f"plant_fault: {path} is not a file", file=sys.stderr)
        return 1
    text = path.read_text(encoding="utf-8")
    if old not in text:
        print(f"plant_fault: {old!r} is not in {path} — the source moved on and "
              f"this fault no longer tests anything", file=sys.stderr)
        return 1
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"planted: {path} — {old!r} -> {new!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
