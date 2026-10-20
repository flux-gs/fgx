#!/usr/bin/env python3
"""gen_vfs_equ.py - src/kernel/vfs/fsparam.h -> include/vfs_equ.s

The kernel's assembly has to size the buffer arena it allocates, and the C
header is the authority on that size.  Copying NBUF and FS_BLKSIZE into an
include by hand would make a SECOND copy of a number the C side can change --
the same failure the kernel-C direct page hit, where a literal in the switch
disagreed with the generated slot map and corrupted C state in the victim
rather than the culprit.

So the EQUs are generated.  Change fsparam.h and the assembly follows; there is
no second place to remember.

The names are prefixed VFS_ rather than reusing NBUF, because include/fs.s is
the LEGACY filesystem's header and shares this namespace -- an unprefixed NBUF
would read as a legacy constant to anyone maintaining it.
"""
import re
import sys

# Only the constants the assembly actually needs.  Extracting everything would
# make this a header translator, and a partial one is a liability.
#
# The second group sizes the VFS POOL ARENA -- the vnode pool, the specinfo
# pool and the name cache, carved in that order from one heap allocation the
# assembly makes (see _VfsInit in src/kernel/main.s).  Same reason as the
# buffer arena: storage has no business sitting in the bank the code lands in.
WANTED = ("NBUF", "FS_BLKSIZE", "VNODE_POOL", "NSPECINFO", "NNAMECACHE",
          "VFS_NPROC", "VFS_NDPERPROC", "MAXPATHLEN", "NFILE", "FS_MAX_FDS",
          # IO_NDELAY (vnode.h) is not geometry, and it is here for the same
          # reason everything else is: a chardev's bulk read op is ASSEMBLY in
          # a driver module and learns non-blocking from its `flag' argument,
          # the way Reno's ptcread does (`if (flag & IO_NDELAY) return
          # (EWOULDBLOCK)', kern/tty_pty.c).  Spelling $10 in a module would
          # be a second copy of a C constant, which is the thing this file
          # exists to prevent.
          "IO_NDELAY")

# STRUCT SIZES ARE NOT KNOBS AND ARE NOT GUESSED HERE.  Each is pinned by an
# assertion in toolchain/tests/M37/vfslayout.c, which runs on the machine, so
# a layout change fails there rather than silently resizing this arena:
#
#   sizeof(struct vnode)     == 60 + VN_MAXPRIVATE   vfslayout.c rc 23
#   sizeof(struct specinfo)  == 14                   vfslayout.c rc 56
#   sizeof(struct namecache) == 64                   vfslayout.c rc 65
#   sizeof(struct nameidata) == 154                  vfslayout.c rc 70
#   sizeof(struct file)      == 24                   vfslayout.c rc 72
#
# VN_MAXPRIVATE lives in vnode.h rather than fsparam.h, which is why this
# generator reads two headers.
VNODE_FIXED    = 60     # struct vnode less its v_data tail
SPECINFO_SIZE  = 14
NAMECACHE_SIZE = 64
# 52 until UFS 1.12c, when direnter's requirements landed in the slot: ni_dent
# is an on-disk `struct direct` and its d_name is MAXNAMLEN+1 = 64 bytes, which
# is 70 of the 102 the struct grew by; the rest is the uio and iovec that write
# it, plus ni_offset/ni_count/ni_endoff.  It costs
# VFS_NPROC * VFS_NDPERPROC * 102 = 2,448 bytes of the pool arena, which is
# HEAP and not module bank.  Reno pays the same on every process for the same
# reason -- a directory entry has to be assembled somewhere contiguous, and the
# name field cannot be shorter than a name.
NAMEIDATA_SIZE = 158
FILE_SIZE      = 24
# struct file's FIELD OFFSETS, for the syscall layer's assembly (UFS 1.7d-I2).
# Reno's layout: four shorts, then four 4-byte members.  These are NOT parsed
# out of the header -- fcc decides them -- so they are pinned instead by
# toolchain/tests/M37/vfslayout.c, which asserts every one at RUNTIME against
# the oracle and returns 77..84 if any moves.  A reorder is invisible to the C
# (both sides still say `fp->f_data`) and lethal to the assembly, which is why
# the fixture asserts offsets and not merely sizeof.
FILE_OFFSETS = (
    ("F_FLAG",     0,  "FREAD and/or FWRITE"),
    ("F_TYPE",     2,  "DTYPE_*"),
    ("F_COUNT",    4,  "descriptors referencing this, all procs"),
    ("F_MSGCOUNT", 6,  "always 0 here -- no unix-domain sockets"),
    ("F_CRED",     8,  "struct ucred *; always 0 until 2.6"),
    ("F_OPS",     12,  "struct fileops *, 24-bit: MAY NAME ANOTHER BANK"),
    ("F_DATA",    16,  "the vnode, socket, pipe or FCB this names"),
    ("F_OFFSET",  20,  "the seek pointer this open(2) carries"),
)
# A descriptor is a POINTER to a file struct, not a file struct: the whole
# point of the split is that dup and fork copy this and share that.  4, because
# kernel C pointers are far (see vfslayout.c rc 70's note on the packed
# nameidata layout).
OFILE_PTR_SIZE = 4

# The descriptor FLAGS, Reno's u_pofile: one byte per descriptor (UF_EXCLOSE,
# close-on-exec), carved by finit after the descriptor arrays and indexed the
# same way.
POFILE_SIZE = 1

# struct fileops, in file.h's declared order (Reno's, all five slots carried).
# Every slot is an fcc function pointer, which is 4 bytes wide like every other
# pointer here -- see the note above OFILE_PTR_SIZE.  The CORE bank's legacy
# tables use this same layout deliberately: a descriptor's f_ops is one shape
# whether it names vfs.mod's C `vnops' or a core-bank legacy table, and only
# the bank it points into differs.
FILEOPS_OFFSETS = (
    ("FO_READ",    0,  "fo_read(fp, uio)"),
    ("FO_WRITE",   4,  "fo_write(fp, uio)"),
    ("FO_IOCTL",   8,  "fo_ioctl(fp, com, data)"),
    ("FO_SELECT", 12,  "fo_select(fp, which)"),
    ("FO_CLOSE",  16,  "fo_close(fp)"),
)
FILEOPS_SIZE = 20

DEFINE_RE = re.compile(r"^#define\s+(\w+)\s+(.+?)\s*(?:/\*.*)?$", re.M)

# A define's body may reference constants defined earlier in the same header
# (NSPECINFO is VFS_NMOUNT + 8; NNAMECACHE is VNODE_POOL).  Copying that
# arithmetic here would recreate the second-copy problem this generator exists
# to prevent, so the expressions are EVALUATED against what has been parsed --
# but only over integers, the four operators and parentheses, so a header can
# never make this script execute anything.
SAFE_EXPR = re.compile(r"^[\w\s+\-*/()]+$")


def _resolve(name, raw, defs, seen):
    if name in seen:
        sys.exit(f"gen_vfs_equ: {name} is defined in terms of itself")
    seen = seen | {name}
    expr = raw.strip()
    if not SAFE_EXPR.match(expr):
        sys.exit(f"gen_vfs_equ: {name} = {expr!r} is not a plain integer "
                 f"expression -- this generator will not evaluate it")
    env = {}
    # \b MATTERS: without it a HEX literal scans as an identifier -- `0x10`
    # yields `x10`, and the lookup then reports a constant the headers do not
    # define.  A word boundary cannot occur between the `0` and the `x`, so the
    # literal is left for eval, which reads it as C does.
    for ident in set(re.findall(r"\b[A-Za-z_]\w*", expr)):
        if ident not in defs:
            sys.exit(f"gen_vfs_equ: {name} references {ident}, which the "
                     f"headers do not define")
        env[ident] = _resolve(ident, defs[ident], defs, seen)
    try:
        return int(eval(expr, {"__builtins__": {}}, env))
    except Exception:
        sys.exit(f"gen_vfs_equ: cannot evaluate {name} = {expr!r}")


def parse(*paths):
    defs = {}
    for path in paths:
        with open(path) as f:
            defs.update(dict(DEFINE_RE.findall(f.read())))
    wanted = WANTED + ("VN_MAXPRIVATE",)
    missing = [n for n in wanted if n not in defs]
    if missing:
        sys.exit(f"gen_vfs_equ: {', '.join(paths)} define no "
                 f"{', '.join(missing)} -- was it renamed?")
    return {n: _resolve(n, defs[n], defs, set()) for n in wanted}


def pool_bytes(vals):
    """The one heap allocation vfs.mod's pools are carved from.

    ORDER MATTERS and is the same here and in vfs_init: the vnode pool and the
    specinfo pool first, because vntblinit carves both from one base, then the
    nameidata slots, which ndinit carves from what is left.  A carve that
    disagrees with this sum overlaps whatever follows the allocation.

    THE NAME CACHE IS NOT IN THIS SUM.  It went to ufsdir.mod with
    vfs_cache.c, beside the ufs_lookup.c that is its only caller, and a carve
    cannot be split across banks -- so ufsdir Kmallocs its own and nchinit
    takes that base instead of a pointer into this arena.  It is sized
    separately, by nc_bytes(), and asserted separately in the self-test.
    """
    return (vals["VNODE_POOL"] * (VNODE_FIXED + vals["VN_MAXPRIVATE"])
            + vals["NSPECINFO"] * SPECINFO_SIZE
            + nd_bytes(vals)
            )


def nc_bytes(vals):
    """The name cache's own allocation, ufsdir.mod's since the cache moved.

    One term, and it stays a function rather than an inline product for the
    reason every other size here is one: the self-test transcribes the
    literals independently, so a header change that resizes the pool fails
    there rather than silently under-allocating on the machine.
    """
    return vals["NNAMECACHE"] * NAMECACHE_SIZE


def file_bytes(vals):
    """The open-file table and the per-process descriptor arrays (UFS 1.2c).

    Both, in one number, because finit carves them together -- and they are
    sized by DIFFERENT constants on purpose.  NFILE bounds the machine's open
    files in total; FS_MAX_FDS bounds one process's descriptors, and the arrays
    are deliberately over-subscribed against the table (16 * 30 = 480 possible
    descriptors served by 32 file structs), which is the same shape 2.11BSD
    runs.  Multiplying by the wrong one of the two is the mistake this
    docstring exists to prevent.  The descriptor flag bytes (pofile_pool)
    follow the descriptor arrays and are sized by the same two constants.
    """
    return (vals["NFILE"] * FILE_SIZE
            + vals["VFS_NPROC"] * vals["FS_MAX_FDS"]
            * (OFILE_PTR_SIZE + POFILE_SIZE))


def nd_bytes(vals):
    """The per-process nameidata slots and their PAIRED pathname buffers.

    Both, in one number, because ndinit carves them together and a slot is
    useless without its buffer -- pairing them is what lets namei stop asking
    its caller for one.  Reno keeps only the nameidata per process and mallocs
    the buffer per call; see fsparam.h's VFS_NDPERPROC for why that route is
    not available here and not needed at MAXPATHLEN 128.
    """
    slots = vals["VFS_NPROC"] * vals["VFS_NDPERPROC"]
    return slots * (NAMEIDATA_SIZE + 2 * vals["MAXPATHLEN"])


def check_nproc(vals, cfg="cfg/system.cfg"):
    """VFS_NPROC must equal kernel.nproc, and a comment claiming so is not a
    check.

    EVERY PER-PROCESS VFS POOL IS INDEXED BY PID and pids run 1..NPROC, so a
    VFS_NPROC below NPROC does not shrink a cache -- it denies the HIGHEST pid
    its slot outright, and only that pid.  ndslot returns 0, namei fails, and
    nothing else on the machine notices.

    This exists because it happened: fsparam.h read 11 correctly when it was
    written, kernel.nproc went 11 -> 12 four days later, and the "= 
    CFG_KERNEL_NPROC" comment went on asserting they matched.  Read from
    cfg/system.cfg rather than the generated include/config.s so this does not
    depend on generator ordering.
    """
    import os
    if not os.path.exists(cfg):
        return                      # not the repo root; the build always is
    with open(cfg) as f:
        m = re.search(r"^\s*kernel\.nproc\s*=\s*(\d+)", f.read(), re.M)
    if not m:
        sys.exit(f"gen_vfs_equ: {cfg} defines no kernel.nproc -- was it renamed?")
    nproc = int(m.group(1))
    if vals["VFS_NPROC"] != nproc:
        sys.exit(f"gen_vfs_equ: VFS_NPROC is {vals['VFS_NPROC']} but "
                 f"kernel.nproc is {nproc}.  Pids run 1..{nproc}, so pid "
                 f"{nproc} would get no nameidata slot and no descriptor "
                 f"array.  Fix VFS_NPROC in src/kernel/vfs/fsparam.h.")


def emit(vals, src, out):
    check_nproc(vals)
    nbuf = vals["NBUF"]
    blk = vals["FS_BLKSIZE"]
    pool = pool_bytes(vals)
    vnsz = VNODE_FIXED + vals["VN_MAXPRIVATE"]
    lines = [
        ";==============================================================================",
        f"; vfs_equ.s - GENERATED by tools/gen_vfs_equ.py from {src}",
        "; Do NOT hand-edit.  Change the C header and rebuild.",
        ";",
        "; The buffer cache's geometry, for the assembly that allocates its arena.",
        "; The C header is the authority; these follow it so there is no second copy",
        "; to keep in step.",
        ";==============================================================================",
        f"VFS_NBUF        EQU     {nbuf}          ; buffers in the pool",
        f"VFS_BLKSIZE     EQU     {blk}        ; filesystem block, bytes",
        f"VFS_ARENA_SIZE  EQU     {nbuf * blk}       ; NBUF * FS_BLKSIZE",
        "",
        "; vnode.h's IO_* flags, for driver assembly.  Only the one a bulk chardev",
        "; op actually tests is emitted; the rest have no assembly reader.",
        f"VFS_IO_NDELAY   EQU     {vals['IO_NDELAY']}          ; vnode.h IO_NDELAY",
        "",
        "; The VFS pool arena: the vnode and specinfo pools (vntblinit carves both",
        "; from one base), then the nameidata slots (ndinit).  Storage does not",
        "; belong in the bank the code lands in -- the same reason the buffer arena",
        "; is an argument rather than a static.",
        "; The struct sizes are pinned by toolchain/tests/M37/vfslayout.c, so this",
        "; total cannot drift behind a layout change without that fixture failing.",
        f"VFS_VNODE_SIZE  EQU     {vnsz}         ; 60 + VN_MAXPRIVATE",
        f"VFS_POOL_BYTES  EQU     {pool}      ; vnode {vals['VNODE_POOL']}*{vnsz}"
        f" + specinfo {vals['NSPECINFO']}*{SPECINFO_SIZE}"
        f" + namei {vals['VFS_NPROC']}*{vals['VFS_NDPERPROC']}"
        f"*({NAMEIDATA_SIZE}+2*{vals['MAXPATHLEN']})"
"",
        "",
        "; The name cache's arena, ufsdir.mod's since the cache moved there to sit",
        "; beside ufs_lookup.c -- the only caller of cache_lookup and cache_enter.",
        "; A SEPARATE Kmalloc, not a slice of VFS_POOL_BYTES: the two banks cannot",
        "; share one carve, because the pointer that walks it is DBR-relative.",
        f"NC_POOL_BYTES   EQU     {nc_bytes(vals)}       "
        f"; ncache {vals['NNAMECACHE']}*{NAMECACHE_SIZE}",
        "",
        "; struct file, for the SYSCALL LAYER'S ASSEMBLY (UFS 1.7d-I2).  The C",
        "; and the assembly now read the same descriptor, so the offsets have to",
        "; come from one place -- this is it.",
        ";",
        "; fcc decides these, not the header, so they are not parsed: they are",
        "; PINNED by toolchain/tests/M37/vfslayout.c, which asserts every one at",
        "; runtime against the oracle and returns 77..84 if one moves.  sizeof",
        "; alone would not do it -- a REORDER keeps the size and stays invisible",
        "; to the C, because both sides still spell it `fp->f_data`.",
        f"FILE_SIZE       EQU     {FILE_SIZE}          ; bytes per struct file",
        "",
        "; The FAR KERNEL BANK's static for the file table and the per-process",
        "; descriptor arrays -- UFS 1.7d I2b.  They are no longer carved from",
        "; the VFS pool: Mod_LoadConf opens files through _Fcb_Alloc and it is",
        "; what LOADS vfs.mod, so a table inside that module would not exist",
        "; the first time anything opened a file.  Sized here so the far bank",
        "; has no second copy of the arithmetic finit relies on.",
        f"VFS_FILE_BYTES  EQU     {file_bytes(vals)}        ; NFILE*{FILE_SIZE}"
        f" + {vals['VFS_NPROC']}*{vals['FS_MAX_FDS']}"
        f"*({OFILE_PTR_SIZE}+{POFILE_SIZE})",
        "",
        "; Where finit puts the descriptor arrays inside that static, and how",
        "; wide one slot is -- UFS 1.7d I2c.  The CORE bank reads `struct file'",
        "; directly (a far call per read(2) would be a bank round trip on the",
        "; hottest path there is), so it needs to index ofile_pool itself.",
        "; Emitted rather than multiplied in Merlin so the C's",
        "; `&file_pool[NFILE]' and the assembly's arithmetic cannot drift.",
        f"VFS_OFILE_OFF   EQU     {vals['NFILE'] * FILE_SIZE}        "
        f"; ofile_pool - arena = NFILE*{FILE_SIZE}",
        f"VFS_OFILE_PTR   EQU     {OFILE_PTR_SIZE}           "
        f"; bytes per descriptor slot",
        "; pofile_pool, the descriptor flag bytes (Reno's u_pofile), follows",
        "; the descriptor arrays: this far past ofile_pool, one byte a slot.",
        f"VFS_POFILE_OFF  EQU     "
        f"{vals['VFS_NPROC'] * vals['FS_MAX_FDS'] * OFILE_PTR_SIZE}        "
        f"; VFS_NPROC*FS_MAX_FDS*{OFILE_PTR_SIZE}",
    ] + [
        f"{name:<15} EQU     {off:<11} ; {note}"
        for name, off, note in FILE_OFFSETS
    ] + [
        "",
        "; struct fileops -- what a descriptor can be asked to do (file.h).",
        "; The CORE bank builds legacy tables in this layout so that f_ops is",
        "; ONE shape whether it names vfs.mod's C `vnops' or a core-bank table;",
        "; only the bank it points into tells them apart.",
        f"FILEOPS_SIZE    EQU     {FILEOPS_SIZE}          ; bytes per struct fileops",
    ] + [
        f"{name:<15} EQU     {off:<11} ; {note}"
        for name, off, note in FILEOPS_OFFSETS
    ] + [
        "",
    ]
    text = "\n".join(lines)
    try:
        if open(out).read() == text:
            return          # restat: do not touch the file, do not relink
    except IOError:
        pass
    with open(out, "w") as f:
        f.write(text)
    print(f"gen_vfs_equ: wrote {out} "
          f"(NBUF={nbuf}, FS_BLKSIZE={blk}, arena={nbuf * blk} B)")


# EVERY NAME IN `WANTED` MUST APPEAR HERE, and that is the fixture's whole
# job: parse() exits when a wanted constant is missing, so a header short of
# one makes selftest() die before it asserts anything.  That is not
# hypothetical -- 1.2b added VFS_NPROC, VFS_NDPERPROC and MAXPATHLEN to WANTED
# without adding them here, and because nothing invoked --selftest the failure
# sat unnoticed until 1.2c.  The kchecks rule now runs it.
FULL_HEADER = ("#define NBUF 4\n"
               "#define FS_BLKSIZE 256\n"
               "#define VFS_NMOUNT 14\n"
               "#define VNODE_POOL 32\n"
               "#define NSPECINFO (VFS_NMOUNT + 8)\n"
               "#define NNAMECACHE VNODE_POOL\n"
               "#define VN_MAXPRIVATE 104\n"
               "#define VFS_NPROC 11\n"
               "#define VFS_NDPERPROC 2\n"
               "#define MAXPATHLEN 128\n"
               "#define NFILE 32\n"
               "#define FS_MAX_FDS 30\n"
               # HEX ON PURPOSE, because the real one is: vnode.h spells
               # IO_NDELAY 0x10, and the identifier scan used to read that as a
               # constant named `x10' and stop the build.  A decimal fixture
               # would pass over the bug.
               "#define IO_NDELAY 0x10\n")


def _write(text):
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".h", delete=False) as f:
        f.write(text)
        return f.name


def _expect_exit(text, what, rc_box):
    import os
    path = _write(text)
    try:
        parse(path)
        print(f"SELFTEST FAIL: {what} was accepted", file=sys.stderr)
        rc_box[0] = 1
    except SystemExit:
        pass
    os.unlink(path)


def selftest():
    """The arena size must be the PRODUCT; derived defines must be FOLLOWED,
    not re-implemented; and anything this script cannot safely evaluate must
    stop the build rather than be guessed at."""
    import os
    rc = [0]
    good = _write(FULL_HEADER)
    vals = parse(good)
    os.unlink(good)

    if vals["NBUF"] * vals["FS_BLKSIZE"] != 1024:
        print("SELFTEST FAIL: product wrong", file=sys.stderr)
        rc[0] = 1
    # NSPECINFO and NNAMECACHE are EXPRESSIONS in the real header.  If this
    # script ever stops evaluating them and starts assuming numbers, the arena
    # silently shrinks -- which is corruption at a distance, so it is asserted.
    if vals["NSPECINFO"] != 22:
        print(f"SELFTEST FAIL: NSPECINFO resolved to {vals['NSPECINFO']}, "
              f"expected 22 (VFS_NMOUNT + 8)", file=sys.stderr)
        rc[0] = 1
    # A HEX LITERAL RESOLVES, and it is asserted rather than assumed: the
    # identifier scan matched `x10' out of `0x10' until the pattern gained a
    # word boundary, and every constant this generator carries today except
    # this one is decimal, so nothing else would catch a regression.
    if vals["IO_NDELAY"] != 16:
        print(f"SELFTEST FAIL: IO_NDELAY resolved to {vals['IO_NDELAY']}, "
              f"expected 16 (0x10)", file=sys.stderr)
        rc[0] = 1
    if vals["NNAMECACHE"] != 32:
        print(f"SELFTEST FAIL: NNAMECACHE resolved to {vals['NNAMECACHE']}, "
              f"expected 32 (= VNODE_POOL)", file=sys.stderr)
        rc[0] = 1
    # EVERY NUMBER HERE IS A LITERAL, and that is the point rather than a
    # style: written as `32 * FILE_SIZE` this compares the constant against
    # ITSELF, so shrinking FILE_SIZE to 20 -- a dropped struct field, the exact
    # thing this guards -- changes both sides and passes.  That was measured,
    # not imagined: the first cut of this line used the symbols and the
    # mutation went green.  The literals are transcribed from the struct sizes
    # at the head of this file, which vfslayout.c pins on the machine.
    #
    # vnode + specinfo + namei slots with their buffers.
    #
    # THE FILE TABLE IS NOT IN THIS SUM ANY MORE (UFS 1.7d I2b).  It and the
    # per-process descriptor arrays moved to the FAR KERNEL BANK, because
    # Mod_LoadConf opens files through _Fcb_Alloc and Mod_LoadConf is what
    # loads vfs.mod -- a table carved by that module cannot exist the first
    # time anything opens a file.  They are sized separately now, by
    # file_bytes(), and asserted separately just below.
    want = (32 * 164 + 22 * 14
            + 11 * 2 * (158 + 2 * 128))
    if pool_bytes(vals) != want:
        print(f"SELFTEST FAIL: pool arena {pool_bytes(vals)}, expected {want}",
              file=sys.stderr)
        rc[0] = 1

    # The name cache's own arena, ufsdir.mod's: 32 entries of 64 bytes.
    # Transcribed rather than computed, for the reason the sum above is.
    want_nc = 32 * 64
    if nc_bytes(vals) != want_nc:
        print(f"SELFTEST FAIL: name cache arena {nc_bytes(vals)}, "
              f"expected {want_nc}", file=sys.stderr)
        rc[0] = 1

    # The far bank's static, by the same literal-transcription rule: 32 file
    # structs of 24 bytes, plus 11 processes' worth of 30 four-byte descriptors
    # and their 30 one-byte flags.
    want_file = 32 * 24 + 11 * 30 * 4 + 11 * 30 * 1
    if file_bytes(vals) != want_file:
        print(f"SELFTEST FAIL: file table {file_bytes(vals)}, "
              f"expected {want_file}", file=sys.stderr)
        rc[0] = 1

    _expect_exit("#define NBUF 4\n", "a missing constant", rc)
    _expect_exit(FULL_HEADER.replace("#define VFS_NMOUNT 14\n", ""),
                 "a define referencing an unknown constant", rc)
    _expect_exit(FULL_HEADER.replace("#define VNODE_POOL 32",
                                     '#define VNODE_POOL open("x")'),
                 "a non-arithmetic define", rc)
    _expect_exit(FULL_HEADER.replace("#define NNAMECACHE VNODE_POOL",
                                     "#define NNAMECACHE NNAMECACHE"),
                 "a self-referential define", rc)

    if rc[0] == 0:
        print("gen_vfs_equ selftest: OK")
    return rc[0]


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--selftest":
        sys.exit(selftest())
    if len(sys.argv) != 4:
        sys.exit("usage: gen_vfs_equ.py <fsparam.h> <vnode.h> <out.s> "
                 "| --selftest")
    srcs = sys.argv[1:3]
    emit(parse(*srcs), " + ".join(srcs), sys.argv[3])
