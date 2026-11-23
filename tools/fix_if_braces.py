"""Adds braces to brace-less `if (...)` statements (curly_braces lint),
including statements the formatter split over several lines."""
import re
import sys

IF = re.compile(r"^(\s*)if \((.*)\)$")

for path in sys.argv[1:]:
    lines = open(path).read().split("\n")
    out = []
    i = 0
    changed = False
    while i < len(lines):
        m = IF.match(lines[i])
        if m and i + 1 < len(lines):
            ind = m[1]
            j = i + 1
            while j < len(lines) and not (lines[j].rstrip().endswith(";") and len(lines[j]) - len(lines[j].lstrip()) == len(ind) + 2):
                j += 1
            if j < len(lines):
                out.append(f"{ind}if ({m[2]}) {{")
                out.extend(lines[i + 1 : j + 1])
                out.append(f"{ind}}}")
                i = j + 1
                changed = True
                continue
        out.append(lines[i])
        i += 1
    if changed:
        open(path, "w").write("\n".join(out))
        print("fixed", path)
