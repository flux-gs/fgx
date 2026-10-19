#!/usr/bin/env python3
"""prune_staged -- take out of disk_src whatever the build no longer produces.

NINJA CANNOT EXPRESS "ENSURE THIS IS ABSENT".  A file the graph never knew
about cannot be one of its inputs, so removing a tool from the manifest never
unstaged it and deleting the leftover could not dirty the image edge.  That is
how `disk_src/bin/jsh' shipped after jsh was deleted, and how
`usr/man/cat8/IFCONFIG.8' outlived its source by over a week -- its source was
never on main at all, so "removed" understates it: an artifact with NO tracked
source outlived every checkout.

gen.py writes `build/staged.list' -- exactly what the graph produces -- and
anything else in a GENERATED directory is a leftover.

WHY IT IS A TOOL OF ITS OWN.  This was eighteen lines inside
tools/ninja/mkimage.sh, which built the ProDOS image.  That image is retired,
and the guard is not about images at all: it is about the staging tree, which
every image is built FROM.  Moving it out is what keeps it when the thing it
was living inside goes away.

ONLY GENERATED DIRECTORIES ARE TOUCHED, and all of them are gitignored build
output.  A directory holding tracked source is not in the list and must never
be: this deletes files.

Exit 0 = pruned (or nothing to prune), 1 = the list is missing or unusable.
Run `--self-test' to check the rule against a synthetic tree.
"""
import argparse
import pathlib
import sys

# Generated staging directories, all gitignored.  `disk_src/lib' itself is NOT
# here and must not be: it holds tracked files (robots.roll, fonts/) beside
# generated ones, and this tool deletes.
PRUNE_DIRS = [
    "disk_src/bin", "disk_src/sbin", "disk_src/testbin",
    "disk_src/usr/fgx/bin", "disk_src/usr/fgx/cda", "disk_src/lib/modules",
] + ["disk_src/usr/man/cat%d" % n for n in range(1, 9)]

# Neither is a build product of the graph, and neither is a leftover.
KEEP = ("_FileInformation.txt", ".gitkeep")


def prune(root, staged, dirs=PRUNE_DIRS):
    """Delete files under `dirs' that `staged' does not name.  Returns the
    list of repo-relative paths removed.

    AN EMPTY LIST IS REFUSED RATHER THAN OBEYED.  "The graph produces nothing"
    would prune the whole staging tree, and a build that produced nothing is a
    build that failed, not a tree to clean."""
    if not staged:
        raise ValueError("the staged list is empty -- that would prune every "
                         "generated directory, so it is refused")
    removed = []
    for d in dirs:
        dp = root / d
        if not dp.is_dir():
            continue
        for f in sorted(dp.iterdir()):
            if not f.is_file() or f.name in KEEP:
                continue
            rel = str(f.relative_to(root))
            if rel not in staged:
                f.unlink()
                removed.append(rel)
    return removed


def read_list(path):
    return {l.strip() for l in path.read_text().splitlines() if l.strip()}


def self_test():
    """The rule, and the two ways it could be wrong: keeping a leftover, and
    deleting something the list names."""
    import tempfile
    bad = 0
    with tempfile.TemporaryDirectory() as td:
        root = pathlib.Path(td)
        gen = root / "disk_src/bin"
        gen.mkdir(parents=True)
        for n in ("cat", "jsh", ".gitkeep", "_FileInformation.txt"):
            (gen / n).write_text("x")
        # A directory NOT in the prune list must be untouched even though its
        # contents are absent from the list.
        tracked = root / "disk_src/etc"
        tracked.mkdir(parents=True)
        (tracked / "passwd").write_text("x")

        removed = prune(root, {"disk_src/bin/cat"},
                        dirs=["disk_src/bin", "disk_src/etc_NOT_LISTED"])
        checks = [
            ("the leftover is removed", removed == ["disk_src/bin/jsh"]),
            ("a staged file survives", (gen / "cat").is_file()),
            (".gitkeep survives", (gen / ".gitkeep").is_file()),
            ("cadius metadata survives", (gen / "_FileInformation.txt").is_file()),
            ("an unlisted DIRECTORY is untouched", (tracked / "passwd").is_file()),
        ]
        for name, ok in checks:
            print("  %s %s" % ("ok  " if ok else "WRONG", name))
            bad += 0 if ok else 1

        # THE VACUOUS CASE.  An empty list means "the graph produces nothing",
        # which would prune everything -- and a build that produced nothing is
        # a build that failed, not a tree to clean.
        (gen / "cat2").write_text("x")
        try:
            prune(root, set(), dirs=["disk_src/bin"])
            print("  WRONG an empty staged list pruned instead of refusing")
            bad += 1
        except ValueError:
            print("  ok   an empty staged list is refused, not obeyed")
    if bad:
        print("prune_staged: SELF-TEST FAILED (%d)" % bad)
        return 1
    print("prune_staged: self-test clean (6 cases)")
    return 0


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", default="build/staged.list")
    ap.add_argument("--root", default=".")
    ap.add_argument("--stamp")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)

    if args.self_test:
        return self_test()

    root = pathlib.Path(args.root).resolve()
    lst = root / args.list
    if not lst.is_file():
        print("prune_staged: FAIL -- %s does not exist; gen.py writes it, so "
              "the graph has not been generated" % lst)
        return 1
    staged = read_list(lst)
    try:
        removed = prune(root, staged)
    except ValueError as e:
        print("prune_staged: FAIL -- %s" % e)
        return 1
    for r in removed:
        print("prune_staged: pruning stale %s" % r, file=sys.stderr)
    if args.stamp:
        p = root / args.stamp
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("%d pruned\n" % len(removed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
