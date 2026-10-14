#!/usr/bin/env python3
"""
merge_strings.py — sync every translation to the English key set.

Run automatically by script/gens after genstrings rebuilds the English base.
Can also be run on its own:

    python3 script/merge_strings.py            # rewrite the language files
    python3 script/merge_strings.py --check     # report only, write nothing
    python3 script/merge_strings.py --mark-identical

For every English .strings table (Localizable.strings, Colors.strings, …) and each
resources/<lang>.lproj/<same table> (except en):

  * keys and their order come from en.lproj (the source of truth)
  * existing translations are preserved
  * a key that is new, or still an untranslated placeholder, is written with the
    English text as its value and tagged "TODO:TRANSLATE" in the comment, so the
    app keeps showing English until it's translated and translators can find the
    gaps with `grep -rn TODO:TRANSLATE`
  * keys no longer present in English are dropped
  * the engineer comment above each entry is always refreshed from English

To translate: replace the placeholder value. A string whose translation is
intentionally identical to English is cleared by removing the
"TODO:TRANSLATE — " prefix from its comment. Use script/apple_term.py to match
Apple's own wording, and script/check_placeholders.py to validate the result.

--mark-identical additionally tags any unmarked value that is identical to
English as untranslated. Use it when adopting files that predate the marker
(community translations often left English placeholders in place); then clear
the marker on the ones that genuinely translate to the same text (e.g. "OK").

Variant locales listed in VARIANT_LOCALES (e.g. en-GB) are sparse overrides of
the base language: they hold only the few strings that differ and fall back to
English for the rest. They are synced to English order/comments and pruned of
removed keys, but missing keys are NOT filled with placeholders.
"""

import re
import sys
from pathlib import Path

MARKER = "TODO:TRANSLATE"

# Sparse "diff" locales: only override the handful of strings that differ from
# the base language; everything else falls back to English at runtime.
VARIANT_LOCALES = set()

# One .strings entry: an optional /* comment */ then "key" = "value";
# The key/value bodies allow escaped characters (e.g. \" \\), so quotes inside
# a string don't end it. DOTALL lets comments/values span lines.
ENTRY_RE = re.compile(
    r'(?:/\*(?P<comment>.*?)\*/\s*)?'
    r'"(?P<key>(?:[^"\\]|\\.)*)"\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"\s*;',
    re.DOTALL,
)


def parse(text):
    """Yield (comment_or_None, key, value) for each entry, in file order."""
    for m in ENTRY_RE.finditer(text):
        yield m.group("comment"), m.group("key"), m.group("value")


def build_language(eng_order, existing, variant=False, mark_identical=False):
    """Pure core: given the English entries and a language's existing
    {key: (value, marked)} map, return (text, stats).

    A variant locale keeps only the keys it already overrides (no placeholders
    for missing keys). With mark_identical, an unmarked value equal to English
    is treated as an untranslated placeholder."""
    eng_keys = {k for _, k, _ in eng_order}
    new_keys = [] if variant else [k for k in eng_keys if k not in existing]
    stale_keys = [k for k in existing if k not in eng_keys]

    blocks, untranslated = [], 0
    for comment, key, evalue in eng_order:
        eng_comment = (comment or "").strip()
        if key in existing:
            value, marked = existing[key]
            if value != evalue:
                needs = False            # translator changed it → translated
            elif marked or mark_identical:
                needs, value = True, evalue   # placeholder, still untranslated
            else:
                needs = False            # intentional identity translation
        elif variant:
            continue                     # variant locale: no placeholders
        else:
            needs, value = True, evalue  # brand-new key

        if needs:
            untranslated += 1
            c = f"{MARKER} — {eng_comment}" if eng_comment else MARKER
        else:
            c = eng_comment
        blocks.append((f"/* {c} */\n" if c else "") + f'"{key}" = "{value}";')

    text = "\n\n".join(blocks) + "\n"
    return text, dict(total=len(blocks), untranslated=untranslated,
                      new=len(new_keys), stale=len(stale_keys))


# C0/C1 control characters except tab, newline, carriage return. Stray NULs
# have crept into translations before; strip them so files stay valid text
# (a single NUL makes git treat the whole file as binary and undiffable).
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def load_existing(path):
    """Return ({key: (value, marked)}, cleaned_count). Strips stray control
    characters from keys and values."""
    if not path.exists():
        return {}, 0
    out, cleaned = {}, 0
    for c, k, v in parse(path.read_text(encoding="utf-8")):
        ck, cv = CONTROL_RE.sub("", k), CONTROL_RE.sub("", v)
        if ck != k or cv != v:
            cleaned += 1
        out[ck] = (cv, bool(c and MARKER in c))
    return out, cleaned


def process_table(en_file, lang_dirs, check, mark_identical=False):
    """Sync one table file (e.g. Localizable.strings, Colors.strings) from its
    English base to every language. Returns True if any file would change."""
    eng_order = list(parse(en_file.read_text(encoding="utf-8")))
    table = en_file.name
    print(f"[{table}]")
    any_change = False
    for d in lang_dirs:
        f = d / table
        variant = d.name.removesuffix(".lproj") in VARIANT_LOCALES
        existing, cleaned = load_existing(f)
        text, st = build_language(eng_order, existing, variant=variant,
                                  mark_identical=mark_identical)
        if variant and st["total"] == 0:
            # variant locale with no overrides for this table: no file needed
            if not check and f.exists():
                f.unlink()
                any_change = True
            continue
        changed = (not f.exists()) or f.read_text(encoding="utf-8") != text
        any_change = any_change or changed
        if not check:
            f.write_text(text, encoding="utf-8")
        flags = []
        if variant:
            flags.append("variant")
        if st["new"]:
            flags.append(f"{st['new']} new")
        if st["stale"]:
            flags.append(f"{st['stale']} removed")
        if cleaned:
            flags.append(f"{cleaned} cleaned")
        if changed:
            flags.append("changed")
        suffix = f"  ({', '.join(flags)})" if flags else ""
        print(f"  {d.name:18} {st['untranslated']:3} untranslated / {st['total']}{suffix}")
    print(f"  {'Checked' if check else 'Merged'} {len(eng_order)} keys "
          f"across {len(lang_dirs)} languages.")
    return any_change


def main(argv):
    check = "--check" in argv
    mark_identical = "--mark-identical" in argv
    root = Path(__file__).resolve().parent.parent
    res = root / "resources"
    en_tables = sorted((res / "en.lproj").glob("*.strings"))
    if not en_tables:
        sys.exit(f"No English base tables found in {res / 'en.lproj'}")

    lang_dirs = sorted(p for p in res.glob("*.lproj") if p.name != "en.lproj")

    any_change = False
    for en_file in en_tables:
        any_change = process_table(en_file, lang_dirs, check, mark_identical) or any_change

    if check and any_change:
        print("(--check: files would change; run without --check to apply)")


if __name__ == "__main__":
    main(sys.argv[1:])
