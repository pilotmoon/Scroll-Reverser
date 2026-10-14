#!/usr/bin/env python3
"""
check_placeholders.py — catch translations that would break at runtime.

    python3 script/check_placeholders.py            # check every language
    python3 script/check_placeholders.py de fr      # check just these

For each resources/<lang>.lproj/*.strings entry, reports:

  * a value whose format placeholders (%1$@, %d, …) differ from its key's —
    a missing or extra placeholder shows the wrong text or crashes
  * a ⛔ without its emoji variation selector (U+FE0F), which then renders as
    a plain text symbol instead of the emoji used in English

Prints nothing and exits 0 when everything is fine; exits 1 otherwise.
"""

import re
import sys
from pathlib import Path

ENTRY_RE = re.compile(r'"(?P<key>(?:[^"\\]|\\.)*)"\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*;')
PLACEHOLDER_RE = re.compile(r'%(?:\d+\$)?[@dDuUxXfeEgGcCsSp%]')
EMOJI_NEEDING_VS16 = ["⛔"]
VS16 = "️"


def problems(path):
    for m in ENTRY_RE.finditer(path.read_text(encoding="utf-8")):
        key, value = m.group("key"), m.group("value")
        if sorted(PLACEHOLDER_RE.findall(key)) != sorted(PLACEHOLDER_RE.findall(value)):
            yield f"placeholders differ: {key!r} -> {value!r}"
        for emoji in EMOJI_NEEDING_VS16:
            if value.count(emoji) != value.count(emoji + VS16):
                yield f"{emoji} missing variation selector: {value!r}"


def main(argv):
    res = Path(__file__).resolve().parent.parent / "resources"
    langs = argv or sorted(p.name.removesuffix(".lproj") for p in res.glob("*.lproj"))
    failed = False
    for lang in langs:
        for path in sorted((res / f"{lang}.lproj").glob("*.strings")):
            for problem in problems(path):
                print(f"{lang}/{path.name}: {problem}")
                failed = True
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
