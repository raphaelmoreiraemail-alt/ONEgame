"""Builds app/assets/data/words_{fr,en}.txt for Mot éclair (section 7.22).

Input lists (downloaded separately, see ASSETS.md):
  EN: ENABLE word list (public domain)            -> enable1.txt
  FR: an-array-of-french-words (MIT, Z. Sikelianos) -> index.json
Kept: 3 to 7 letters, accents removed, letters only, uppercase, unique.
Usage: python3 -I tools/build_wordlists.py <enable1.txt> <index.json>
"""
import json
import pathlib
import sys
import unicodedata

OUT = pathlib.Path(__file__).resolve().parent.parent / "app" / "assets" / "data"


def clean(words):
    out = set()
    for w in words:
        w = unicodedata.normalize("NFD", w.strip()).encode("ascii", "ignore").decode().upper()
        if 3 <= len(w) <= 7 and w.isalpha():
            out.add(w)
    return sorted(out)


def main(enable_path, fr_path):
    en = clean(pathlib.Path(enable_path).read_text(encoding="utf-8").splitlines())
    fr = clean(json.loads(pathlib.Path(fr_path).read_text(encoding="utf-8")))
    for lang, words in (("en", en), ("fr", fr)):
        (OUT / f"words_{lang}.txt").write_text("\n".join(words) + "\n", encoding="ascii")
        sevens = sum(1 for w in words if len(w) == 7)
        print(f"{lang}: {len(words)} words, {sevens} of 7 letters")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
