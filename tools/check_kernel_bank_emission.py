#!/usr/bin/env python3
"""check_kernel_bank_emission.py - fcc --kernel-bank emits what it claims to.

WHY THIS IS NOT AN M37 FIXTURE.  The fcc fixture suite builds FGX2 userland
binaries, and --kernel-bank is meaningless there -- an FGX2 binary HAS a linker
and a loader, so FGX2_LONG_PTR is the correct macro and the goldens rightly
contain it.  The mode this checks exists only for the far kernel bank, which no
fixture can produce.  That gap is exactly how apple/fgx#88 survived: the
construct was correct everywhere anything looked.

So the coverage is here instead, and it is a COMPILER test rather than a
runtime one: compile a source that contains every shape of &function a data
initialiser can hold, and assert the emitted form.  Two directions, because a
one-sided check cannot tell "the flag works" from "the flag does nothing":

    with    --kernel-bank   ->  KFAR_FN_PTR, and the call READS the bank byte
    with    --module-bank   ->  MOD_FN_PTR,  and the call READS the bank byte
    without either          ->  FGX2_LONG_PTR, and the call reads a bank byte

Both single-bank modes carry the apple/fgx#178 DBR bracket; an ordinary build
must not.  The two cell names differ because different code stamps them --
Far_BankInit and Tty_BankInit for KFAR_FN_PTR, _Mod_StampFnPtrs for MOD_FN_PTR
-- and a listing scan has only the name to tell which image a cell is in.

The last is what makes the others meaningful.  It also pins the promise that
the flags change NOTHING for an ordinary build -- the whole fixture suite
depends on that, and 568 goldens would be a slow way to find out otherwise.

THE --module-bank ARM IS apple/fgx#173, and it is here rather than in a fixture
for the same reason as the first: no FGX2 binary can produce an FGXM module.
Taking the bank from PHK made a vnode's v_op dispatch land at the target's
offset in the CALLER's bank, and both fcc arms agreed with each other, so
nothing saw it until UFS moved to a bank of its own.

THE --kernel-bank ARM TOOK ITS BANK FROM PHK TOO, on the grounds that the far
bank's own cells had no bank byte anything could write.  That made every
pointer into a module -- mp->mnt_op, v_op -- uncallable from the far bank, and
every such call had to cross into vfs.mod first, one seam hop deeper on a
512-byte kernel stack.  The cells ARE writable: Far_BankInit and Tty_BankInit
run in their image before any C and PHK yields the bank there, exactly as it
does in mod_init.
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FCC = os.path.join(ROOT, "toolchain", "fcc")

# Every shape a &function can reach a data initialiser through.  Each one is a
# separate emission path in emit.c, and the campaign's recorded defects live in
# exactly this area -- far function pointers in a DATA INITIALIZER, and struct
# fn-ptr field offsets past 120 bytes.
SRC = r"""
int op_a() { return 1; }
int op_b() { return 2; }
static int op_c() { return 3; }

/* scalar */
int (*g_scalar)() = op_a;

/* array -- the ops-vector shape */
int (*g_vec[3])() = { op_a, op_b, op_c };

/* struct field */
struct ops { int (*f1)(); int (*f2)(); };
struct ops g_struct = { op_a, op_b };

/* array of structs, so the cell is not at offset 0 */
struct ops g_structs[2] = { { op_a, op_b }, { op_b, op_a } };

/* runtime address-of: a hidden data cell plus a load */
int (*g_runtime)();

int take(fp) int (*fp)(); { return (*fp)(); }

int driver()
{
    int (*local)();

    g_runtime = op_b;
    /* Indirect calls -- what the bank byte would have been read by.  Spelled
     * (*p)() because that is the form fcc parses; a bare p() does not, and
     * neither does (*s.field)() through a dot member. */
    local = g_struct.f1;
    return ((*g_scalar)() + (*g_vec[1])() + (*local)() + take(op_c));
}
"""


def compile_src(tmpdir, kernel_bank, module_bank=False):
    src = os.path.join(tmpdir, "kb.c")
    out = os.path.join(tmpdir, "kb.s")
    with open(src, "w") as f:
        f.write(SRC)
    cmd = [FCC, "-fno-safepoints", "--pile"]
    if module_bank:
        cmd.append("--module-bank")
    elif kernel_bank:
        cmd.append("--kernel-bank")
    cmd += [src, "-o", out]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        print(f"check_kernel_bank_emission: cannot run fcc: {e}",
              file=sys.stderr)
        return None, None
    if r.returncode != 0:
        print(f"check_kernel_bank_emission: fcc failed: {r.stderr}",
              file=sys.stderr)
        return None, None
    with open(out) as f:
        code = f.read()
    with open(out[:-2] + ".data.s") as f:
        data = f.read()
    return code, data


# THE BANK LOAD MUST BE LOOKED FOR INSIDE THE CALL TRAMPOLINE, not anywhere in
# the file.  `LDA _fcc_fprN+2` also appears whenever a 4-byte pointer VALUE is
# copied -- assigning a fn ptr to a local reads its bank byte and that is
# correct in either mode.  A file-wide search calls those a failure, which is
# how the first draft of this check reported a defect that was not there.
#
# The trampoline is anchored by its return-address push and closed by the DEC
# that turns the target offset into offset-1 for RTL:
#
#     PHK / PEA <tu>_L<n>-1 / <TARGET BANK> / LDA <fpr> / DEC / PHA / RTL
#
# and <TARGET BANK> is exactly what this fix changes.
TRAMPOLINE_RE = re.compile(
    r"PEA\s+\S+_L\d+-1\n(?P<mid>(?:.*\n)*?)\s*DEC\n", re.M)
FPR_BANK_LOAD_RE = re.compile(r"LDA\s+_fcc_fpr\d+\+2")

# apple/fgx#178.  The DBR BRACKET around a module's indirect call: the target's
# bank reaches DBR as well as the RTL frame, and the caller's DBR comes back
# from PHK at the return label.  Without the first half the callee reads its own
# globals, literals and cross-module import table in the CALLER's bank; without
# the second the caller carries on in the callee's.
DBR_SET_RE  = re.compile(r"LDA\s+_fcc_fpr\d+\+2\n\s*PHA\n\s*PLB\n")
DBR_BACK_RE = re.compile(r"\n\S+_L\d+\n\s*PHK\n\s*PLB\n")


def dbr_brackets(code):
    """(n_trampolines, n_with_the_DBR_set, n_return_labels_restoring_DBR)."""
    n = setn = 0
    for m in TRAMPOLINE_RE.finditer(code):
        n += 1
        if DBR_SET_RE.search(m.group("mid")):
            setn += 1
    return n, setn, len(DBR_BACK_RE.findall(code))


def call_banks(code):
    """(n_from_phk, n_from_pointer) over every indirect-call trampoline."""
    phk = ptr = 0
    for m in TRAMPOLINE_RE.finditer(code):
        mid = m.group("mid")
        if FPR_BANK_LOAD_RE.search(mid):
            ptr += 1
        elif "PHK" in mid:
            phk += 1
    return phk, ptr


def check():
    rc = 0
    with tempfile.TemporaryDirectory() as d:
        kb_code, kb_data = compile_src(d, True)
        fg_code, fg_data = compile_src(d, False)
        mb_code, mb_data = compile_src(d, False, module_bank=True)
    if kb_code is None or fg_code is None or mb_code is None:
        return 1

    # --- with the flag -------------------------------------------------
    n_kfar = kb_data.count("KFAR_FN_PTR")
    if n_kfar == 0:
        print("check_kernel_bank_emission: --kernel-bank emitted NO "
              "KFAR_FN_PTR cells", file=sys.stderr)
        rc = 1
    for macro in ("FGX2_LONG_PTR", "LIBC_DATA_PTR"):
        if macro in kb_data:
            print(f"check_kernel_bank_emission: --kernel-bank still emitted "
                  f"{macro}, which nothing resolves in the far bank",
                  file=sys.stderr)
            rc = 1
    kb_phk, kb_ptr = call_banks(kb_code)
    if kb_phk:
        print(f"check_kernel_bank_emission: --kernel-bank: {kb_phk} indirect "
              f"call(s) take the target bank from PHK -- a far-bank call "
              f"through a pointer into a module lands in the far bank",
              file=sys.stderr)
        rc = 1
    if kb_ptr == 0:
        print("check_kernel_bank_emission: --kernel-bank: no indirect call "
              "trampoline found at all -- the source no longer covers one",
              file=sys.stderr)
        rc = 1

    # --- --module-bank: a REAL bank byte, and a call that reads it -----
    n_mod = mb_data.count("MOD_FN_PTR")
    if n_mod == 0:
        print("check_kernel_bank_emission: --module-bank emitted NO "
              "MOD_FN_PTR cells", file=sys.stderr)
        rc = 1
    if "KFAR_FN_PTR" in mb_data:
        print("check_kernel_bank_emission: --module-bank emitted KFAR_FN_PTR, "
              "whose bank byte gen_mod_bankpatch.py will not stamp -- every "
              "dispatch through such a cell targets bank 0", file=sys.stderr)
        rc = 1
    for macro in ("FGX2_LONG_PTR", "LIBC_DATA_PTR"):
        if macro in mb_data:
            print(f"check_kernel_bank_emission: --module-bank still emitted "
                  f"{macro}, which nothing resolves in a module",
                  file=sys.stderr)
            rc = 1
    mb_phk, mb_ptr = call_banks(mb_code)
    if mb_phk:
        print(f"check_kernel_bank_emission: --module-bank: {mb_phk} indirect "
              f"call(s) STILL take the target bank from PHK -- that is the "
              f"caller's bank, so a vnode op stored by one module and "
              f"dispatched by another lands in the wrong image (apple/fgx#173)",
              file=sys.stderr)
        rc = 1
    if mb_ptr == 0:
        print("check_kernel_bank_emission: --module-bank: no indirect call "
              "trampoline found at all -- the source no longer covers one",
              file=sys.stderr)
        rc = 1

    # THE BANK MUST REACH DBR TOO (apple/fgx#178).  #173 made the pointer name
    # the right function; this is what makes calling it run in the right bank.
    # fcc reads every global, literal and runtime scratch DBR-relatively, so a
    # callee entered with the caller's DBR reads its own data at the right
    # offsets in the wrong image and returns plausible garbage -- which is how
    # ufs.mod's ufs_reclaim, dispatched by vfs.mod, read vfs.mod's bank.
    # BOTH SINGLE-BANK MODES: in each, DBR is the program bank -- a module's
    # mod_init and every far- and tty-bank entry do PHK/PLB -- so the bracket's
    # PHK/PLB restore is exact.
    for name, code in (("--module-bank", mb_code), ("--kernel-bank", kb_code)):
        n_tramp, n_set, n_back = dbr_brackets(code)
        if n_set != n_tramp:
            print(f"check_kernel_bank_emission: {name}: {n_tramp - n_set} of "
                  f"{n_tramp} indirect call(s) do not put the target's bank in "
                  f"DBR -- the callee will read its own globals in the caller's "
                  f"bank (apple/fgx#178)", file=sys.stderr)
            rc = 1
        if n_back < n_tramp:
            print(f"check_kernel_bank_emission: {name}: {n_tramp - n_back} "
                  f"indirect call(s) never restore the caller's DBR (PHK/PLB at "
                  f"the return label), so the caller carries on in the callee's "
                  f"bank", file=sys.stderr)
            rc = 1
    # ...AND MUST NOT LEAK.  In an ordinary FGX2 build DBR is the DATA bank and
    # not the program bank, so the same bracket would be actively wrong.
    t, s, b = dbr_brackets(fg_code)
    if s or b:
        print(f"check_kernel_bank_emission: an ordinary build emitted the #178 "
              f"DBR bracket ({s} set, {b} restore) -- DBR is the data bank there "
              f"and PHK/PLB would corrupt it", file=sys.stderr)
        rc = 1
    # The two single-bank modes must name their cells differently, or no
    # listing scan can tell which image stamps which.
    if mb_data == kb_data:
        print("check_kernel_bank_emission: --module-bank data is identical to "
              "--kernel-bank's -- the cell names no longer say who stamps them",
              file=sys.stderr)
        rc = 1

    # --- without it, NOTHING may change --------------------------------
    if "KFAR_FN_PTR" in fg_data:
        print("check_kernel_bank_emission: an ordinary build emitted "
              "KFAR_FN_PTR -- the flag is leaking into FGX2 output",
              file=sys.stderr)
        rc = 1
    if "FGX2_LONG_PTR" not in fg_data:
        print("check_kernel_bank_emission: an ordinary build stopped emitting "
              "FGX2_LONG_PTR -- either the source no longer covers &function "
              "in a data initialiser, or FGX2 output regressed",
              file=sys.stderr)
        rc = 1
    fg_phk, fg_ptr = call_banks(fg_code)
    if fg_ptr == 0:
        print("check_kernel_bank_emission: an ordinary build no longer takes "
              "the target bank from the pointer on an indirect call -- a "
              "multi-bank call would go to the wrong bank", file=sys.stderr)
        rc = 1

    # The two must actually DIFFER, or both halves above could be vacuous.
    if kb_data == fg_data:
        print("check_kernel_bank_emission: --kernel-bank changed nothing",
              file=sys.stderr)
        rc = 1

    if rc == 0:
        print(f"check_kernel_bank_emission: OK ({n_kfar} KFAR_FN_PTR cells "
              f"and {kb_ptr} pointer-banked call(s) with --kernel-bank; "
              f"{n_mod} MOD_FN_PTR cells and {mb_ptr} pointer-banked call(s) "
              f"with --module-bank; "
              f"FGX2_LONG_PTR and {fg_ptr} pointer-banked call(s) without them)")
    return rc


def selftest():
    """The checker must fail when handed output that lacks the property.

    A checker that cannot go red reads as a clean bill of health -- the trap
    this project has hit more than once, most recently as apple/fgx#88 itself.
    """
    global FCC
    saved = FCC
    FCC = os.path.join(HERE, "does-not-exist")
    got = check()
    FCC = saved
    if got == 0:
        print("SELFTEST FAIL: check() passed with no compiler", file=sys.stderr)
        return 1
    print("check_kernel_bank_emission selftest: OK (red when it cannot "
          "compile)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--selftest":
        sys.exit(selftest())
    sys.exit(check())
