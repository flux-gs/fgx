#!/usr/bin/env python3
"""check_modload_lists -- /etc/rc and /etc/modload.conf name the SAME modules,
in the same order.  apple/fgx#384.

TWO FILES LIST THE LOADABLE MODULES AND ONLY ONE OF THEM IS READ.  On a UFS
root the kernel's Mod_LoadConf cannot open /etc/modload.conf -- it reads through
Fs_ReadN, which answers EBADF for a root descriptor -- so /etc/rc's
`/sbin/modload' lines, read in order as one list, are the only thing that loads
anything.  modload.conf is
still shipped, still documented by modload.conf(5), and still the file a person
edits when they want to change what loads.

So the two are one list written twice, and they diverged: modload.conf named
six modules and rc.in's line named five.  The missing one was `ufsprobe', which
is the module carrying the filesystem self-test -- so the probe had not run at
all, and the manifest's seven `screen_lacks' arms were passing because the thing
that would have printed `ufs: BROKEN' was never loaded.  A gate off by default
whose instrument is also absent is two ways to see nothing.

This is the cheap half of the fix.  The list still lives in two files, because
neither one can be generated from the other without the shell reading a config
file at boot; what this removes is the SILENCE when they disagree.

Exit 0 = the lists agree, 1 = they do not.
Run `--self-test' to check this checker against synthetic inputs.
"""
import pathlib
import re
import sys

RC_IN = pathlib.Path("disk_src/etc/rc.in")
CONF = pathlib.Path("disk_src/etc/modload.conf")
MODLOAD_RE = re.compile(r"^\s*(?:/sbin/)?modload\s+(.*)$", re.M)


def conf_list(text):
    """The module names in a modload.conf, in order."""
    out = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            out.append(line)
    return out


def rc_list(text):
    """The module names the rc script's modload lines pass, in file order.

    Comment lines are stripped FIRST.  rc.in's header quotes the command it is
    describing, and a scan that did not strip comments would find the quotation
    before the line that runs.  Each line's names end at its first redirection
    (`>/dev/console', `2>&1'), which is the shell's, not modload's.
    """
    body = "\n".join(l for l in text.splitlines()
                     if not l.lstrip().startswith("#"))
    hits = MODLOAD_RE.findall(body)
    if not hits:
        return None, 0
    out = []
    for hit in hits:
        words = hit.split()
        for i, w in enumerate(words):
            if re.match(r"^\d*[<>]", w):
                words = words[:i]
                break
        # A `$NAME' word is a module rc loads only when the image carries it:
        # `[ -f /lib/modules/x ] && NAME=x'.  It stands for x.
        for i, w in enumerate(words):
            m = re.match(r"^\$(\w+)$", w)
            if m:
                a = re.search(r"\[\s+-f\s+/lib/modules/(\w+)\s+\]\s*&&\s*%s=(\w+)"
                              % m.group(1), body)
                words[i] = a.group(2) if a and a.group(1) == a.group(2) else w
        out.extend(words)
    return out, len(hits)


def compare(rc_text, conf_text):
    """Returns a list of complaint strings; empty means the two agree."""
    want = conf_list(conf_text)
    got, n = rc_list(rc_text)
    if got is None:
        return ["%s has no `modload' line" % RC_IN]
    # THE VACUOUS CASE IS A FAILURE.  Two empty lists agree perfectly, and a
    # pattern that has gone stale produces exactly that.
    if not want:
        return ["%s lists no modules -- either the file is empty or the "
                "comment rule has gone stale, and an empty list agrees with "
                "anything" % CONF]
    if not got:
        return ["the `modload' lines in %s pass no module names" % RC_IN]
    if got == want:
        return []
    out = ["%s and %s disagree about what loads, and %s is the only one the "
           "machine reads on a UFS root:" % (RC_IN, CONF, RC_IN)]
    out.append("    %-16s %s" % (CONF.name, " ".join(want)))
    out.append("    %-16s %s" % ("rc.in", " ".join(got)))
    missing = [m for m in want if m not in got]
    extra = [m for m in got if m not in want]
    if missing:
        out.append("    in %s and NOT loaded: %s" % (CONF.name,
                                                     " ".join(missing)))
    if extra:
        out.append("    loaded and NOT in %s: %s" % (CONF.name,
                                                     " ".join(extra)))
    if not missing and not extra:
        out.append("    same names, different ORDER -- and the order is "
                   "load-bearing: ufsprobe drives its cases from its own "
                   "mod_init, so a case touching a pty needs pty.mod up first")
    return out


def self_test():
    """Ten synthetic pairs; the six that must DISAGREE are the point."""
    conf = "# a comment\nserial\nbpf\npty   # trailing\n"
    good = "# quoting: /sbin/modload a b c\n/sbin/modload serial bpf pty\n"
    short = "/sbin/modload serial bpf\n"
    swapped = "/sbin/modload serial pty bpf\n"
    twice = "/sbin/modload serial\n/sbin/modload bpf pty\n"
    twiceswap = "/sbin/modload bpf pty\n/sbin/modload serial\n"
    redir = "/sbin/modload serial bpf pty >/dev/console 2>&1\n"
    redirshort = "/sbin/modload serial bpf >/dev/console pty\n"
    guarded = ("P=\n[ -f /lib/modules/pty ] && P=pty\n"
               "/sbin/modload serial bpf $P >/dev/console\n")
    misguard = ("P=\n[ -f /lib/modules/tty ] && P=pty\n"
                "/sbin/modload serial bpf $P\n")
    cases = [
        ("agreeing lists", good, conf, True),
        ("a module missing from rc", short, conf, False),
        ("the same names reordered", swapped, conf, False),
        ("two modload invocations, in order", twice, conf, True),
        ("two modload invocations, out of order", twiceswap, conf, False),
        ("a redirected modload line", redir, conf, True),
        ("a name after the redirection", redirshort, conf, False),
        ("an empty modload.conf", good, "# only comments\n", False),
        ("a guarded $NAME module", guarded, conf, True),
        ("a guard testing another file", misguard, conf, False),
    ]
    bad = 0
    for name, rc, cf, want_ok in cases:
        ok = not compare(rc, cf)
        mark = "ok  " if ok == want_ok else "WRONG"
        print("  %s %-28s -> %s" % (mark, name, "agree" if ok else "disagree"))
        if ok != want_ok:
            bad += 1
    # The comment-stripping case is the one a naive scan gets wrong, so it is
    # asserted by VALUE rather than only by verdict.
    got, _ = rc_list(good)
    if got != ["serial", "bpf", "pty"]:
        print("  WRONG comment line was read as the modload invocation: %r"
              % (got,))
        bad += 1
    else:
        print("  ok   a quoted modload in a comment is not the live line")
    if bad:
        print("check_modload_lists: SELF-TEST FAILED (%d)" % bad)
        return 1
    print("check_modload_lists: self-test clean (%d cases)" % (len(cases) + 1))
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    for p in (RC_IN, CONF):
        if not p.exists():
            print("check_modload_lists: FAIL -- %s not found (run from the "
                  "repo root)" % p)
            return 1
    problems = compare(RC_IN.read_text(), CONF.read_text())
    if problems:
        print("check_modload_lists: FAIL -- " + problems[0])
        for line in problems[1:]:
            print(line)
        return 1
    names, _ = rc_list(RC_IN.read_text())
    print("check_modload_lists: clean (%d modules, same order in both: %s)"
          % (len(names), " ".join(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
