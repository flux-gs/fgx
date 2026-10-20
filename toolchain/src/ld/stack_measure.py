#!/usr/bin/env python3
"""Deepest-path hardware-stack depth per binary from fcc .s output (P3-3 T4).

fcc emits `<fn>_FRAMESIZE EQU <bytes>` per function and, post-P3-3-flip, moves
that frame onto the bank-0 HARDWARE stack in the prologue.  This walks the
static call graph (JSR / FGX2_FARCALL edges between fcc functions) and reports
the deepest frame-sum path from main — the number the LINKER (fgx_ld.py) turns
into the FGX2 header stack-pages hint (offset 14) so the loader sizes the
task's bank-0 stack to fit.

Per-call overhead (P3-3 review F1): each live call level holds, on the same
page, more than just its FRAMESIZE:
  - 3 bytes  JSL return address (the call that reached the callee),
  - 2 bytes  the callee prologue's `PEI _fcc_fb` saved frame pointer,
  - the caller-pushed argument bytes (live across the whole callee).
The first two are exact and deterministic (CALL_OVERHEAD).  The arg bytes are
read from each call site's cleanup sequence (bank-0 stack campaign 0.3); they
used to be a flat ARG_PAD_PER_CALL = 16, which is now only the fallback for
edges that have no call site to read — an indirect dispatch, a signal handler,
a cycle turn.  Measured across the shipped userland: 3,517 of 3,517 graph edges
parsed, worst single site 70 bytes, and nine binaries' reservations shrank
(182 -> 169 pages in total) with none growing.  This overhead is DELIBERATELY
counted per graph edge, NOT folded into fgx_ld's headroom pad: it scales with
call depth, so a constant pad cannot cover it (F1).  The pad is reserved for
what the C graph CANNOT see — hand-asm libc/syscall pushes and IRQ nesting on
the same stack.

Caveats reported per binary:
  - recursion: cycles are cut (each cycle member counted once) and named — the
    sum is then a FLOOR, not a bound; the caller (fgx_ld) sizes such binaries
    to the page cap and REQUIRES the prologue overflow guard;
  - indirect calls (fn-ptr dispatch): edges unknowable statically.  P3-3 3.2c
    (task #43): sized by the ONE-HOP model — the deepest direct path plus one
    dispatch (edge overhead + the deepest function subtree in the binary,
    `maxfn`), instead of the old floor-to-cap (which put every fn-ptr-using
    tool at 32 pages = 8KB and let three sized tools exhaust the 112-page
    stack arena).  Ceiling: an indirect TARGET that itself dispatches through
    fn ptrs is under-counted (one hop only) — the prologue overflow guard
    backstops that with a loud exit-134 trap, and the fix is a manifest
    `stack_pad` / page bump, not silent corruption.

Usage (CLI, audit): stack_measure.py <tool.s> [more.s ...]   (one binary = one
run; multi-TU/multi-bank binaries pass all their TUs' .s files together).
Library (linker): from stack_measure import stack_pages
"""
import os
import re
import sys

FRAME_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)_FRAMESIZE\s+EQU\s+(\d+)", re.M)
# fcc emits one of these per function: 1 = the prologue carries the stack-floor
# guard, 0 = it does not.  Read it rather than re-deriving fcc's gate (frame
# >=128 / self-recursive / indirect call) so this analysis cannot drift out of
# sync with codegen.
GUARD_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)_STKGUARD\s+EQU\s+(\d+)", re.M)
ENT_RE   = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+ENT", re.M)
CALL_RE  = re.compile(r"^\s+(?:JSR|FGX2_FARCALL)\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
# fn-ptr dispatch tell: the two-frame RTL idiom pulls the far target from an
# FPR (P3-2.7: `LDA _fcc_fprN / DEC / PHA / RTL`; was _fcc_ptr pre-2.5b)
INDIR_RE = re.compile(r"LDA\s+_fcc_fpr\d+\s*\n\s+DEC\s*\n\s+PHA", re.M)
# signal-handler tell (#45 Fix B): a TU that registers a handler.  This libc's
# registration entries are signal() and sigvec() (lib/libc_c/signal.c,
# sigmask.c).  2.11BSD's kernel registers through sigaction()
# (usr/sys/sys/kern_sig2.c, sigaction -> setsigvec; its old sigvec syscall is
# nosys), which this libc does not export, and it is matched for the day it
# does.  fcc emits `FGX2_FARCALL <name>`.  A registration this misses leaves its
# handler with no allowance at all -- the under-sizing direction.
# The handler is delivered by the crt0 trampoline (crt0_lib.s _sig_tramp,
# which jumps to libc_start.s's _libc_sigtramp) at syscall exit -- it runs on
# the SAME bank-0 stack, ON TOP of whatever C frame
# was live, yet it is NOT an edge in main's call graph, so `worst=depth(main)`
# never sizes it.  It is exactly a one-hop indirect dispatch (the trampoline
# calls the handler by fn-ptr), so it earns the same allowance as INDIR_RE:
# edge_overhead + maxfn (the handler is some non-entry fn; maxfn bounds its
# subtree).  Runtime backstop for a nested/oversized handler = the _sig_tramp
# floor check (B2), since small handler frames are UNGUARDED (STKGUARD=0).
SIGNAL_RE = re.compile(
    r"^\s+(?:JSR|FGX2_FARCALL)\s+(?:signal|sigaction|sigvec)\b", re.M)

# --- Per-call-site argument bytes (bank-0 stack campaign, increment 0.3) ------
# The caller's argument pushes stay live for the whole callee, so they are part
# of what each call LEVEL holds.  fcc cleans them up in exactly two shapes, both
# emitted immediately after the call and both readable without guessing:
#
#   TAY / PLA xN / TYA          when every argument is 2 bytes (emit_drop_args)
#   [TAY] TSC / CLC / ADC #n / TCS / [TYA]   otherwise (parse_expr's call arms)
#
# and NOTHING at all when the call has no arguments.  The TAY is optional
# because the peephole deletes it when A is dead.  An `ADC #<sym>_FRAMESIZE`
# is a function EPILOGUE that happens to follow a call, not an argument pop --
# hence the digits-only immediate.
#
# This replaces a flat ARG_PAD_PER_CALL = 16 on every edge.  Measured over the
# whole userland (24,502 call sites): mean 2.24 bytes, and only 53 sites exceed
# 16 -- so the constant was over-reserving by roughly 14 bytes per call level on
# a typical path while still under-reserving the handful that matter.
# Deliberately the SAME shape as CALL_RE (no end anchor): every edge the
# depth walk knows about must also be findable here, or an edge would silently
# take the fallback allowance instead of its measured argument bytes.
CALLSITE_RE = re.compile(r"^\s+(?:JSR|FGX2_FARCALL)\s+([A-Za-z_][A-Za-z0-9_]*)")
ADC_IMM_RE = re.compile(r"^\s+ADC\s+#(\d+)\s*$")

# Exact per-call-level overhead below a callee's FRAMESIZE (P3-3 review F1):
# 3-byte JSL return address + 2-byte PEI'd saved frame pointer.
CALL_OVERHEAD = 5
# FALLBACK per-call allowance for caller-pushed argument bytes (8 int args'
# worth).  Since 0.3 the depth walk reads the real bytes at each call site, so
# this applies only where there is no site to read: an fn-ptr dispatch, a signal
# handler, a cycle turn -- and to any cleanup shape _call_arg_bytes does not
# recognise, which must NOT read as "zero arguments".  Zero is the direction
# that shrinks the reservation, and a stack sized too small is the silent
# corruption failure rather than the loud one.
ARG_PAD_PER_CALL = 16
# Default headroom for non-C stack users the call graph cannot see: hand-asm
# libc pushes, the syscall/IRQ pre-switch, the IRQ hardware frame, the signal
# trampoline (each runs on the same bank-0 stack, invisible to the FRAMESIZE
# sum).  CALIBRATED 2026-07-08 (task #42, GAP 2) via the fgxdebug
# `stack_excursion` tap over printf/ed/sed/jsh/sigtest + an IRQ-storm-during-C
# composition: the worst per-instant excursion e = _fcc_fb-1-S measured 26 B
# (IIgs ROM firmware), signal mechanism ~15 B, IRQ hw frame <=16 B.  128 is kept
# as a ~5x margin — see docs/history/audits/2026-07-08-p33-42-pad-calibration.md.
# NOT shaved below 128: this is the UNGUARDED budget (the prologue guard catches
# only C prologues, so a non-C push below StackBase is SILENT cross-task
# corruption, not the loud exit-134 trap that backstops C-frame under-estimates);
# page granularity means a smaller pad rarely changes any page count; and 128
# keeps a tiny frame + this headroom inside one page, so small programs stay
# pages==0 (loader 1-page default) with no header churn.  Keep the kernel-side
# FCC_STK_FLOOR_MARGIN (include/kernel.s) equal to this value.
# KNOWN GAP (not pad-fixable): the kernel-laid argv/envp frame is a top-side,
# command-line-dependent deduction that silently competes with this pad on a
# 1-page stack; the fix is spawn-side page accounting, not a bigger constant.
DEFAULT_PAD = 128
# LIBC'S OWN DEPTH, which this analysis could not see and charged as ZERO.
# The call table keeps only edges whose callee is in `frames' -- the program's
# own .s -- on the reasoning that anything else is an `_fcc_*' helper with a
# register ABI and no stack cost.  True of the helpers, false of libc: syslog(3)
# reaches fprintf reaches __lc_vpf, each pushing a return address and its
# arguments onto the same bank-0 stack.  DEFAULT_PAD above is the allowance for
# NON-C users and says so; nothing covered this.
#
# CHARGED PER CALLEE, not as one worst case.  libc's deepest chain is 384 bytes
# (getwd), and billing that to every binary that calls anything grew every
# task's reservation until the bank-0 arena could not seat the big runtime
# fixtures -- ss_bigbuf wants 17 pages of 152 and started exiting 1 instead of
# 42.  So the charge is the deepest libc function this binary actually reaches,
# and LIBC_WORST_DEPTH is only the fallback for a name the table does not have:
# the hand-asm piles carry no FRAMESIZE, so printf's callers still take the
# worst case.  Over-estimating is the safe direction -- a stack sized too small
# is the SILENT corruption, not the loud trap -- but over-estimating EVERYWHERE
# spends an arena that is also finite.
#
# WHAT IT COST WHILE IT WAS ZERO (apple/fgx#404): /sbin/reboot was sized at 2
# pages, 512 bytes, and /testbin/slogprobe measures 526 through reboot(8)'s own
# getlogin/getpwuid/openlog/syslog sequence.  It overran by fourteen bytes, and
# nothing trapped: the prologue guard catches C prologues, and the overrun was
# libc's pushes below StackBase.
LIBC_WORST_DEPTH = 384
# Paths resolve against THIS FILE, never the working directory: fgx_ld is
# invoked as `cd <bindir> && python3 $OLDPWD/fgx_ld.py', so cwd is the binary's
# build directory and a repo-relative path finds nothing.  Measured the hard
# way -- every lookup failed, every binary took the fallback, and the result
# was indistinguishable from the model working.
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))      # .../toolchain/src/ld/this -> repo root
LIBC_SRC = os.path.join(_REPO, "toolchain", "lib", "libc_c.s")
_LIBC_CACHE = os.path.join(_REPO, "build", ".libc_depths.json")
_libc_memo = None


def libc_depths():
    """name -> bank-0 depth for every C function in the libc pile.

    Cached on disk against the source's size+mtime: fgx_ld runs once per binary
    and the analysis is about a second, which is minutes of a full build spent
    recomputing one answer.  `toolchain/lib/libc_c.s' is on TOOLCHAIN_DEPS so a
    libc change relinks everything and the stamp is re-checked then.
    """
    global _libc_memo
    if _libc_memo is not None:
        return _libc_memo
    import json as _json
    try:
        st = os.stat(LIBC_SRC)
        stamp = [int(st.st_size), int(st.st_mtime)]
    except OSError:
        _libc_memo = {}
        return _libc_memo
    try:
        with open(_LIBC_CACHE) as f:
            c = _json.load(f)
        if c.get("stamp") == stamp:
            _libc_memo = c["depths"]
            return _libc_memo
    except (OSError, ValueError, KeyError):
        pass
    src = open(LIBC_SRC, errors="replace").read()
    frames = {m.group(1): int(m.group(2)) for m in FRAME_RE.finditer(src)}
    ents = list(ENT_RE.finditer(src))
    calls = {}
    for i, m in enumerate(ents):
        end = ents[i + 1].start() if i + 1 < len(ents) else len(src)
        nm = m.group(1)
        if nm in frames:
            calls[nm] = sorted({t for t in CALL_RE.findall(src[m.start():end])
                                if t in frames})
    edge = CALL_OVERHEAD + ARG_PAD_PER_CALL
    memo, onpath = {}, []

    def depth(fn):
        if fn in memo:
            return memo[fn]
        if fn in onpath:                      # cycle: cut it, as analyze does
            return 0
        onpath.append(fn)
        d = frames.get(fn, 0) + max(
            (edge + depth(c) for c in calls.get(fn, ())), default=0)
        onpath.pop()
        memo[fn] = d
        return d

    _libc_memo = {f: depth(f) for f in frames}
    try:
        os.makedirs(os.path.dirname(_LIBC_CACHE), exist_ok=True)
        with open(_LIBC_CACHE, "w") as f:
            _json.dump({"stamp": stamp, "depths": _libc_memo}, f)
    except OSError:
        pass
    return _libc_memo

STACK_PAGE = 256
# Per-task page ceiling; mirrors the kernel's TASK_STACK_MAX_PAGES (task.s) and
# fgx_ld's MAX_STACK_PAGES.  fgx_ld passes its own value explicitly; this is the
# audit-CLI default.
DEFAULT_MAX_PAGES = 83
# Extra turns of the deepest cycle member reserved for a RECURSIVE binary, on top
# of the measured (cycles-cut) depth.  See the CYCLE SIZING note in stack_pages().
CYCLE_TURNS = 8


def _call_arg_bytes(body):
    """Per-call-site argument bytes in one function body.

    Yields (callee, bytes).  A call site whose cleanup matches neither shape is
    reported as None, and the caller substitutes ARG_PAD_PER_CALL -- an
    unrecognised site must not read as "zero arguments", because zero is the
    direction that SHRINKS the reservation, and a stack sized too small is the
    silent-corruption failure, not the loud one.
    """
    lines = [l for l in body.split("\n") if l.strip()]
    for i, l in enumerate(lines):
        m = CALLSITE_RE.match(l)
        if not m:
            continue
        w = lines[i + 1:i + 12]
        op = [x.split()[0] for x in w]
        j = 1 if op[:1] == ["TAY"] else 0        # peephole may have dropped it
        if op[j:j + 1] == ["PLA"]:
            n = 0
            while op[j + n:j + n + 1] == ["PLA"]:
                n += 1
            yield m.group(1), 2 * n
        elif op[j:j + 4] == ["TSC", "CLC", "ADC", "TCS"]:
            imm = ADC_IMM_RE.match(w[j + 2])
            # digits -> argument pop; a symbol -> the epilogue of a function
            # whose last act was this call, i.e. no arguments to clean up.
            yield m.group(1), int(imm.group(1)) if imm else 0
        elif op[j:j + 1] in (["TSC"], ["PLX"], ["PLY"]):
            yield m.group(1), None               # a shape we do not model
        elif any(o == "TSC" for o in op[j:j + 4]):
            # A TSC within reach of the call that did NOT match the cleanup
            # shape above.  Reading this as "no arguments" is the failure this
            # generator's docstring forbids and did anyway: verified live, a
            # `JSR foo / STA _tmp / TSC / CLC / ADC #8 / TCS` scored 0 args.
            # Harmless today because the two emitter shapes are exhaustive --
            # and the first peephole that sinks an instruction between the call
            # and its cleanup would start SHRINKING reservations silently.
            yield m.group(1), None
        else:
            yield m.group(1), 0                  # no cleanup emitted = no args


def _sccs(calls):
    """Tarjan strongly-connected components of the call graph, as sorted lists.

    Iterative: tcsh's graph is 569 nodes with a 117-member component, so a
    recursive walk would need the interpreter's stack raised.
    """
    idx, low, on_stack, stack, out, counter = {}, {}, set(), [], [], [0]
    for root in calls:
        if root in idx:
            continue
        work = [(root, 0)]
        while work:
            v, pi = work[-1]
            if pi == 0:
                idx[v] = low[v] = counter[0]
                counter[0] += 1
                stack.append(v)
                on_stack.add(v)
            recursed = False
            succs = calls.get(v, ())
            for i in range(pi, len(succs)):
                w = succs[i]
                if w not in idx:
                    work[-1] = (v, i + 1)
                    work.append((w, 0))
                    recursed = True
                    break
                if w in on_stack:
                    low[v] = min(low[v], idx[w])
            if recursed:
                continue
            if low[v] == idx[v]:
                comp = []
                while True:
                    w = stack.pop()
                    on_stack.discard(w)
                    comp.append(w)
                    if w == v:
                        break
                out.append(sorted(comp))
            work.pop()
            if work:
                low[work[-1][0]] = min(low[work[-1][0]], low[v])
    return out


def call_graph(paths):
    """{caller: [callee, ...]} over the functions these .s files define.

    Split out of analyze() so the SCC emitter can share the exact graph the
    depth walk uses.  Sharing it is the point: an SCC list built from a
    second, subtly different graph would exile a set the stack model never
    agreed was recursive, and the two would drift silently.
    """
    frames, spans = {}, []
    for p in paths:
        s = open(p).read()
        for m in FRAME_RE.finditer(s):
            frames[m.group(1)] = int(m.group(2))
        ents = list(ENT_RE.finditer(s))
        for i, m in enumerate(ents):
            end = ents[i + 1].start() if i + 1 < len(ents) else len(s)
            spans.append((m.group(1), s[m.start():end]))
    calls = {}
    for name, body in spans:
        if name not in frames:
            continue
        calls[name] = sorted({t for t in CALL_RE.findall(body) if t in frames})
    return calls


def recursion_members(calls):
    """Sorted names of every function in a real recursion cycle.

    A Tarjan component of size > 1 is mutual recursion.  A SINGLETON component
    is a cycle only when it carries a self-edge -- Tarjan returns one component
    per node, so taking every component would exile the entire program, which
    is the failure mode that makes this two lines instead of one.
    """
    out = set()
    for comp in _sccs(calls):
        if len(comp) > 1:
            out.update(comp)
        elif comp[0] in calls.get(comp[0], ()):
            out.add(comp[0])
    return sorted(out)


def analyze(paths, edge_overhead=CALL_OVERHEAD + ARG_PAD_PER_CALL):
    """Return (worst, entry, path, frames, cycles, indirect, maxfn, mutual,
    has_signal).

    `worst` is the deepest-path byte sum INCLUDING per-edge overhead (F1).
    `maxfn` is the deepest subtree rooted at any NON-entry function — the
    one-hop indirect-dispatch allowance (3.2c): any fn-ptr target is some
    function in the binary, so its whole subtree fits under maxfn.
    `mutual` is the set of functions belonging to a cyclic strongly-connected
    component in which NO member carries the prologue guard — the only shape
    whose overrun is SILENT.  This used to be "cycle cut-point without a direct
    self-edge", which asked the wrong question: the guard traps on whichever
    member carries it, so a cycle is safe if ANY member has STKGUARD=1, not
    only if the cut-point self-calls.  On tcsh the old test named 16 functions
    of which 15 sat in guarded cycles (e.g. dobackp, a 1040 B frame -> gate's
    >=128 rule -> STKGUARD=1), so the one finding that mattered was buried in
    noise.  Cycles are real SCCs here, not DFS cut-points, so the reported
    group is the actual cycle.

    NOTE what this still cannot see: a cycle bounded by DATA FLOW rather than
    by the call graph.  tcsh's aliasrun <-> precmd is bounded upstream by a
    `static bool precmd_active` reentrancy flag, and no call-graph analysis
    can know that.  Such a cycle is reported; confirm by reading the source
    before treating a report as a defect.
    `has_signal` (#45) is True when any TU registers a signal handler — the
    handler subtree needs the same one-hop allowance as an indirect call."""
    frames, spans, indirect, has_signal = {}, [], 0, False
    guard = {}
    for p in paths:
        s = open(p).read()
        for m in FRAME_RE.finditer(s):
            frames[m.group(1)] = int(m.group(2))
        for m in GUARD_RE.finditer(s):
            guard[m.group(1)] = int(m.group(2))
        ents = list(ENT_RE.finditer(s))
        for i, m in enumerate(ents):
            end = ents[i + 1].start() if i + 1 < len(ents) else len(s)
            spans.append((m.group(1), s[m.start():end]))
        indirect += len(INDIR_RE.findall(s))
        has_signal = has_signal or bool(SIGNAL_RE.search(s))

    calls, argbytes, unparsed = {}, {}, 0
    libc_callees = set()
    for name, body in spans:
        if name not in frames:
            continue
        # Keep self-edges: direct self-recursion (rec -> rec) is a cycle the
        # depth walk must flag so the binary is sized to the cap + guard.  An
        # earlier `t != name` filter dropped them, making direct recursion
        # invisible and under-sizing the stack (P3-3 3.2).
        calls[name] = sorted({t for t in CALL_RE.findall(body) if t in frames})
        # A callee that is NOT in `frames' and is not an `_fcc_*' helper is
        # LIBC.  The comprehension above DISCARDS those edges, which is what
        # made libc cost nothing; they are collected here and priced in
        # stack_pages().  See LIBC_WORST_DEPTH.
        for t_ in CALL_RE.findall(body):
            if t_ not in frames and not t_.startswith("_fcc_"):
                libc_callees.add(t_)
        # 0.3: real argument bytes per edge.  Several sites can call the same
        # callee with different argument counts -- K&R varargs especially --
        # so the edge takes the WORST of them.
        for callee, nb in _call_arg_bytes(body):
            if callee not in frames:
                continue                          # _fcc_* helper: register ABI
            if nb is None:
                nb, unparsed = ARG_PAD_PER_CALL, unparsed + 1
            k = (name, callee)
            argbytes[k] = max(argbytes.get(k, 0), nb)

    memo, onpath, cycles = {}, [], set()

    def depth(fn):
        if fn in memo:
            return memo[fn]
        if fn in onpath:                       # recursion: cut the cycle
            cycles.add(fn)
            return 0
        onpath.append(fn)
        # Each edge to a callee costs the callee's frame PLUS the fixed
        # per-call overhead that lives below it (F1) PLUS that call site's real
        # argument bytes (0.3).  `edge_overhead` survives only as the
        # allowance for edges the call graph cannot see -- an indirect
        # dispatch, a signal handler, a cycle turn -- where there is no call
        # site to read.
        d = frames.get(fn, 0) + max(
            (CALL_OVERHEAD + argbytes.get((fn, c), ARG_PAD_PER_CALL) + depth(c)
             for c in calls.get(fn, ())), default=0)
        onpath.pop()
        memo[fn] = d
        return d

    entry = "main" if "main" in frames else max(frames, key=lambda f: frames[f])
    worst = depth(entry)
    # One-hop indirect allowance (3.2c): deepest subtree at any non-entry fn.
    # depth() is memoized, so sweeping the rest of the graph is cheap; entry
    # is excluded (an fn-ptr call back into main is recursion in disguise —
    # unbounded by nature, the guard's problem, not sizing's).
    maxfn = max((depth(f) for f in frames if f != entry), default=0)
    # SM_TOPSUB=1: report what actually SETS maxfn.  The one-hop allowance is
    # charged twice (indirect dispatch + signal handler), so for a program with
    # fn-ptr dispatch it is usually the DOMINANT term -- 9,370 of elvis's 12,728
    # bytes at one point.  "largest frames" below does NOT answer this: maxfn is
    # the deepest SUBTREE, and the function heading it can have a tiny frame of
    # its own (elvis's was v_overtype, own frame 4).  Reading the frame list and
    # assuming the biggest frame drives the allowance cost a wrong prediction
    # (~21 pages expected, 1 delivered); this prints the chain instead.
    if os.environ.get("SM_TOPSUB"):
        tops = sorted(((depth(f), f) for f in frames if f != entry), reverse=True)[:3]
        print("TOP SUBTREES (depth = own frame + callees):")
        for d_, f_ in tops:
            print("   %6d  %-24s own frame %d" % (d_, f_, frames.get(f_, 0)))
        cur, seen = tops[0][1], set()
        print("DEEPEST CHAIN from %s:" % cur)
        while cur and cur not in seen:
            seen.add(cur)
            print("   %-24s frame %5d   subtree %5d"
                  % (cur, frames.get(cur, 0), depth(cur)))
            kids = [(depth(c), c) for c in calls.get(cur, ()) if c not in seen]
            cur = max(kids)[1] if kids else None
    # A cycle is dangerous only when NOTHING on it is guarded (see doc).  Work
    # over real SCCs so the reported group is the actual cycle, and read the
    # guard flag fcc emitted rather than re-deriving its gate.  When a TU
    # predates the STKGUARD EQU (or a hand-written fixture omits it), fall back
    # to the old self-edge test for that function so nothing silently drops out
    # of the warning.
    def _guarded(f):
        return bool(guard[f]) if f in guard else (f in calls.get(f, ()))

    unguarded_sccs = [c for c in _sccs(calls)
                      if (len(c) > 1 or c[0] in calls.get(c[0], ()))
                      and not any(_guarded(f) for f in c)]
    mutual = {f for c in unguarded_sccs for f in c}

    # reconstruct one worst path for the report (visited-guarded: self-edges
    # and cycles are now present in `calls`, so stop when a node repeats)
    path, fn, seen = [], entry, set()
    while fn is not None and fn not in seen:
        seen.add(fn)
        path.append(f"{fn}({frames.get(fn, 0)})")
        nxt = max(calls.get(fn, ()), key=lambda c: memo.get(c, 0), default=None)
        fn = nxt if nxt and nxt not in seen and memo.get(nxt, 0) > 0 else None

    # Diagnostics for the linker log: how many edges were MEASURED, how many
    # fell back to the constant, and the worst site.  A silent fallback rate
    # would mean the constant is still doing the work under a new name.
    edges = sum(len(v) for v in calls.values())
    argstats = {"edges": edges, "measured": len(argbytes), "unparsed": unparsed,
                "max": max(argbytes.values(), default=0)}

    return worst, entry, path, frames, cycles, indirect, maxfn, mutual, \
        has_signal, unguarded_sccs, argstats, sorted(libc_callees)


def stack_pages(paths, pad=DEFAULT_PAD, max_pages=DEFAULT_MAX_PAGES,
                edge_overhead=CALL_OVERHEAD + ARG_PAD_PER_CALL):
    """Linker entry point: bytes -> clamped FGX2 stack-pages hint.

    Returns (pages, info) where info carries the raw numbers for logging.
    A RECURSIVE binary is sized to `max_pages` (the static sum is only a
    floor there) and MUST also carry the prologue overflow guard fcc emits
    for such functions.  An INDIRECT-call binary (no cycles) is sized by the
    one-hop model (3.2c): deepest direct path + one dispatch of the deepest
    subtree (`maxfn`) — the guard backstops nested dispatch.  `pages == 0`
    means "fits the loader's 1-page default" (keeps the header byte $00; no
    size-up needed)."""
    worst, entry, path, frames, cycles, indirect, maxfn, mutual, has_signal, \
        unguarded_sccs, argstats, libc_callees = analyze(paths, edge_overhead)
    floored = bool(cycles)
    # BOTH one-hop allowances below were once suppressed on `floored`, and the
    # reason was sound WHILE a cyclic binary was sized straight to `max_pages`:
    # the cap dominated, so adding to `total` changed nothing.  960dc6a92
    # replaced cap-sizing with the bounded `cycle_extra` below but left the
    # suppression in place, and the two together UNDER-size any binary that has
    # both a cycle and fn-ptr dispatch -- it loses the cap AND the allowance.
    #
    # elvis is exactly that binary and it is why this is not a hypothetical: a
    # 5-member cycle flipped `floored`, which zeroed a 4,786 B indirect
    # allowance, sizing vi's stack to 14 pages (3,584 B).  `add()` -- reached
    # ONLY through the vikeys fn-ptr table, so invisible to the direct graph --
    # has a 4,128 B frame that cannot fit in 3,584 B, so every insert-mode
    # keystroke hit add()'s prologue guard and exited 134.  A cycle and an
    # indirect call are independent facts about a binary; neither excuses the
    # other's reserve.
    indirect_extra = 0
    if indirect:
        indirect_extra = edge_overhead + maxfn         # one fn-ptr hop
    # #45 Fix B: a signal handler stacks ON TOP of the live C frame at delivery,
    # invisible to worst=depth(main).  Reserve one more one-hop dispatch for it
    # (edge + maxfn) — ADDITIVE to indirect_extra, since a signal can fire while
    # an fn-ptr-dispatched subtree is live (over-estimation grows the stack, the
    # safe direction).
    signal_extra = 0
    if has_signal:
        signal_extra = edge_overhead + maxfn           # one signal-handler hop
    # CYCLE SIZING.  A cycle makes `worst` a FLOOR, not a bound -- the static sum
    # cannot know how many times the cycle turns -- so this used to size such a
    # binary straight to `max_pages`.  Simple, but it charges EVERY cyclic binary
    # the entire cap, and that is a global coupling with teeth: raising the cap
    # 32 -> 56 for tcsh (which genuinely measures 50 pages) also inflated bsh from
    # 33 to 57 even though bsh's real deepest path is 4,623 B = 19 pages.  Two
    # 57-page stacks do not fit the 112-page bank-0 arena (FGX_STK_ARENA_PAGES,
    # and the arena cannot meaningfully grow because the 65816 stack pointer is
    # 16-bit), so `tcsh` exec began failing with ENOMEM -- reported by bsh as the
    # famously unhelpful "too big".
    #
    # Reserve a BOUNDED number of extra turns of the deepest cycle member instead.
    # This is still a heuristic, not a proof: the honest backstop for a deeper
    # recursion is the fcc prologue guard, which traps DIRECT self-recursion.  A
    # MUTUAL cycle has STKGUARD=0 and is therefore UNGUARDED -- fgx_ld already
    # warns about exactly that, and this note is why that warning matters more
    # now than it did under cap-sizing.
    cycle_extra = 0
    if floored:
        deepest_cycle_frame = max((frames.get(f, 0) for f in cycles), default=0)
        cycle_extra = CYCLE_TURNS * (edge_overhead + deepest_cycle_frame)
    # libc's own depth: the deepest function this binary actually reaches,
    # charged once -- libc does not call back except through a function pointer
    # or a signal handler, and both already carry their own allowance.
    libc_extra = 0
    if libc_callees:
        _d = libc_depths()
        libc_extra = edge_overhead + max(
            (_d.get(c, LIBC_WORST_DEPTH) for c in libc_callees), default=0)
    total = worst + indirect_extra + signal_extra + cycle_extra + libc_extra \
        + pad
    pages = (total + STACK_PAGE - 1) // STACK_PAGE     # ceil
    if pages > max_pages:
        pages = max_pages
    if pages <= 1:
        pages = 0                                      # loader default (1 page)
    info = {"entry": entry, "worst": worst, "pad": pad, "total": total,
            "cycle_extra": cycle_extra,
            "cycles": sorted(cycles), "mutual_cycles": sorted(mutual),
            "unguarded_cycles": unguarded_sccs,
            "indirect": indirect,
            "maxfn": maxfn, "indirect_extra": indirect_extra,
            "has_signal": has_signal, "signal_extra": signal_extra,
            "libc_callees": len(libc_callees), "libc_extra": libc_extra,
            "clamped": bool((total + STACK_PAGE - 1) // STACK_PAGE
                            > max_pages),
            "floored": floored, "path": path, "argstats": argstats}
    return pages, info


def _self_test():
    """Prove the call-site argument parser in BOTH directions.

    It is the one piece here whose failure is silent: an unrecognised cleanup
    reads as "this call had no arguments", which SHRINKS the reservation, and a
    stack sized too small is the silent-corruption failure rather than the loud
    exit-134 one.  Exercise each shape fcc actually emits, plus the two that
    must not be mistaken for argument pops.
    """
    def one(body):
        return dict(_call_arg_bytes(body))

    fails = 0
    cases = [
        ("no cleanup = no arguments",
         "                JSR     foo\n                LDA     #0\n", {"foo": 0}),
        ("PLA drop, 3 two-byte args",
         "                JSR     foo\n                TAY\n                PLA\n"
         "                PLA\n                PLA\n                TYA\n", {"foo": 6}),
        ("PLA drop with the TAY peepholed away",
         "                JSR     foo\n                PLA\n                PLA\n"
         "                STA     _x\n", {"foo": 4}),
        ("TSC/CLC/ADC/TCS pop",
         "                FGX2_FARCALL printf\n                TSC\n"
         "                CLC\n                ADC     #4\n"
         "                TCS\n", {"printf": 4}),
        ("TSC pop behind a TAY",
         "                JSR     foo\n                TAY\n                TSC\n"
         "                CLC\n                ADC     #70\n                TCS\n"
         "                TYA\n", {"foo": 70}),
        # An epilogue that happens to follow a call is NOT an argument pop --
        # the immediate is a symbol, and reading it as one would be a parse
        # error that silently inflated (not shrank) the number.
        ("epilogue after a tail call is not a pop",
         "                JSR     foo\n                TAY\n                TSC\n"
         "                CLC\n                ADC     #bar_FRAMESIZE\n"
         "                TCS\n", {"foo": 0}),
        # A call with a trailing comment must still be found: CALL_RE has no end
        # anchor, so a stricter CALLSITE_RE would drop the edge here and let it
        # take the fallback instead of its real bytes.
        ("call line with a trailing comment",
         "                JSR     foo        ; note\n                PLA\n", {"foo": 2}),
        # A cleanup with an instruction sunk in front of the TSC must fall back
        # to the conservative constant, NOT read as zero arguments.
        ("displaced cleanup falls back rather than reading as no-args",
         "                JSR     foo\n                STA     _tmp\n"
         "                TSC\n                CLC\n                ADC     #8\n"
         "                TCS\n", {"foo": None}),
    ]
    for label, body, want in cases:
        got = one(body)
        if got != want:
            print(f"  SELFTEST FAIL [{label}]: {got} != {want}")
            fails += 1

    # An unmodelled cleanup must report None (-> the caller substitutes the
    # conservative constant), NOT 0.
    got = one("                JSR     foo\n                PLX\n")
    if got != {"foo": None}:
        print(f"  SELFTEST FAIL [unmodelled cleanup]: {got} != {{'foo': None}}")
        fails += 1

    # And the whole pipeline must still produce a number.
    body = ("main            ENT\n"
            "                JSR     foo\n                PLA\n                PLA\n")
    if not CALLSITE_RE.match("                JSR     foo"):
        print("  SELFTEST FAIL: CALLSITE_RE no longer matches a plain call")
        fails += 1

    # SIGNAL_RE: a TU that registers only through sigvec() must earn the
    # signal allowance, and a mask call must not.
    for call, want in (("signal", True), ("sigvec", True), ("sigaction", True),
                       ("sigsetmask", False), ("sigblock", False)):
        got = bool(SIGNAL_RE.search(f"                FGX2_FARCALL {call}\n"))
        if got != want:
            print(f"  SELFTEST FAIL: SIGNAL_RE on a call to {call} = {got}, "
                  f"want {want}")
            fails += 1

    # recursion_members (1.3): the dangerous direction is OVER-reporting.
    # Tarjan emits one component per node, so a naive "every component is a
    # cycle" would mark the whole program soft -- every function would pay the
    # prologue and the per-access cost, and tcsh does not have the code space.
    # Under-reporting is caught by the runtime guards; over-reporting is not
    # caught by anything, so it is the case with two assertions.
    scc_cases = [
        ({"a": ["b"], "b": ["c"], "c": []},                    []),
        ({"rec": ["rec"]},                                     ["rec"]),
        ({"ping": ["pong"], "pong": ["ping"]},                 ["ping", "pong"]),
        # a leaf hanging off a cycle is NOT in the cycle
        ({"p": ["q"], "q": ["p", "leaf"], "leaf": []},         ["p", "q"]),
        # two independent cycles both reported, sorted
        ({"a": ["b"], "b": ["a"], "z": ["z"]},                 ["a", "b", "z"]),
    ]
    for graph, want in scc_cases:
        got = recursion_members(graph)
        if got != want:
            print(f"  SELFTEST FAIL: recursion_members({graph}) = {got}, "
                  f"want {want}")
            fails += 1
    # Determinism: the same graph must give a byte-identical list, or the
    # committed file churns and `ninja -n` stops being a meaningful test.
    g = {"m": ["n"], "n": ["m"], "o": ["o"]}
    if recursion_members(g) != recursion_members(g):
        print("  SELFTEST FAIL: recursion_members is not deterministic")
        fails += 1

    if fails:
        print(f"stack_measure self-test: {fails} FAILURE(S)")
        return 1
    print(f"stack_measure self-test: OK ({len(cases) + 2 + 5 + len(scc_cases) + 1} "
          f"cases)")
    return 0


def main():
    if "--self-test" in sys.argv:
        sys.exit(_self_test())
    if "--emit-scc" in sys.argv:
        # Bank-0 stack campaign 1.3: the soft-frame member list.  Deterministic
        # (sorted, one name per line) so re-running the generator produces a
        # byte-identical file and `ninja -n` reports no work -- the
        # build-writes-its-own-inputs test.  Written to stdout; the caller
        # commits it, because which functions recurse is a link-time fact and
        # fcc must not learn it from a file the same build just produced.
        args = [a for a in sys.argv[1:] if a != "--emit-scc"]
        if not args:
            sys.exit(__doc__)
        names = recursion_members(call_graph(args))
        sys.stdout.write("# GENERATED by stack_measure.py --emit-scc -- do not "
                         "hand-edit.\n")
        sys.stdout.write("# Functions in a recursion cycle; fcc gives these "
                         "soft (data-bank) frames.\n")
        for n in names:
            sys.stdout.write(n + "\n")
        return 0
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    worst, entry, path, frames, cycles, indirect, maxfn, mutual, has_signal, \
        unguarded_sccs, argstats, libc_callees = analyze(sys.argv[1:])
    pages, info = stack_pages(sys.argv[1:])
    print(f"functions: {len(frames)}   entry: {entry}")
    print(f"WORST-CASE hw-stack frame sum (incl. per-call overhead): "
          f"{worst} bytes")
    print(f"stack pages (pad {info['pad']}, total {info['total']}, "
          f"clamp {DEFAULT_MAX_PAGES}): "
          f"{pages if pages else '0 (loader default, 1 page)'}")
    if info["clamped"]:
        print(f"  !! CLAMPED: deepest path exceeds the {DEFAULT_MAX_PAGES}-page "
              f"({DEFAULT_MAX_PAGES // 4}KB) cap — this binary needs "
              f"TASK_STACK_MAX_PAGES raised or heap-boxing")
    a = argstats
    print(f"call-site arg bytes: {a['measured']} of {a['edges']} edges measured, "
          f"{a['unparsed']} fell back to {ARG_PAD_PER_CALL}, worst {a['max']} B")
    print("worst path: " + " -> ".join(path))
    big = sorted(frames.items(), key=lambda kv: -kv[1])[:8]
    print("largest frames: " + ", ".join(f"{n}={v}" for n, v in big))
    if cycles:
        print(f"RECURSION (cycles cut, sum is a floor; sized to cap + guard): "
              f"{sorted(cycles)}")
    if mutual:
        for c in unguarded_sccs:
            print(f"  !! UNGUARDED cycle {c}: no member carries STKGUARD, so an "
                  f"unbounded turn overruns the stack SILENTLY (a guarded "
                  f"member would trap).  Check for a data-flow bound in the "
                  f"source before treating this as a defect.")
    if indirect:
        print(f"indirect call sites: {indirect} (fn-ptr edges not in the "
              f"graph — one-hop model adds {info['indirect_extra']} B "
              f"(edge + maxfn {maxfn}); nested dispatch relies on the guard)")
    if has_signal:
        print(f"signal handler registered: +{info['signal_extra']} B one-hop "
              f"allowance (edge + maxfn {maxfn}); handler subtree stacks on "
              f"top of the live frame — runtime backstop = _sig_tramp floor "
              f"check (crt0)")


if __name__ == "__main__":
    main()
