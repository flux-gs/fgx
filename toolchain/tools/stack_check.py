#!/usr/bin/env python3
"""Static n,S-vs-depth checker for fcc hardware-stack output (P3-3 3.1b).

fcc addresses C locals/params on the bank-0 HARDWARE stack as `n,S`.  The `n`
displacement is S-relative, so it must fold in `g_s_delta` — the compiler's
running count of bytes it has pushed below the frame base at that point in an
expression.  A latent `g_s_delta` maintenance bug bakes the wrong displacement
and reads a NEIGHBOURING slot; that frequently still yields a correct-looking
exit code, so the runtime oracle waves it through.  This checker is the real
net: it independently re-derives the stack depth at every instruction and
cross-checks it against ground truth the compiler emits.

Two independent models of the stack, differenced:
  1. THE TRACKER — walk the asm, tracking `depth` (bytes pushed below the frame
     base) through PHA/PHX/PHY/PEI/PEA/PHB/PHD/PLx and the reserve/release
     idioms `TSC/SEC/SBC #n/TCS` (+n) and `TSC/CLC/ADC #n/TCS` (-n), honouring
     SEP/REP #$20/#$10 push widths, with verifier-style label-join: every path
     reaching a label must agree on depth.
  2. GROUND TRUTH — each converted slot access carries a byte-neutral Merlin
     comment `; fccstk d=<g_s_delta> b=<base>` (b = the delta-free slot offset;
     `fs` flag = a param, whose operand also carries +<fn>_FRAMESIZE).

Per annotated access the checker asserts:
  (i)  d == tracker depth          -> catches the g_s_delta maintenance bug,
                                       INCLUDING the balanced-stack variant the
                                       oracle and a pure bounds-check both miss.
  (ii) operand == b + d (+FRAMESIZE for a param)  -> catches format/`extra` bugs.

Plus checks that need no annotation (sharp, free):
  - underflow: every n,S operand >= 1;
  - return-address band: NO operand in [depth+FS+1 .. depth+FS+5] (the saved-FP
    word + the JSL return address) — an access there is a return-addr clobber;
  - balance: recognized epilogue teardown is reached at depth 0.

Plus a P3-3 3.3 forbidden-token guard (see _FORBIDDEN): the soft stack is gone,
so `_fcc_ssp` (its old pointer name), `_fcc_fb+<n>` (the freed frame-base bank
byte/pad), and `[_fcc_fb]` (indirect through the frame base) must never reappear
in checked output — each is a resurrection of a deleted mechanism and a silent
garbage-bank hazard the assembler would happily build.

Fails CLOSED: an unmodeled stack mnemonic (PLP, a stray TCS, PHD/PLD if not
modelled) is an error, not a silent skip — a checker that guesses is theatre.

Usage:
  stack_check.py <file.s | dir> ...     # check goldens / userland .s
  stack_check.py --self-test            # built-in red/green cases
Exit 0 = all clean; 1 = violation(s); 2 = usage error.
"""
import os
import re
import sys

# ---- line lexing -----------------------------------------------------------
# A label starts in column 0 (optionally `label  MNEM ...` on one line, Merlin
# style).  An instruction line is indented.  EQUs define FRAMESIZE / STKGUARD.
LABEL_RE = re.compile(r"^([A-Za-z_.][A-Za-z0-9_.]*)\b")
EQU_RE   = re.compile(r"^([A-Za-z_.][A-Za-z0-9_.]*)\s+EQU\s+(.+?)\s*$")
# operand + optional `; comment`.  Merlin comments start with `;` or `*`.
INSN_RE  = re.compile(r"^\s+([A-Za-z][A-Za-z0-9]*)\b\s*(.*?)\s*$")
ANNOT_RE = re.compile(r";\s*fccstk\s+d=(-?\d+)\s+b=(-?\d+)(\s+fs)?")
# `; fccstk pops=N` on a JSL: the callee pops N pushed arg bytes itself
# (Pascal-convention IIgs toolbox calls, e.g. WriteTimeHex via $E10000).
# Without this the checker sees the pushes and never their pulls.
POPS_RE  = re.compile(r";\s*fccstk\s+pops=(\d+)")

# n,S operand: `<expr>,S`  (expr = sum of ints and <fn>_FRAMESIZE terms)
NS_RE    = re.compile(r"^(.*?),[sS]$")

PUSH2 = {"PEI", "PEA"}                       # always 2 bytes
PULL1 = {"PLB", "PLP"}
PUSH1 = {"PHB", "PHP", "PHK"}
PUSH2D = {"PHD"}                             # direct-page push: always 2
PULL2D = {"PLD"}
# width-sensitive (M for A, X-flag for X/Y):
PHA = {"PHA"}
PLA = {"PLA"}
PHXY = {"PHX", "PHY"}
PLXY = {"PLX", "PLY"}
# stack mnemonics we DON'T model -> fail closed if seen outside a template:
UNMODELED_STACK = {"TXS", "TCS", "TSC"}   # PHD/PLD modeled (+2/-2) since H2 serinfo

SLOT_MNEM = {"LDA", "STA", "ORA", "AND", "EOR", "ADC", "SBC", "CMP",
             "LDX", "STX", "LDY", "STY", "STZ", "BIT"}
UNCOND = {"BRA", "JMP", "JML", "RTL", "RTS", "RTI"}
COND_BR = {"BCC", "BCS", "BEQ", "BNE", "BMI", "BPL", "BVC", "BVS"}


class Violation(Exception):
    pass


class Fn:
    __slots__ = ("name", "lines", "framesize", "guard")

    def __init__(self, name):
        self.name = name
        self.lines = []        # list of (lineno, raw)
        self.framesize = None
        self.guard = None


def split_functions(path):
    """Yield (Fn) per `name ENT ... ` block; collect trailing EQUs into it."""
    fns = []
    cur = None
    equs = {}
    with open(path) as f:
        raw_lines = f.readlines()
    # First pass: harvest EQUs (they can trail the body).
    for raw in raw_lines:
        m = EQU_RE.match(raw)
        if m:
            equs[m.group(1)] = m.group(2)
    # Second pass: carve functions.
    for i, raw in enumerate(raw_lines, 1):
        stripped = raw.rstrip("\n")
        lab = LABEL_RE.match(stripped)
        if lab and re.search(r"\bENT\b", stripped):
            cur = Fn(lab.group(1))
            fns.append(cur)
            continue
        if cur is not None:
            cur.lines.append((i, stripped))
    for fn in fns:
        fs = equs.get(fn.name + "_FRAMESIZE")
        fn.framesize = int(fs) if fs is not None and fs.isdigit() else None
        fn.guard = equs.get(fn.name + "_STKGUARD")
    return fns, equs


def eval_operand(expr, equs, framesize):
    """Evaluate an n,S displacement expression to (int_value, has_framesize).

    Terms are `+`-separated ints or `<fn>_FRAMESIZE` symbols.  Returns None if
    a symbol can't be resolved (caller treats as un-checkable)."""
    has_fs = False
    total = 0
    for term in expr.split("+"):
        term = term.strip()
        if not term:
            continue
        if term.isdigit():
            total += int(term)
        elif term.endswith("_FRAMESIZE"):
            has_fs = True
            v = equs.get(term)
            if v is None or not v.isdigit():
                return None
            total += int(v)
        else:
            return None            # unknown symbol -> un-checkable
    return (total, has_fs)


def check_fn(fn, equs, path):
    """Run the depth tracker + cross-checks over one function.  Raises
    Violation on the first inconsistency (with file:line context)."""
    fs = fn.framesize
    depth = 0                 # bytes pushed below frame base; 0 at frame base
    m8 = False                # SEP #$20 in effect (A is 8-bit)
    x8 = False                # SEP #$10 in effect (X/Y 8-bit)
    started = False           # past the prologue TCS?
    dead = False              # unreachable until next label (after uncond jump)
    label_depth = {}          # label -> depth on entry
    pending = {}              # forward-branch target -> expected depth

    lines = fn.lines
    n = len(lines)
    idx = 0
    do_stack = []             # conditional-assembly: [entry_depth, do_arm_exit]

    def err(lineno, msg):
        raise Violation(f"{path}:{lineno}: {fn.name}: {msg} (depth={depth})")

    # locate prologue TCS (`<name>_stkok TCS` or a bare `TCS` right after the
    # SBC #FRAMESIZE); everything up to and including it is frame setup.
    while idx < n:
        lineno, raw = lines[idx]
        if re.search(r"\bTCS\b", raw):
            # first TCS = prologue frame allocation
            started = True
            idx += 1
            break
        idx += 1
    if not started:
        return   # no frame (e.g. a naked data block) — nothing to check

    while idx < n:
        lineno, raw = lines[idx]
        idx += 1
        # strip trailing comment for mnemonic parsing, keep raw for annotation
        code = raw.split(";", 1)[0].rstrip()

        # label in column 0?
        lab = LABEL_RE.match(code)
        if lab and not code[:1].isspace():
            name = lab.group(1)
            # EQU / ENT terminators end the function body
            rest = code[lab.end():]
            if re.search(r"\bEQU\b", rest):
                break
            # the shared epilogue tail of a function holding callee-saved
            # band words: its returns free the frame and branch here to pull
            # the band and _fcc_fb, as an inline teardown does
            if name == fn.name + "_bandx":
                dead = True
                continue
            incoming = None if dead else depth
            exp = pending.pop(name, None)
            prior = label_depth.get(name)
            cands = [d for d in (incoming, exp, prior) if d is not None]
            if not cands:
                depth = 0            # dead label, no info; reset conservatively
            else:
                if len(set(cands)) != 1:
                    err(lineno, f"label {name} depth-join mismatch {sorted(set(cands))}")
                depth = cands[0]
            label_depth[name] = depth
            dead = False
            # a label line may also carry an instruction after it (Merlin)
            code2 = rest.strip()
            if not code2:
                continue
            m = re.match(r"([A-Za-z][A-Za-z0-9]*)\b\s*(.*)$", code2)
            if not m:
                continue
            mnem, operand = m.group(1).upper(), m.group(2).strip()
        else:
            mi = INSN_RE.match(code)
            if not mi:
                continue
            mnem, operand = mi.group(1).upper(), mi.group(2).strip()

        # ---- conditional assembly DO/ELSE/FIN (mutually-exclusive arms) ----
        # Both arms are walked from the same entry depth and must exit equal;
        # this models the param far-fallback (DO far-ptr ... ELSE n,S ... FIN)
        # and any A-preserving PHA/PLA-balanced far store arm.
        if mnem == "DO":
            do_stack.append([depth, None])
            continue
        if mnem == "ELSE":
            if not do_stack:
                err(lineno, "ELSE without DO")
            do_stack[-1][1] = depth          # record DO-arm exit depth
            depth = do_stack[-1][0]           # reset to block entry for ELSE arm
            dead = False
            continue
        if mnem == "FIN":
            if not do_stack:
                err(lineno, "FIN without DO")
            entry, do_exit = do_stack.pop()
            if do_exit is None:               # DO ... FIN (no ELSE): depth-neutral
                if depth != entry:
                    err(lineno, f"DO-only block changed depth {entry}->{depth}")
                depth = entry
            else:                             # DO ... ELSE ... FIN: arms must match
                if depth != do_exit:
                    err(lineno, f"DO/ELSE arms exit at unequal depth "
                                f"{do_exit} vs {depth}")
                depth = do_exit
            dead = False
            continue

        if dead:
            # unreachable code between an uncond jump and the next label; skip
            continue

        # ---- width tracking ----
        if mnem == "SEP":
            if "$20" in operand: m8 = True
            if "$10" in operand: x8 = True
            continue
        if mnem == "REP":
            if "$20" in operand: m8 = False
            if "$10" in operand: x8 = False
            continue

        # ---- TSC: reads S into A.  Depth-neutral UNLESS it forms a
        # `TSC/SEC/SBC #n/TCS` (reserve, +n) or `TSC/CLC/ADC #n/TCS` (release,
        # -n) window that writes S back.  A lone TSC (far-ptr / _fcc_fpr address
        # calc: TSC/CLC/ADC #off/STA _fcc_fp) does NOT move S — no-op it. ----
        if mnem == "TSC":
            win = [raw]
            j = idx
            while j < n and len(win) < 8:
                win.append(lines[j][1])
                j += 1
            joined = " ".join(w.split(";", 1)[0] for w in win)

            def _past_tcs():
                """Advance idx to just past the TCS that closes this idiom."""
                k = idx
                while k < n and not re.search(r"\bTCS\b",
                                              lines[k][1].split(";", 1)[0]):
                    k += 1
                return k + 1

            mrel = re.match(r"\s*TSC\s+CLC\s+ADC\s+#(\S+)\s+TCS", joined)
            mres = re.match(r"\s*TSC\s+SEC\s+SBC\s+#(\S+)\s+TCS", joined)
            # Cheap small ±S adjust: TSC/INC.../TCS raises S (release, -k depth);
            # TSC/DEC.../TCS lowers S (reserve, +k) — the peephole's alternative
            # to CLC/ADC for a 1-2 byte arg cleanup after an indirect call.
            minc = re.match(r"\s*TSC((?:\s+INC)+)\s+TCS", joined)
            mdec = re.match(r"\s*TSC((?:\s+DEC)+)\s+TCS", joined)
            if mrel:
                amt = mrel.group(1)
                # epilogue teardown; `-<n>' leaves the callee-saved band
                # words the prologue pushed, which the epilogue pulls back
                if re.fullmatch(r"\S+_FRAMESIZE(-\d+)?", amt):
                    if depth != 0:
                        err(lineno, f"epilogue teardown at nonzero depth {depth}")
                    idx = _past_tcs()
                    dead = True     # after teardown: PLA/STA _fcc_fb/RTL
                    continue
                if amt.isdigit():
                    depth -= int(amt)
                    if depth < 0:
                        err(lineno, f"release #{amt} underflows depth")
                    idx = _past_tcs()
                    continue
                err(lineno, f"unmodeled TSC/ADC release operand #{amt}")
            if mres:
                amt = mres.group(1)
                if amt.isdigit():
                    depth += int(amt)
                    idx = _past_tcs()
                    continue
                err(lineno, f"unexpected reserve #{amt} in body")
            if minc:
                depth -= minc.group(1).count("INC")
                if depth < 0:
                    err(lineno, "TSC/INC release underflows depth")
                idx = _past_tcs()
                continue
            if mdec:
                depth += mdec.group(1).count("DEC")
                idx = _past_tcs()
                continue
            continue                # lone TSC = read S into A; depth unchanged

        if mnem in ("TCS", "TXS"):
            err(lineno, f"unmodeled {mnem} outside prologue/epilogue template")

        # ---- indirect-call far trampoline (net depth-neutral round trip) ----
        # `PHK / PEA <ret>-1 / ...target bank/offset PHA... / RTL` sets up a
        # JSL-style return then RTLs to the fn-ptr target; the callee's RTL pops
        # the PHK'd bank + PEA'd address (3 B) and the first RTL pops the target
        # (3 B), so execution resumes at <ret> at the SAME depth it had at PHK
        # (args already pushed below).  Model the whole linkage as a unit; the
        # surrounding arg push / post-call PLA cleanup are counted normally.
        if mnem == "PHK":
            nxt = None
            for k in range(idx, min(idx + 3, n)):
                c2 = lines[k][1].split(";", 1)[0].strip()
                mm = re.match(r"([A-Za-z]+)\s+(\S+)", c2)
                if mm and mm.group(1).upper() not in ("SEP", "REP"):
                    nxt = mm; break
            if nxt and nxt.group(1).upper() == "PEA" and nxt.group(2).endswith("-1"):
                ret = nxt.group(2)[:-2]
                entry = depth
                while idx < n:
                    c3 = lines[idx][1].split(";", 1)[0]
                    idx += 1
                    if re.match(r"\s+RTL\b", c3):
                        break
                if ret in label_depth and label_depth[ret] != entry:
                    err(lineno, f"trampoline return {ret} depth {entry} != "
                                f"{label_depth[ret]}")
                pending[ret] = entry
                dead = True
                continue
            depth += 1          # plain PHK (e.g. PHK/PLB DBR setup)
            continue

        # ---- callee-pops annotation (toolbox Pascal convention) ----
        if mnem == "JSL":
            mp = POPS_RE.search(raw)
            if mp:
                n = int(mp.group(1))
                if n > depth:
                    err(lineno, f"pops={n} exceeds tracked depth {depth}")
                depth -= n

        # ---- pushes / pulls ----
        if mnem in PUSH2:
            depth += 2;
        elif mnem in PUSH1:
            depth += 1
        elif mnem in PULL1:
            depth -= 1
        elif mnem in PUSH2D:
            depth += 2
        elif mnem in PULL2D:
            depth -= 2
        elif mnem in PHA:
            depth += 1 if m8 else 2
        elif mnem in PLA:
            depth -= 1 if m8 else 2
        elif mnem in PHXY:
            depth += 1 if x8 else 2
        elif mnem in PLXY:
            depth -= 1 if x8 else 2
        elif mnem == "PLP":
            err(lineno, "PLP: processor-state pull not modelled (fail closed)")
        if depth < 0:
            err(lineno, "stack pull underflows frame base")

        # ---- n,S operand checks ----
        if mnem in SLOT_MNEM and operand:
            nm = NS_RE.match(operand)
            if nm:
                ev = eval_operand(nm.group(1), equs, fs)
                if ev is not None:
                    val, _ = ev
                    if val < 1:
                        err(lineno, f"n,S operand {val} < 1 (reads at/below S)")
                    if fs is not None:
                        lo, hi = depth + fs + 1, depth + fs + 5
                        if lo <= val <= hi:
                            err(lineno, f"n,S operand {val} in return-address "
                                        f"band [{lo},{hi}] (frame clobber)")
                    an = ANNOT_RE.search(raw)
                    if an:
                        d, b, isfs = int(an.group(1)), int(an.group(2)), bool(an.group(3))
                        if d != depth:
                            err(lineno, f"annotation d={d} != tracked depth {depth} "
                                        f"(g_s_delta maintenance bug)")
                        want = b + d
                        # operand `val` already folded FRAMESIZE; for a param the
                        # annotation base b is delta/framesize-free, so add FS.
                        if isfs and fs is not None:
                            want += fs
                        if val != want:
                            err(lineno, f"annotation b+d={want} != operand {val} "
                                        f"(displacement format bug)")

        # A PC-relative forward jump (`BRA *+5`) skips one instruction that
        # another PC-relative branch lands on -- fcc's boolean idiom, `BNE *+7
        # / LDA #0 / BRA *+5 / LDA #1` -- so the code after it is reached, at
        # this depth.  Marking it dead lost every push until the next label:
        # a long double compare followed by the pushes of the next operation
        # (ecvt.c's cvt) read as a pull below the frame.
        if mnem in UNCOND and not operand.startswith("*"):
            dead = True
        # A branch carries its depth to its label, an unconditional one as
        # much as a conditional one: after `BRA L' the walk is dead, and L
        # takes its depth from here.
        if mnem in COND_BR or mnem in ("BRA", "BRL"):
            tgt = operand.strip()
            if tgt.startswith("*"):
                pass                     # PC-relative skip (`*+5`), not a label
            elif tgt in label_depth:
                if label_depth[tgt] != depth:
                    err(lineno, f"back-branch to {tgt} depth {depth} != "
                                f"{label_depth[tgt]}")
            else:
                if tgt in pending and pending[tgt] != depth:
                    err(lineno, f"branch to {tgt} depth {depth} != pending "
                                f"{pending[tgt]}")
                pending[tgt] = depth
    return


def iter_asm_files(args):
    for a in args:
        if os.path.isdir(a):
            # A directory scan = "the committed goldens": only *.expected.s, and
            # never the multibank sweep's intermediate .code.s (those are stale
            # pre-3.1a soft-stack artifacts — old `LDA _fcc_fb/SBC/STA` prologue,
            # no HW-stack frame — and untracked build output, not fcc's world).
            for root, _, files in os.walk(a):
                if os.sep + "multibank" + os.sep in root + os.sep:
                    continue
                for fn in files:
                    if fn.endswith(".expected.s"):
                        yield os.path.join(root, fn)
        elif os.path.isfile(a):
            yield a          # explicit path (e.g. FGX userland .s) — check as-is
        else:
            # Fail CLOSED: a path that is neither file nor dir (typo, stale
            # glob, ANSI-mangled shell expansion) must not be silently skipped
            # — "0 files, 0 violations" reads as green.
            sys.exit(f"stack_check: no such file or directory: {a!r}")


# P3-3 3.3 forbidden-token guard.  The soft-stack is gone: locals live on the
# bank-0 HW stack, addressed n,S; _fcc_fb is a bare 2-byte frame base used only
# for &local address arithmetic (bank invariantly 0).  These tokens must NEVER
# reappear in fcc output — each marks a resurrection of a deleted mechanism:
#   _fcc_ssp   the pre-3.3 name; its presence means STALE pre-rename fcc output
#              (or a hand-written reference to a symbol that no longer exists).
#   _fcc_fb+<n> the frame-base bank byte ($BE) / pad ($BF) were freed; the base
#              is a bare word.  A +offset read rebuilds the "fourth bank class"
#              (a local's bank != 0) this increment deleted.
#   [_fcc_fb]  the frame base is an offset for arithmetic, never an indirect ptr.
# Fail CLOSED: any hit is a hard violation (the assembler would happily build a
# silent garbage-bank read from _fcc_fb+2 — $BE is now unwritten).
_FORBIDDEN = [
    (re.compile(r"_fcc_ssp"),
     "_fcc_ssp — pre-3.3 soft-stack-pointer name (STALE fcc output; rerun fcc)"),
    (re.compile(r"_fcc_fb\s*\+"),
     "_fcc_fb+<n> — the frame-base bank/pad bytes were freed at 3.3; "
     "an offset read resurrects the deleted fourth-bank class"),
    (re.compile(r"\[\s*_fcc_fb\s*\]"),
     "[_fcc_fb] — the frame base is a bank-0 offset, never an indirect pointer"),
]


def forbidden_tokens(path):
    out = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for lineno, raw in enumerate(f, 1):
                code = raw.split(";", 1)[0]           # ignore inline comments
                for rx, why in _FORBIDDEN:
                    if rx.search(code):
                        out.append(f"{path}:{lineno}: forbidden token: {why}")
    except OSError as e:
        out.append(f"{path}: read error: {e}")        # fail CLOSED
    return out


def run(paths):
    viols, nfiles, nfns = [], 0, 0
    for path in iter_asm_files(paths):
        nfiles += 1
        viols.extend(forbidden_tokens(path))
        try:
            fns, equs = split_functions(path)
        except Exception as e:                       # noqa
            viols.append(f"{path}: parse error: {e}")
            continue
        for fn in fns:
            nfns += 1
            try:
                check_fn(fn, equs, path)
            except Violation as v:
                viols.append(str(v))
    return viols, nfiles, nfns


# ---- self-test: synthetic red/green cases ---------------------------------
_GREEN_SKIP = """\
f              ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                TCS
                STA     _fcc_fb
                INC     _fcc_fb
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                PHA
                PHK
                PEA     f_L2-1
                PHK
                PEA     g-1
                RTL             ; PILECALL
f_L2            PLA
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE     EQU     4
"""

_GREEN = """\
f              ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     3,S              ; fccstk d=0 b=3
                PHA
                LDA     5,S              ; fccstk d=2 b=3
                PLA
                LDA     6+f_FRAMESIZE,S  ; fccstk d=0 b=6 fs
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE     EQU     4
"""

# green: a function holding two callee-saved band words.  The prologue pushes
# them after _fcc_fb, FRAMESIZE counts them, and both returns free only the
# locals and branch to the shared tail that pulls them back.
_GREEN_BAND = """\
f              ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #f_FRAMESIZE-4
                TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     10+f_FRAMESIZE,S ; fccstk d=0 b=10 fs
                STA     _fcc_img16
                BEQ     f_L1
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-4
                TCS
                BRA     f_bandx
f_L1            LDA     #1
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE-4
                TCS
f_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE     EQU     8
"""

# red (a): uncounted push — a PHA/PLA window around a correct access; the
# annotation d stays 0 but the tracker sees depth 2.
_RED_BIAS = _GREEN.replace(
    "                PHA\n                LDA     5,S              ; fccstk d=2 b=3",
    "                PHA\n                LDA     5,S              ; fccstk d=0 b=3")

# red (b): a push never popped before RTL -> teardown at nonzero depth.
_RED_LEAK = _GREEN.replace(
    "                PLA\n                LDA     6+f_FRAMESIZE,S  ; fccstk d=0 b=6 fs",
    "                LDA     6+f_FRAMESIZE,S  ; fccstk d=2 b=6 fs")

# red (c): operand lands in the return-address band [FS+1,FS+5] = [5,9] at d=0.
_RED_BAND = _GREEN.replace(
    "                LDA     6+f_FRAMESIZE,S  ; fccstk d=0 b=6 fs",
    "                LDA     7,S              ; fccstk d=0 b=7")

# P3-3 3.3 forbidden-token reds — each resurrects a deleted soft-stack mechanism.
# red (d): the pre-3.3 _fcc_ssp name (stale fcc output).
_RED_OLDNAME = _GREEN.replace(
    "                INC     _fcc_fb\n",
    "                INC     _fcc_fb\n                LDA     _fcc_ssp\n")
# red (e): a +offset read of the freed frame-base bank byte (fourth-bank class).
_RED_FBOFF = _GREEN.replace(
    "                INC     _fcc_fb\n",
    "                INC     _fcc_fb\n                LDA     _fcc_fb+2\n")
# red (f): an indirect deref through the frame base.
_RED_FBIND = _GREEN.replace(
    "                INC     _fcc_fb\n",
    "                INC     _fcc_fb\n                LDA     [_fcc_fb]\n")


def self_test():
    import tempfile
    ok = True

    def one(name, text, expect_clean):
        nonlocal ok
        with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as t:
            t.write(text)
            p = t.name
        viols, _, _ = run([p])
        os.unlink(p)
        clean = not viols
        good = (clean == expect_clean)
        ok = ok and good
        tag = "OK " if good else "FAIL"
        exp = "clean" if expect_clean else "flagged"
        got = "clean" if clean else f"flagged: {viols[0]}"
        print(f"  [{tag}] {name}: expected {exp}, got {got}")

    one("green baseline", _GREEN, True)
    one("green: code after `BRA *+5' is live", _GREEN_SKIP, True)
    one("green: callee-saved band words and the shared tail", _GREEN_BAND, True)
    one("red(a) g_s_delta bias (uncounted push)", _RED_BIAS, False)
    one("red(b) unpopped push -> teardown imbalance", _RED_LEAK, False)
    one("red(c) return-address band clobber", _RED_BAND, False)
    one("red(d) forbidden _fcc_ssp (stale pre-3.3 output)", _RED_OLDNAME, False)
    one("red(e) forbidden _fcc_fb+off (resurrected bank class)", _RED_FBOFF, False)
    one("red(f) forbidden [_fcc_fb] indirect", _RED_FBIND, False)
    print("self-test:", "OK" if ok else "FAILED")
    return 0 if ok else 1


def main(argv):
    if not argv:
        sys.exit(__doc__)
    if argv[0] == "--self-test":
        return self_test()
    viols, nfiles, nfns = run(argv)
    for v in viols:
        print("stack_check: " + v, file=sys.stderr)
    print(f"stack_check: {nfiles} files, {nfns} functions, {len(viols)} violation(s)")
    return 1 if viols else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
