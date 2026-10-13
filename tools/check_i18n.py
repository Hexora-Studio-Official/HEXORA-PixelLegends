#!/usr/bin/env python3
"""Validate PixelLegends' English-only UI string table.

Runs without Godot, so it can gate every commit:

  * only the English source table is present
  * no duplicate keys or empty values
  * placeholders use the project's named-token format

Usage:
    python3 tools/check_i18n.py            # check, exit non-zero on failure
    python3 tools/check_i18n.py --list     # also dump every key
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
I18N_DIR = REPO_ROOT / "src" / "i18n"
SOURCE_LOCALE = "en"

# `"key": "value",` — values may contain escaped quotes and are single-line.
ENTRY_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}")


def parse_table(path: Path) -> tuple[dict[str, str], list[str]]:
    """Return (entries, problems) for one strings_<locale>.gd file."""
    entries: dict[str, str] = {}
    problems: list[str] = []
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line.startswith('"'):
            continue
        match = ENTRY_RE.match(raw)
        if not match:
            # A multi-line string would land here. Fail loudly rather than
            # silently skipping a key that then shows up as a raw key in-game.
            problems.append(f"{path.name}:{lineno}: could not parse entry: {line[:70]!r}")
            continue
        key, value = match.group(1), match.group(2)
        if key in entries:
            problems.append(f"{path.name}:{lineno}: duplicate key {key!r}")
            continue
        if not value.strip():
            problems.append(f"{path.name}:{lineno}: empty value for {key!r}")
            continue
        entries[key] = value
    return entries, problems


def locale_files() -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in sorted(I18N_DIR.glob("strings_*.gd")):
        locale = path.stem.removeprefix("strings_")
        found[locale] = path
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="print every key")
    args = parser.parse_args()

    files = locale_files()
    if SOURCE_LOCALE not in files:
        print(f"FAIL: no source locale strings_{SOURCE_LOCALE}.gd in {I18N_DIR}")
        return 1
    extra_locales = sorted(set(files) - {SOURCE_LOCALE})
    if extra_locales:
        print("FAIL: PixelLegends UI is English-only; unexpected locale table(s): "
              + ", ".join(extra_locales))
        return 1

    tables: dict[str, dict[str, str]] = {}
    problems: list[str] = []
    for locale, path in files.items():
        table, table_problems = parse_table(path)
        tables[locale] = table
        problems.extend(table_problems)

    source = tables[SOURCE_LOCALE]
    source_keys = set(source)

    for locale, table in tables.items():
        if locale == SOURCE_LOCALE:
            continue
        locale_keys = set(table)
        missing = sorted(source_keys - locale_keys)
        extra = sorted(locale_keys - source_keys)
        for key in missing:
            problems.append(f"{locale}: missing key {key!r}")
        for key in extra:
            problems.append(f"{locale}: unknown key {key!r} (not in {SOURCE_LOCALE})")

    # Placeholder parity.
    for locale, table in tables.items():
        for key, value in table.items():
            if key not in source:
                continue
            source_placeholders = set(PLACEHOLDER_RE.findall(source[key]))
            locale_placeholders = set(PLACEHOLDER_RE.findall(value))
            for placeholder in sorted(locale_placeholders - source_placeholders):
                problems.append(
                    f"{locale}:{key}: placeholder {{{placeholder}}} is not passed by callers"
                )
            for placeholder in sorted(source_placeholders - locale_placeholders):
                problems.append(
                    f"{locale}:{key}: drops placeholder {{{placeholder}}} from the source string"
                )

    if args.list:
        for key in sorted(source_keys):
            print(key)

    print(f"locales: {', '.join(sorted(tables))}")
    for locale in sorted(tables):
        print(f"  {locale}: {len(tables[locale])} keys")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("\nOK — string tables are consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
