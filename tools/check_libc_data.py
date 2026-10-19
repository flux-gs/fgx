#!/usr/bin/env python3
"""check_libc_data.py - every label libc's hand-written data defines is used.

The fixed data prefix (toolchain/lib/libc_data.s, args_data.s,
fcc_runtime_data.s) is PUT into every program's data segment, so a label
nothing references still costs every process its bytes.  A label is live if
code outside the three files names it, or if a live label's own definition
names it (a table of pointers keeps its strings alive).  Comments do not
count: `;' to end of line and `*' in column 1 in assembly, /* */ and // in C.

Every tracked source-like file is scanned, generated link files included, so
the error runs the safe way: a stray mention keeps a label alive, never the
reverse.  NOT seen: a name fcc builds at run time (emit.c's snprintf of
"_fcc_img%u" / "_fcc_fpr%d"); a data cell only codegen reaches that way must
be named in fcc's source some other way or it will be reported dead.

Run: python3 tools/check_libc_data.py [--self-test]
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = ["toolchain/lib/libc_data.s", "toolchain/lib/args_data.s",
        "toolchain/lib/fcc_runtime_data.s", "toolchain/lib/libc_start_data.s"]
LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")
DIRECTIVE = re.compile(r"\b(EQU|MAC|ENT)\b")
SKIP = re.compile(r"^(docs|vendor|examples)/")


def strip_asm(text):
    out = []
    for line in text.splitlines():
        if line.startswith("*"):
            continue
        out.append(line.split(";", 1)[0])
    return "\n".join(out)


def strip_c(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def strip(path, text):
    return strip_asm(text) if path.endswith(".s") else strip_c(text)


def definitions(files):
    """{label: (file, body text)} for every storage label in `files`."""
    defs = {}
    for path, text in files.items():
        cur = None
        for line in text.splitlines():
            m = LABEL.match(line)
            if m and not DIRECTIVE.search(line.split(";", 1)[0]):
                cur = m.group(1)
                defs[cur] = (path, [])
            if cur:
                defs[cur][1].append(line.split(";", 1)[0])
    return {k: (f, "\n".join(b)) for k, (f, b) in defs.items()}


def dead_labels(data_files, other_files):
    defs = definitions(data_files)
    others = {p: strip(p, t) for p, t in other_files.items()}

    def named_in(label, text):
        return re.search(r"(?<![A-Za-z0-9_])" + re.escape(label)
                         + r"(?![A-Za-z0-9_])", text) is not None

    live = {n for n in defs if any(named_in(n, t) for t in others.values())}
    grew = True
    while grew:
        grew = False
        for n in defs:
            if n not in live and any(named_in(n, defs[m][1]) for m in live):
                live.add(n)
                grew = True
    return sorted((defs[n][0], n) for n in defs if n not in live)


def repo_files():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True,
                         text=True, check=True).stdout.split()
    files = {}
    for p in out:
        if SKIP.search(p) or not re.search(
                r"(\.(s|c|h|in|py|sh|json)|/Makefile)$", p):
            continue
        if p in DATA or p == "tools/check_libc_data.py":
            continue
        with open(os.path.join(ROOT, p), errors="ignore") as f:
            files[p] = f.read()
    return files


def self_test():
    data = {"d.s": "used    DS 2\ntable   DA used_str\nused_str ASC 'x'\n"
                   "orphan  DS 2\nstr2    ASC 'y'\n"
                   "noted   DS 2 ; an EQU in the comment\n"}
    other = {"a.s": " LDA used\n LDA table ; orphan in a comment\n"
                    "* orphan in a column-1 comment\n",
             "b.c": "/* orphan */ int x;\n"}
    got = [n for _, n in dead_labels(data, other)]
    assert got == ["noted", "orphan", "str2"], got
    print("check_libc_data: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    data = {}
    for p in DATA:
        with open(os.path.join(ROOT, p)) as f:
            data[p] = f.read()
    dead = dead_labels(data, repo_files())
    for path, n in dead:
        print("check_libc_data: %s: %s is referenced by nothing" % (path, n))
    if dead:
        print("check_libc_data: %d dead label(s)" % len(dead), file=sys.stderr)
        return 1
    print("check_libc_data: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
