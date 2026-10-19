#!/usr/bin/env python3
"""Every place 2.11BSD asks suser(), and what FGX does about it.

WHY THIS EXISTS.  Porting a tool brings the INTERFACE across; it does not bring
the kernel's enforcement, because the enforcement is not in the tool.  mount(8)
ported cleanly and ran for a whole campaign against a mount(2) that asked
nobody's permission -- and the tree KNEW: vfs_mountat's header said "mount(2)
is unprivileged here, which is a REAL hole and not a simplification", and
_Sys_Reboot's said "any process here can halt the machine".  Both notes ended
with the same sentence, that it "goes with the credentials the VFS is waiting
on".  The credentials landed at UFS 2.6 and nobody walked the set, because
there was no set: each omission was a paragraph in a different file, and
prose in thirty files is not an inventory.

So this is the inventory.  It is mechanical on the side that can be mechanical
-- 2.11BSD is vendored and its suser() calls are a finite, stable list -- and
registered on the side that cannot, which is what FGX does about each one.  A
site with no entry fails the build, so re-vendoring the tree cannot quietly add
an unexamined check, and an entry that says OWED must name a work item, so a
known hole cannot go quiet the way these two did.

WHY 2.11BSD AND NOT RENO.  The credential model is 2.11BSD's (see
docs/coding-standards.md, "Which BSD, when the two disagree"), so 2.11BSD's
suser() sites are the set FGX is answerable for.  Reno's are near-identical in
subject and differ in spelling; where Reno checks something 2.11BSD does not,
it belongs in the registry as an extra row rather than a second scan.

TWO AXES, ONE REGISTRY SHAPE.  `suser()' asks "may this caller do a
privileged thing at all"; `access(ip, mode)' asks "may this caller do THAT to
THIS file", and it is the one the filesystem leans on -- 19 call sites across
seven files of the vendored kernel, four of them in ufs_namei.c.  The second
axis is where the cost already showed: apple/fgx#419 was found by hand
immediately after this tool found four holes on the first, and it is the worst
of the lot -- FGX checks VEXEC on a directory and never VWRITE, so any account
can create and delete in any directory it can search.  Both axes are scanned
here and both register the same four dispositions.

WHAT THIS DOES NOT DO.  It does not prove a carried check is CORRECT -- only
that the named routine contains a permission predicate.  A gate in the wrong
place still passes here; the mount gate's first cut called _Suser before
stashing the arguments and broke root's own mounts, and it was the mount
FIXTURES that caught that, not this.  This answers "is anything asking?", and
the fixtures answer "does it ask the right question?".

COMMENTS ARE STRIPPED BEFORE THE PREDICATE IS LOOKED FOR, because a routine
whose header says "NO VOP_ACCESS" would otherwise satisfy a search for
VOP_ACCESS -- and vfs_fchdir's did say exactly that, for as long as it had no
check.  A check whose tool did not run looks like a pass.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPSTREAM = os.path.join("vendor", "2.11BSD", "usr", "sys", "sys")

# suser()'s own DEFINITION, twice -- sys_net.c's copy carries the comment
# "copied from ufs_fio.c".  Not call sites.
SUSER_DEFINITIONS = {("sys_net.c", 263), ("ufs_fio.c", 104)}

# A routine in FGX counts as gated when its CODE contains one of these -- its
# comments are stripped first.  The asm form is the chokepoint _Suser's own
# header nominates; `kc_curuid' is what a module bank has instead, there being
# no ucred to pass (file.h); and `uid != 0' is the third form, for a far-bank
# routine whose caller's uid arrives as an ARGUMENT because that bank has no
# u-area to read it from (root_sysctl, whose header says so).
SUSER_PREDICATES = ("_Suser", "kc_curuid", "suser", "uid != 0")

# access(ip, mode)'s own definition.  `saccess' is access(2)'s SYSCALL and not
# a call site; the word-boundary in the scan pattern is what keeps it out.
ACCESS_DEFINITIONS = {("ufs_fio.c", 32)}

# What asking the per-file question looks like here: through the vnodeops
# vector when the caller is in another bank, or by name when the filesystem is
# its own -- which is upstream's split too (Reno ufs_lookup.c:108 calls
# ufs_access directly and kern/vfs_vnops.c:95 goes through VOP_ACCESS).
ACCESS_PREDICATES = ("VOP_ACCESS", "ufs_access", "vn_access")

# ---------------------------------------------------------------------------
# THE REGISTRY.  Key is the upstream site; value is (routine, disposition,
# detail).  Dispositions:
#
#   carried  FGX enforces it.  Detail is "path::symbol" and the symbol's body
#            must contain a privilege predicate.
#   stricter FGX refuses the operation to EVERYONE where upstream lets root
#            through.  Detail is "path::symbol" and the body must contain the
#            refusal (EPERM).  A real answer, and safer than upstream's, but it
#            is NOT "carried" and must not read as if a credential were asked.
#   n/a      FGX has no such facility.  Detail says which, and "no such
#            syscall" is only an answer when there really is none -- check
#            include/loader.s before writing it.
#   owed     FGX implements the operation WITHOUT the check.  Detail must name
#            an apple/fgx work item.
# ---------------------------------------------------------------------------
SUSER_REGISTRY = {
    ("kern_prot.c", 135): ("setgroups", "n/a",
        "no setgroups syscall; FGX has one gid and it moves through setgid, "
        "whose rule is _Cred_Set's"),
    ("kern_prot.c", 200): ("setlogin", "carried",
        "src/kernel/syscall.s::_Sys_SetLogin"),
    ("kern_prot2.c", 70): ("setuid", "carried",
        "src/kernel/syscall.s::_Cred_Set"),
    ("kern_prot2.c", 109): ("seteuid", "carried",
        "src/kernel/syscall.s::_Cred_Set"),
    ("kern_prot2.c", 134): ("setgid", "carried",
        "src/kernel/syscall.s::_Cred_Set"),
    ("kern_prot2.c", 158): ("setegid", "carried",
        "src/kernel/syscall.s::_Cred_Set"),
    ("kern_resource.c", 137): ("donice", "n/a",
        "no setpriority syscall; libc's is inert (su(1) BUGS says so)"),
    ("kern_resource.c", 178): ("setrlimit", "owed",
        "apple/fgx#418 -- SYS_SETRLIMIT stores any hard limit from any caller"),
    ("kern_sig.c", 630): ("core", "n/a", "no core dumps"),
    ("kern_sysctl.c", 101): ("__sysctl", "carried",
        "src/kernel/far/root_sysctl.c::root_sysctl"),
    ("kern_time.c", 67): ("settimeofday", "carried",
        "src/kernel/syscall.s::_thunk_Stod"),
    ("kern_time.c", 80): ("setthetime", "carried",
        "src/kernel/syscall.s::_thunk_Stod"),
    ("kern_time.c", 123): ("adjtime", "carried",
        "src/kernel/syscall.s::_thunk_Adj"),
    ("kern_xxx.c", 23): ("reboot", "carried",
        "src/kernel/main.s::_Sys_Reboot"),
    ("quota_sys.c", 84): ("qquota", "n/a", "no quotas"),
    ("quota_sys.c", 169): ("setdlim", "n/a", "no quotas"),
    ("quota_sys.c", 290): ("setduse", "n/a", "no quotas"),
    ("quota_sys.c", 338): ("setwarn", "n/a", "no quotas"),
    ("quota_sys.c", 375): ("dowarn", "n/a", "no quotas"),
    ("quota_sys.c", 403): ("qsync", "n/a", "no quotas"),
    ("quota_sys.c", 433): ("qsetuid", "n/a", "no quotas"),
    ("sys_inode.c", 709): ("vhangup", "n/a", "no vhangup syscall"),
    ("tty_conf.c", 95): ("nullioctl/TIOCSETD", "n/a",
        "no line-discipline switch; NTTY lines are all the one discipline"),
    ("ufs_fio.c", 131): ("ufs_setattr va_flags", "stricter",
        "src/kernel/vfs/ufs_vnops.c::ufs_setattr"),
    ("ufs_fio.c", 170): ("ufs_setattr utimes", "owed",
        "apple/fgx#418 -- the timestamps are honoured for any caller"),
    ("ufs_mount.c", 331): ("getmdev (mount+umount)", "carried",
        "src/kernel/syscall.s::_Sys_Mount"),
    ("ufs_syscalls.c", 65): ("chroot", "n/a", "no chroot syscall"),
    ("ufs_syscalls.c", 205): ("mknod", "n/a",
        "no mknod syscall; device nodes are made when the image is built"),
    ("ufs_syscalls.c", 254): ("link of a directory", "stricter",
        "src/kernel/vfs/vfs_vnops.c::vfs_link"),
    ("ufs_syscalls.c", 353): ("unlink of a directory", "stricter",
        "src/kernel/vfs/vfs_vnops.c::vfs_unlink"),
    ("ufs_syscalls.c", 587): ("chmod1", "carried",
        "src/kernel/vfs/ufs_vnops.c::ufs_chmod1"),
    ("ufs_syscalls.c", 675): ("chown1", "carried",
        "src/kernel/vfs/ufs_vnops.c::ufs_chown1"),
}

# ---------------------------------------------------------------------------
# THE SECOND REGISTRY: every access(ip, mode) in the vendored 2.11BSD kernel.
# Same four dispositions, same rules.  The `mode' is named in each routine
# because IEXEC on a directory and IWRITE on a directory are different
# questions and a row that said only "namei" would hide which one is missing.
# ---------------------------------------------------------------------------
ACCESS_REGISTRY = {
    ("kern_exec.c", 86): ("execve, IEXEC on the image", "carried",
        "src/kernel/vfs/vfs_vnops.c::vn_execchk"),
    ("kern_exec.c", 88): ("execve, IREAD when traced", "n/a",
        "no ptrace syscall, so nothing sets P_TRACED"),
    ("kern_sig.c", 635): ("core, IREAD on the text", "n/a", "no core dumps"),
    ("kern_sig.c", 655): ("core, IWRITE on the core file", "n/a",
        "no core dumps"),
    ("sys_kern.c", 145): ("unpconn, IWRITE on the socket", "n/a",
        "AF_UNIX SOCK_DGRAM exists (XPORT_UNIX, src/modules/net/unp.s) but "
        "bind(2) does not name it yet, so no socket of this system's has a "
        "name in the filesystem to carry a mode.  This becomes `carried' with "
        "unp_bind/unp_connect, whose VOP_ACCESS(vp, VWRITE) IS this check"),
    ("ufs_fio.c", 172): ("ufs_setattr utimes, IWRITE", "owed",
        "apple/fgx#418 -- the timestamps are honoured for any caller"),
    ("ufs_namei.c", 196): ("namei, IEXEC on each directory searched", "carried",
        "src/kernel/vfs/ufs_lookup.c::ufs_lookup"),
    ("ufs_namei.c", 510): ("namei CREATE, IWRITE on the parent", "carried",
        "src/kernel/vfs/ufs_lookup.c::ufs_lookup"),
    ("ufs_namei.c", 593): ("namei DELETE, IWRITE on the parent", "carried",
        "src/kernel/vfs/ufs_lookup.c::ufs_lookup"),
    ("ufs_namei.c", 669): ("namei RENAME, IWRITE on the parent", "carried",
        "src/kernel/vfs/ufs_lookup.c::ufs_lookup"),
    ("ufs_syscalls.c", 47): ("fchdir, IEXEC on the directory", "carried",
        "src/kernel/vfs/vfs_lookup.c::vfs_fchdir"),
    ("ufs_syscalls.c", 90): ("chdirec, IEXEC on the directory", "carried",
        "src/kernel/vfs/vfs_lookup.c::vfs_chdir"),
    ("ufs_syscalls.c", 402): ("saccess R_OK", "carried",
        "src/kernel/vfs/vfs_vnops.c::vn_access"),
    ("ufs_syscalls.c", 404): ("saccess W_OK", "carried",
        "src/kernel/vfs/vfs_vnops.c::vn_access"),
    ("ufs_syscalls.c", 406): ("saccess X_OK", "carried",
        "src/kernel/vfs/vfs_vnops.c::vn_access"),
    ("ufs_syscalls.c", 725): ("truncate by path, IWRITE", "n/a",
        "no truncate(2) by path; SYS_FTRUNCATE takes a DESCRIPTOR, and the "
        "check at that door is the descriptor's own FWRITE (root_ftruncate), "
        "which is upstream's rule for ftruncate too"),
    ("ufs_syscalls.c", 890): ("rename, IWRITE on the source directory",
        "carried", "src/kernel/vfs/ufs_vnops.c::ufs_rename"),
    ("vfs_vnops.c", 119): ("vn_open, IREAD for a read open", "carried",
        "src/kernel/vfs/vfs_vnops.c::vn_open"),
    ("vfs_vnops.c", 132): ("vn_open, IWRITE for a write or truncate open",
        "carried", "src/kernel/vfs/vfs_vnops.c::vn_open"),
}

# (label, scan pattern, definitions to skip, registry, predicates)
AXES = (
    ("suser()", re.compile(r"\bsuser\(\)"), SUSER_DEFINITIONS,
     SUSER_REGISTRY, SUSER_PREDICATES),
    ("access(ip, mode)", re.compile(r"\baccess\("), ACCESS_DEFINITIONS,
     ACCESS_REGISTRY, ACCESS_PREDICATES),
)

ISSUE = re.compile(r"apple/fgx#\d+")


def upstream_sites(pattern, definitions, root=ROOT):
    """[(file, line)] for every match in the vendored kernel, definitions out."""
    sites = []
    d = os.path.join(root, UPSTREAM)
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".c"):
            continue
        with open(os.path.join(d, fn), encoding="utf-8", errors="replace") as f:
            for n, line in enumerate(f, 1):
                if pattern.search(line) and (fn, n) not in definitions:
                    sites.append((fn, n))
    return sites


def strip_comments(text, path):
    """The code of `text` with its commentary removed.

    A routine that says "NO VOP_ACCESS" in its header is not one that calls it,
    and a search over the raw body cannot tell the two apart.  Deliberately
    crude: it can only ever make a predicate DISAPPEAR, so the failure mode is
    a check reported missing when it is present -- loud, and not the quiet
    direction."""
    if path.endswith(".s"):
        return re.sub(r";[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def body_of(path, symbol, root=ROOT):
    """The lines of `symbol`'s definition, to the next one at column 0.

    Deliberately crude and deliberately GENEROUS: a body that runs long
    swallows the next routine and can only make a missing predicate look
    present, which this comment exists so a reader knows to distrust.  The
    fixtures are what prove a gate actually fires."""
    full = os.path.join(root, path)
    if not os.path.exists(full):
        return None
    lines = open(full, encoding="utf-8", errors="replace").read().split("\n")
    if path.endswith(".s"):
        start = re.compile(r"^%s\s" % re.escape(symbol))
        nxt = re.compile(r"^[A-Za-z_@][\w@]*\s+(MX|ENT|EQU)\b")
    else:
        start = re.compile(r"^(?:\w[\w \t*]*?\b)?%s\s*\(" % re.escape(symbol))
        nxt = re.compile(r"^[a-zA-Z_]\w*\s*\(")
    i = None
    for n, l in enumerate(lines):
        if start.match(l):
            i = n
            break
    if i is None:
        return None
    out = [lines[i]]
    for l in lines[i + 1:]:
        if nxt.match(l) and not start.match(l):
            break
        out.append(l)
    return strip_comments("\n".join(out), path)


def check_axis(label, pattern, definitions, registry, predicates, root=ROOT):
    errors = []
    sites = upstream_sites(pattern, definitions, root)
    seen = set()
    counts = {"carried": 0, "stricter": 0, "n/a": 0, "owed": 0}
    owed = []

    for site in sites:
        seen.add(site)
        if site not in registry:
            errors.append(
                "%s:%d is a %s site with no registry entry -- every place "
                "upstream asks permission needs a disposition here (carried / "
                "n/a / owed), or the next one goes unnoticed the way mount(2) "
                "and reboot(2) did" % (site[0], site[1], label))
            continue
        routine, how, detail = registry[site]
        counts[how] = counts.get(how, 0) + 1
        if how == "owed":
            if not ISSUE.search(detail):
                errors.append("%s:%d (%s) is OWED and names no work item: %s"
                              % (site[0], site[1], routine, detail))
            owed.append("%s:%d %s -- %s" % (site[0], site[1], routine, detail))
        elif how == "stricter":
            path, symbol = detail.split("::", 1)
            body = body_of(path, symbol, root)
            if body is None:
                errors.append("%s:%d (%s) is stricter at %s, which has no %s"
                              % (site[0], site[1], routine, path, symbol))
            elif "EPERM" not in body:
                errors.append(
                    "%s:%d (%s) is stricter at %s::%s, but that routine refuses "
                    "nothing -- no EPERM in it" % (site[0], site[1], routine,
                                                   path, symbol))
        elif how == "carried":
            if "::" not in detail:
                errors.append("%s:%d (%s) is carried but names no symbol: %s"
                              % (site[0], site[1], routine, detail))
                continue
            path, symbol = detail.split("::", 1)
            body = body_of(path, symbol, root)
            if body is None:
                errors.append("%s:%d (%s) is carried at %s, which has no %s"
                              % (site[0], site[1], routine, path, symbol))
            elif not any(pr in body for pr in predicates):
                errors.append(
                    "%s:%d (%s) is carried at %s::%s, but that routine asks no "
                    "permission question -- none of %s appears in its code"
                    % (site[0], site[1], routine, path, symbol,
                       "/".join(predicates)))

    for site in sorted(registry):
        if site not in seen:
            errors.append(
                "registry names %s:%d, which is no longer a %s site -- the "
                "vendored tree moved under it" % (site[0], site[1], label))

    return errors, counts, owed


def check(root=ROOT, axes=AXES):
    """[(label, errors, counts, owed)] for each axis."""
    return [(a[0],) + check_axis(*a, root=root) for a in axes]


def self_test():
    """The checker's own red cases, on a scratch tree."""
    import tempfile, shutil
    tmp = tempfile.mkdtemp(prefix="bsdenf-")
    try:
        d = os.path.join(tmp, UPSTREAM)
        os.makedirs(d)
        # one registered site, one unregistered
        open(os.path.join(d, "kern_xxx.c"), "w").write(
            "\n" * 22 + "\tif (suser())\n")
        open(os.path.join(d, "zzz_new.c"), "w").write("\tif (!suser())\n")
        os.makedirs(os.path.join(tmp, "src", "kernel"))
        open(os.path.join(tmp, "src", "kernel", "main.s"), "w").write(
            "_Sys_Reboot     MX      %00\n                JSR     _Suser\n")
        suser_axis = (AXES[0],)
        (_, errs, counts, owed), = check(tmp, suser_axis)
        assert any("zzz_new.c:1" in e and "no registry entry" in e
                   for e in errs), errs
        assert any("no longer a suser() site" in e for e in errs), errs
        assert not any("asks no permission question" in e for e in errs), errs

        # the same tree with the gate removed from the carried routine
        open(os.path.join(tmp, "src", "kernel", "main.s"), "w").write(
            "_Sys_Reboot     MX      %00\n                STA     _rbHowto\n")
        (_, errs2, _, _), = check(tmp, suser_axis)
        assert any("asks no permission question" in e for e in errs2), errs2

        # A MENTION IN A COMMENT IS NOT A CHECK.  This is the case comment
        # stripping exists for: vfs_fchdir's header said "NO VOP_ACCESS" for
        # as long as it had none, and a raw search would have called that a
        # carried check.
        open(os.path.join(tmp, "src", "kernel", "main.s"), "w").write(
            "_Sys_Reboot     MX      %00\n                STA     _rbHowto"
            "   ; would call _Suser if it had one\n")
        (_, errs3, _, _), = check(tmp, suser_axis)
        assert any("asks no permission question" in e for e in errs3), errs3

        # the access axis, same three shapes in one pass
        shutil.rmtree(d)
        os.makedirs(d)
        open(os.path.join(d, "kern_exec.c"), "w").write(
            "\n" * 85 + "\tif (access(ip, IEXEC))\n")
        open(os.path.join(d, "zzz_new.c"), "w").write("\tif (access(ip, IREAD))\n")
        os.makedirs(os.path.join(tmp, "src", "kernel", "vfs"))
        vn = os.path.join(tmp, "src", "kernel", "vfs", "vfs_vnops.c")
        open(vn, "w").write("vn_execchk(vp)\n{\n"
                            "    /* no VOP_ACCESS here */\n    return (0);\n}\n")
        access_axis = (AXES[1],)
        (_, errs4, _, _), = check(tmp, access_axis)
        assert any("zzz_new.c:1" in e and "no registry entry" in e
                   for e in errs4), errs4
        assert any("kern_exec.c:86" in e and "asks no permission question" in e
                   for e in errs4), errs4
        open(vn, "w").write("vn_execchk(vp)\n{\n"
                            "    return (VOP_ACCESS(vp, VEXEC, (char *)0));\n}\n")
        (_, errs5, _, _), = check(tmp, access_axis)
        assert not any("kern_exec.c:86" in e for e in errs5), errs5
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # the real registries must not name an owed entry without an issue
    for registry in (SUSER_REGISTRY, ACCESS_REGISTRY):
        for site, (routine, how, detail) in registry.items():
            if how == "owed":
                assert ISSUE.search(detail), (site, detail)
            assert how in ("carried", "stricter", "n/a", "owed"), (site, how)
    print("check_bsd_enforcement self-test: OK (%d registry rows over %d axes; "
          "red on an unregistered site, on a registry row the tree no longer "
          "has, on a carried routine whose check was deleted, and on one whose "
          "only mention of it is in a comment)"
          % (len(SUSER_REGISTRY) + len(ACCESS_REGISTRY), len(AXES)))
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        return self_test()
    results = check()
    errors = [e for (_, errs, _, _) in results for e in errs]
    if errors:
        print("BSD ENFORCEMENT CHECK FAILED:")
        for e in errors:
            print("  - %s" % e)
        print("Fix: give every 2.11BSD suser() and access() site a disposition "
              "in tools/check_bsd_enforcement.py -- carried (and where), n/a "
              "(and why), or owed (and which work item).")
        return 1
    for label, _, counts, owed in results:
        print("bsd enforcement OK: %d %s site(s) in the vendored 2.11BSD "
              "kernel -- %d carried, %d stricter here, %d not applicable, "
              "%d OWED%s"
              % (sum(counts.values()), label, counts["carried"],
                 counts["stricter"], counts["n/a"], counts["owed"],
                 (":" if owed else "")))
        for o in owed:
            print("    OWED  %s" % o)
    return 0


if __name__ == "__main__":
    sys.exit(main())
