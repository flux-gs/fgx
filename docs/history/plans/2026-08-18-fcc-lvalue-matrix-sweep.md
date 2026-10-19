# fcc lvalue matrix sweep -- campaign charter

**Chartered 2026-08-18.**  Plan of record for closing the fcc lvalue /
pointer-arithmetic defect class as a class, instead of one cell at a time.

Prompted by apple/fgx#153, #154 and #155, which between them took 26 commits
and found twelve separate emitter sites carrying the same mistake.  Every one
was found by writing a fixture and watching it fail, and each fix made the next
one visible.  That is a working method but a bad way to finish: it terminates
when someone stops looking, not when the class is closed.

---

## 1. Why this is a class and not a run of bugs

fcc does not have *an* lvalue store.  It has a per-shape emitter for nearly
every combination of how an lvalue is reached and what is done to it.  Counted
2026-08-18 on `toolchain/src/cc/`:

    41   statement-side node kinds (S_*), 41 arms in walk_stmt
    87   expression-side node kinds (N_*)
    20   arms that read-modify-write (call emit_binop_for_compound)
    19   distinct store helpers (emit_*store_*)
     9   arms that scale a compound pointer operand
     9   ++/-- stride sites

Each arm was written for the shape in front of its author.  Nothing forces two
arms that mean the same thing to agree, and nothing tells you which arm a given
source construct will reach -- #155's `f()->next += 1` reached the EXPRESSION
emitter from STATEMENT position, because a call in the base routes the whole
statement through the expression layer.

The defects found so far are all the same species: an arm that gets one axis of
the matrix right and another wrong, in a cell no test occupied.

- **#154**: `ptr_stride()` returns 0 for a struct pointer by design; nine arms
  each independently wrote `if (s == 0) s = 1;` and advanced one byte.
- **#155**: the statement arm was fixed and its expression twin was not.
- **#153**: a struct id lost through the `--sigs` sidecar sent `->` down the
  K&R member-pun branch, which dereferences a base that is already a pointer.

None of the three was findable by reading the arm that contained it.  All three
were found by running a program and comparing a VALUE.

---

## 2. What is already known (2026-08-18)

Measured, not assumed.  This is the sweep's starting map, and the first task is
to reproduce it mechanically.

### Believed closed (every shape that compiles now scales correctly)

    p + n, p - n, p1 - p2, p[i]           always correct; use elem_size_for
    p++, ++p, p--, --p    (variable)      correct
    p->f++, ++p->f, p->q->f++, x.f++      fixed #154
    parr[i] += n, pp[i] += n              fixed #154
    p += n, p -= n, *pp += n              fixed #154
    f()->f += n, f()[i] += n              fixed #155
    x.f += <call>                         fixed #155 (bank no longer read back)

### Loud rejections of valid K&R C -- the band that remains

    s.parr[i] = / += / ++         "expected '='"        (any operation)
    p->parr[i] += n               "compound assign on pointer element
                                   unsupported"          (explicit refusal)
    q = (*pp += 1)                "expected ')'"
    q = p->ip++                   "expected ';'"
    (p->ip++)->x                  "expected ')'"
    (*(struct B **)buf) += 1      "expected '='"         (cast as lvalue)
    f()->m++ in value position    parses; other value forms do not

### Known departures from K&R, deliberate or unexamined

    void *p; p += 1               accepted, stride 1; void is not an object
                                  type (A.7.7) and this is undiagnosed
    member pun (A.7.3)            tolerated by policy for the 2.11BSD sh port;
                                  see apple/fgx#85

### Arms that do NOT scale a compound pointer operand

Eleven of the twenty RMW arms.  Nine are long/float arms, where a pointer leaf
is impossible and the absence is correct.  Two are not:

    S_FIELD_COMPOUND_AT           reachable only via p->parr[i] op=, which is
                                  refused before it gets there
    N_DSTORE (compound path)      reachable only via q = (*pp += 1), refused

So both are currently unreachable for a pointer leaf -- which means they are
latent, not live.  **They become live the moment the rejection band above is
closed.**  Phase 3 must not land without them.

---

## 3. The matrix

Five axes.  The cross product is far larger than the number of real cells,
because most combinations are ungrammatical or unreachable; enumerating and
CLASSIFYING is the work, not testing every product.

**A. How the lvalue is reached (shape)**

    named variable                      x
    dot member of a named struct        x.f
    arrow member                        p->f
    multi-hop chain                     p->q->f, p->q.f, x.f->g
    index of an array                   a[i]
    index of a pointer                  p[i]
    index of an array FIELD             x.arr[i], p->arr[i]
    deref                               *p, **p
    computed base (call result)         f()->g, f()[i]
    parenthesised                       (x).f, (p->f)
    cast as lvalue                      (*(T **)buf)

**B. Operation**

    read | plain store = | compound op= | prefix ++/-- | postfix ++/-- | &

**C. Position**

    statement (value discarded) | expression (value used)

**D. Leaf / element type**

    int | char | long | float | struct value | function pointer
    pointer to non-struct (stride 1, 2, 4)
    pointer to struct, POWER-OF-TWO size
    pointer to struct, NON-power-of-two size        <- the one that catches ASL
    pointer to struct, size > 255                   <- the one that catches
                                                       inline shift-add and
                                                       forces _fcc_mul16

**E. Storage class of the base**

    local | parameter | global | static local | static global

**F. Operand of the compound op** (secondary axis, applies to op= only)

    constant | runtime variable | expression with a CALL in it | negative

Axis F is not decoration.  A constant folds and reaches different code; a call
in the RHS is what exposed the direct-page liveness defect in #155.

---

## 4. Method

The method is not open to negotiation on the following points, each of which
was learned by getting it wrong in this campaign.

1. **Correctness is a runtime VALUE, compared against host C.**  Not "it
   compiled" -- every #154 shape compiled.  Not "the assembly looks right" -- I
   read it and concluded wrongly twice.  Each cell asserts a value the defect
   would change, and the reference answer comes from `cc` on the host.

2. **The struct in the fixtures is not a power of two.**  A stride built out of
   `ASL` passes every power-of-two case and is still wrong.  Include one size
   over 255 so the `_fcc_mul16` path is exercised; nothing exercised it before
   2026-08-18.

3. **Every probe is validated against a case it should catch.**  Twice in this
   campaign a probe reported a clean zero while blind to most of its subject,
   and twice a call counter watched the wrong function.  A counter is a probe.

4. **A fixture is run RED before it is trusted GREEN**, against a compiler
   built from the parent commit.

5. **Blast radius is measured by compiling the whole tree with both compilers
   and diffing the generated assembly** (2701 `.s` files), with a control
   proving the diff can see a difference.

6. **Never calibrate an oracle against a compiler you have not verified.**
   `run_runtime.py --calibrate` records the OBSERVED exit code; run against a
   broken compiler it writes the bug down as the expected answer.  This was
   nearly done once.

---

## 5. Phases

Each phase has an exit criterion that is a measurement, not a judgement.

### Phase 1 -- Enumerate and classify (no fixes)

Build a generator that emits one small C program per matrix cell, compiles it,
and classifies the result into exactly one of:

    COMPILES-CORRECT   runs on FGX and matches host C
    COMPILES-WRONG     runs and does NOT match host C     <- silent, worst
    REJECTED           fcc refuses with a diagnostic       <- loud
    ICE                fcc internal error                  <- loud, but see #155
    UNGRAMMATICAL      host cc also refuses; not our problem

Output is a committed coverage report: a table of cells by status, and the
generator itself so the table can be regenerated.

**Exit:** the table exists, every cell has a status, and the COMPILES-WRONG
column is enumerated.  If that column is empty, say so plainly -- that is the
campaign's most valuable possible finding and must not be softened.

*Estimated size: the generator plus one batch run.  The runtime oracle takes
one MAME boot per chunk of 40, so a few hundred cells is a handful of boots.*

### Phase 2 -- Close COMPILES-WRONG

Every silent miscompile gets a fix and a fixture.  Fixtures join the golden
suite; the aggregate cell table joins the gate as a single check.

**Exit:** COMPILES-WRONG is empty and a gate check keeps it empty.

### Phase 3 -- Close the rejection band

The REJECTED cells above are valid K&R and a self-hosting compiler will meet
them.  Close them in dependency order, and land the two latent unscaled arms
(section 2) WITH the shapes that reach them -- not after.

**Exit:** REJECTED contains only cells with a written justification (the
`void *` policy, the struct-return ABI limit) and each justification names the
K&R paragraph it departs from.

### Phase 4 -- Make the shape count go down

The real defect is that twenty arms can disagree.  With the matrix green and a
gate holding it, collapse arms onto the uniform lvalue walker where they
duplicate it, deleting emitters rather than adding scale calls.  This is the
only phase that reduces the surface; it is last because it needs the matrix as
its safety net.

**Exit:** a measured reduction in RMW arm count with the cell table unchanged.

---

## 6. Deliverables

    toolchain/tests/lvalue_matrix/gen.py      the generator
    toolchain/tests/lvalue_matrix/CELLS.md    the committed coverage report
    toolchain/tests/M22/*.c                   one fixture per fixed cell
    tools/gate.sh                             one aggregate check
    docs/PROVENANCE.md                        unchanged; this is original work

---

## 7. Non-goals

- **Not a rewrite of fcc's expression layer.**  Phase 4 deletes duplicated
  arms; it does not redesign the walker.
- **Not the register allocator.**  `fcc-fpr: non-LIFO register free` was a
  symptom in #155, not a subject; the allocator has its own scope note at
  `2026-08-09-fcc-regalloc-scope.md`.
- **Not ANSI conformance.**  The authority is K&R (the book, `kr_c` in the
  offline corpus).  Where FGX departs deliberately, the departure is recorded,
  not fixed.
- **Not performance.**  A correct stride that costs a `_fcc_mul16` call is
  correct.  Optimising it is a separate question and a later one.

---

## 8. Sequencing note

This campaign is independent of the three chartered at train-3 close and of the
UFS migration.  It is a prerequisite for the self-hosting `fcc` push in
practice if not on paper: a compiler that miscompiles `p += 1` on some shapes
cannot be trusted to compile itself, and the rejection band in section 2 is
exactly the kind of C a compiler source base contains.

Blocked on nothing.  MRs !214 and !215 should land first so Phase 1 measures
the current compiler rather than a known-stale one.
