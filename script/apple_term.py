#!/usr/bin/env python3
"""
apple_term.py — look up Apple's own localized wording for English UI terms.

    python3 script/apple_term.py <lang> "Input Monitoring" "Open at Login" ...

macOS ships its localized UI text as .loctable files (binary plists keyed by
language). This searches the ones in System Settings, AppKit and a few
built-in apps for entries whose English value matches a given term (ignoring
case and a trailing ellipsis), and prints that entry in <lang>:

    'Input Monitoring' -> 'Eingabeüberwachung'   [SecurityPrivacyExtension.appex/Localizable.loctable]

Use it when translating so that pane names, menu items and checkbox wording
match what users actually see on their Mac. <lang> is our .lproj name (e.g.
de, pt-BR, zh-Hans); where Apple's code differs it is mapped via ALIASES.
No output means Apple has no match — or doesn't localize macOS into <lang>.
"""

import plistlib
import sys
from pathlib import Path

ROOTS = [
    "/System/Library/ExtensionKit/Extensions",  # System Settings panes
    "/System/Library/Frameworks/AppKit.framework",
    "/System/Applications/System Settings.app",
    "/System/Applications/TextEdit.app",
    "/System/Applications/Notes.app",
]

# Our .lproj name → Apple's .loctable language keys, tried first.
ALIASES = {"nb": ["no"], "zh-Hans": ["zh_CN"], "zh-Hant": ["zh_TW", "zh_HK"]}


def normalize(s):
    return s.lower().rstrip("…. ")


def candidate_langs(lang):
    return ALIASES.get(lang, []) + [lang, lang.replace("-", "_"), lang.split("-")[0]]


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    lang, terms = argv[0], {normalize(t) for t in argv[1:]}
    langs = candidate_langs(lang)

    tables = sorted({p for root in ROOTS for p in Path(root).rglob("*.loctable")})
    seen = set()
    for path in tables:
        try:
            data = plistlib.loads(path.read_bytes())
        except Exception:
            continue
        en = data.get("en") or data.get("English")
        target = next((data[l] for l in langs if l in data), None)
        if not isinstance(en, dict) or not isinstance(target, dict):
            continue
        for key, value in en.items():
            if isinstance(value, str) and normalize(value) in terms:
                localized = target.get(key)
                if isinstance(localized, str) and (value, localized) not in seen:
                    seen.add((value, localized))
                    print(f"{value!r} -> {localized!r}   [{path.parts[-4]}/{path.name}]")


if __name__ == "__main__":
    main(sys.argv[1:])
