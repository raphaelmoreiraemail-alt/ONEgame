"""Merges strings into app/lib/core/l10n/app_{fr,en}.arb.

Input: a JSON file {"key": {"fr": "...", "en": "...", "types": {"n": "int"}}}.
Placeholders like {name} are detected automatically (type Object by default).
Usage: python3 tools/l10n_add.py strings.json
"""
import json
import pathlib
import re
import sys

ARB = pathlib.Path(__file__).resolve().parent.parent / "app" / "lib" / "core" / "l10n"


def main(path):
    new = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    fr = json.loads((ARB / "app_fr.arb").read_text(encoding="utf-8"))
    en = json.loads((ARB / "app_en.arb").read_text(encoding="utf-8"))
    for key, v in new.items():
        fr[key] = v["fr"]
        en[key] = v["en"]
        names = sorted(set(re.findall(r"\{(\w+)\}", v["fr"])) | set(re.findall(r"\{(\w+)\}", v["en"])))
        if names:
            types = v.get("types", {})
            fr["@" + key] = {"placeholders": {n: {"type": types.get(n, "Object")} for n in names}}
        elif "@" + key in fr and "placeholders" in fr["@" + key]:
            del fr["@" + key]
    for name, data in (("app_fr.arb", fr), ("app_en.arb", en)):
        (ARB / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"merged {len(new)} keys")


if __name__ == "__main__":
    main(sys.argv[1])
