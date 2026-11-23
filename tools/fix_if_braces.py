"""Adds braces to `if (...)` statements split over two lines by the formatter."""
import re
import sys

PAT = re.compile(r"^(\s*)if \((.*)\)\n\s+(.*;)\n", re.M)

for path in sys.argv[1:]:
    s = open(path).read()
    n = PAT.sub(lambda m: f"{m[1]}if ({m[2]}) {{\n{m[1]}  {m[3]}\n{m[1]}}}\n", s)
    if n != s:
        open(path, "w").write(n)
        print("fixed", path)
