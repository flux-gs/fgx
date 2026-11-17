# Net-mux S0 -- fcc prerequisites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** fcc compiles every 2.11BSD networking file the net-mux design ports, as 2.11BSD's compiler did, with no workaround in a ported file.

**Architecture:** One task audits the whole file set under fcc and sorts each failure into "fcc" (fixed here) or "machine seam" (S1's).  Then one task per fcc defect: a fixture that fails first, the fix in `toolchain/src/cc/`, goldens and the emulator oracle green.  A closing task re-runs the audit.

**Tech Stack:** fcc (K&R C compiler, `toolchain/src/cc/`), its fixture suite (`toolchain/tests/`), MAME via `toolchain/tests/run_runtime.py`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md` (phase S0, section 4.4), which folds in the item list of `docs/history/plans/2026-09-27-trackb-s0-fcc-design.md` section 3.  Read both.

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR (the maintainer tests locally first).
- Toolchain-first: fix fcc, never a ported file.  No sed over generated output, no per-file workaround (CLAUDE.md).
- Before each fcc change, open the governing K&R 2nd ed Appendix A page (`mcp__gs-mcp__search_iigs_docs(q, doc_filter=["kr_c"])`, then `get_iigs_page(doc_id="kr_c", page=N)`) and QUOTE the deciding sentence in the commit.  The S0 design's quotes are leads, not evidence.
- Every fix: a fixture in `toolchain/tests/M46/` with an oracle value of 42 in `toolchain/tests/oracle.json`, seen FAILING before the fix; `cd toolchain/tests && ./run.sh` all green; `python3 run_runtime.py --names <fixtures>` green on FGX.
- A rejection fcc must keep making goes in `toolchain/tests/reject/<name>.c` with `/* expect: <diagnostic substring> */` on line 1; `./run_reject.sh` green.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.
- `tools/gate.sh` green before the phase is called done.
- Rebuild fcc with `ninja toolchain/fcc` (or `make -C toolchain`) and check its timestamp is newer than the edit before testing.

## Review Focus

1. A macro argument next to `##` that is itself a macro name: it must paste unexpanded (`cat(x, ONE)` gives `xONE`, not `x1`).  Task 2's fixture pins it.
2. An `extern struct T g;` whose struct is never completed but whose member is read: must still be REFUSED at the use, not compiled at a guessed offset.  Task 3's reject fixture pins it.
3. Two calls to one struct-returning function in one expression (`f(1).x + f(2).x`): each must see its own value -- the reason for the hidden pointer.  Task 7's fixture pins it.
4. A struct-returning function called through a function pointer, and across translation units through the signature sidecar.  Task 7 pins both.
5. `&` of a bit-field or of a `register` variable: still refused after `&` accepts every other lvalue.  Task 6's reject fixtures pin it.

---

### Task 1: Audit the whole port set under fcc

**Files:**
- Create (scratch, not committed): `$SCRATCH/netaudit/` with a configured include tree
- Modify: `docs/history/plans/2026-11-03-net-mux-s0-plan.md` (append any new fcc items as tasks after Task 7)

**Interfaces:**
- Produces: the audit script `$SCRATCH/netaudit/audit.sh`, re-run by Task 8; a table, in the commit body, of each file's first fcc failure and its class.

**Result (2026-11-03).**  `audit.sh` compiles each file as CURLY's `Make.net` does (`-Dpdp11 -DKERNEL -DCURLY -DUCB_METER -DINET -DQUOTA -DUCB_CLIST -DSUPERVISOR`, CURLY's config headers, `<sys/...>` mapped to `h/`).  With seam gaps patched and the known fcc items masked in scratch, the first failures were:

| Class | Item | Where |
|---|---|---|
| fcc | 3.2 `##` (port writes `##` for the Reiser `x/**/domain`) | `sys/uipc_domain.c:36` |
| fcc | 3.7 `&` of a parenthesized or cast primary followed by `->` | `sys/uipc_socket.c:322` (`sblock`), `netinet/tcp_subr.c:284` and `udp_usrreq.c:154` (`sorwakeup`), `netinet/ip_input.c:606` (`IA_SIN`) |
| fcc | 3.8 struct return, declaration and definition | `netinet/in.h:178`, `netinet/in.c:56` |
| fcc | NEW: call through a function pointer at the end of a member chain | `netinet/if_ether.c:132`, `:339` (Task 7a) |
| fcc | NEW: typedef of a sized array | `pdp/seg.h:127` (Task 7b) |
| seam | `h/signal.h:129` missing `;` (non-conforming, not ported) | every file |
| seam | `label_t` and other PDP arms under `-Dpdp11` | `h/types.h` |
| seam | `FMARK`/`FDEFER`, `FREAD` defined nowhere in 2.11BSD's `h/` (4.3BSD-Reno's `sys/file.h` has them) | `sys/uipc_usrreq.c:572`, `sys/uipc_syscalls.c:63` |
| seam | PDP segmentation | `pdp/seg.h` |

Items 3.4, 3.5 and 3.6 did not surface as a first failure in this set (`in_proto.c`'s `&inetsw[...]` initializer now compiles); their tasks stay, from the approved S0 list, and Task 8's unmasked re-run shows whether they are reached.  `uipc_socket2.c`, `uipc_mbuf.c`, `net/if.c`, `net/route.c` compile with no change.

- [ ] **Step 1: Build the include tree.**  Copy `examples/2.11BSD/usr/sys/h` to `netaudit/sys`, `netaudit/net`, `netaudit/netinet` from the same tree, and make `netaudit/machine` a directory of empty or minimal headers for what the PDP `machine/*.h` and `pdp/net_mac.h` supply (`spl*`, `KScall`, `label_t`, `UCHAR`) -- stubs only, enough to get past them; they are S1's real work.
- [ ] **Step 2: Write `audit.sh`.**  For each file below, run `toolchain/fcc --module-bank -DKERNEL -DINET -I netaudit -I netaudit/sys -o /dev/null --data-segment /dev/null <file>` and print the first error:
  `sys/uipc_socket.c uipc_socket2.c uipc_mbuf.c uipc_domain.c uipc_usrreq.c uipc_syscalls.c`,
  `netinet/tcp_input.c tcp_output.c tcp_subr.c tcp_timer.c tcp_usrreq.c udp_usrreq.c in_pcb.c in.c in_proto.c ip_icmp.c raw_ip.c ip_input.c ip_output.c if_ether.c`,
  `net/if.c route.c if_loop.c`.
- [ ] **Step 3: Classify.**  For each failure: fcc (the source is K&R-conforming and fcc refuses or miscompiles it) or seam (PDP-specific header, `spl`, mbuf layout, supervisor space).  Work around a SEAM failure in the stub tree and re-run, so the file's next failure shows; never work around an fcc failure.  Expected fcc classes already known: items 3.2 (`##`), 3.4, 3.5, 3.6 (`t+4` in an array of pointers), 3.7, 3.8, and `#` stringizing.
- [ ] **Step 4: Record.**  Any fcc defect not in Tasks 2-7 becomes a new task appended after Task 7, in the same shape.
- [ ] **Step 5: Commit** the plan update: `git commit -m "docs: net-mux S0 audit of the port set"` with the table in the body.

### Task 2: `#` and `##` in macro replacement (S0 item 3.2)

**Files:**
- Modify: `toolchain/src/cc/lex_pp.c` (macro body capture and expansion; today line 1539 dies "unexpected character #")
- Test: `toolchain/tests/M46/pp_paste.c`, `toolchain/tests/reject/pp_paste_edge.c`

**Interfaces:**
- Produces: function-like macros whose bodies use `#param` (string of the unexpanded argument spelling) and `a ## b` (token concatenation of the unexpanded arguments), per K&R A.12.3.

- [ ] **Step 1: Write the fixture** `pp_paste.c`: `#define cat(a,b) a ## b`, `#define ONE 1`, `#define str(x) #x`; `int var123 = 20; int xONE = 22;`; `main` returns `cat(var,123) + cat(x,ONE)` when `str(abc)` is the 3-character string `"abc"` (check with a byte loop), else 0.  Expected 42.
- [ ] **Step 2: Write the reject fixture** `pp_paste_edge.c`: `/* expect: ## */` and `#define bad(a) ## a`, used once.  (A.12.3: `##` may not begin or end a replacement sequence.)
- [ ] **Step 3: Run both; see them fail** (`cd toolchain/tests && ./run.sh pp_paste` -- "unexpected character #"; `./run_reject.sh pp_paste_edge`).
- [ ] **Step 4: Implement** in `lex_pp.c`: keep `#` and `##` as tokens inside a `#define` body; at expansion, substitute arguments next to `#`/`##` without expanding them, stringize for `#`, then concatenate across `##` and re-lex the joined spelling as one token.
- [ ] **Step 5: Run** `./run.sh` (all), `./run_reject.sh`, `python3 run_runtime.py --names pp_paste`.  Expected: all pass, `pp_paste` returns 42.
- [ ] **Step 6: Commit** `fcc: # and ## in macro replacement`, quoting A.12.3.

### Task 3: `extern` of an incomplete struct (item 3.4)

**Files:**
- Modify: `toolchain/src/cc/parse_stmt.c:9750` ("by-value struct global requires complete type")
- Test: `toolchain/tests/M46/extern_incomplete.c`, `toolchain/tests/reject/extern_never_complete.c`

**Interfaces:**
- Produces: a global declared `extern` with an incomplete struct type; completeness checked where size is needed (definition, `sizeof`, member access, copy).

- [ ] **Step 1: Fixture** `extern_incomplete.c`: `extern struct domain inetdomain;` before `struct domain { int dom_family; struct domain *dom_next; };`, then `struct domain inetdomain = { 42, 0 };`; `main` returns `inetdomain.dom_family`.  Expected 42.
- [ ] **Step 2: Reject fixture** `extern_never_complete.c`: `/* expect: incomplete */`, `extern struct nope g; int main() { return g.x; }`.
- [ ] **Step 3: See both fail** (the first refuses at the extern, the second at the extern for the wrong reason).
- [ ] **Step 4: Implement:** an `extern` (non-defining) declaration of an incomplete struct type records the global with its struct id and no size; the size check moves to the definition, `sizeof`, and member/copy use, which fail with a message containing "incomplete".
- [ ] **Step 5: Run** goldens, rejects, `run_runtime.py --names extern_incomplete`.
- [ ] **Step 6: Commit** `fcc: an extern declaration may name an incomplete struct`, quoting A.8.3.

### Task 4: struct assignment into an array element (item 3.5)

**Files:**
- Modify: `toolchain/src/cc/parse_stmt.c:6705` and `:7137` ("struct-array element LHS requires '.field'")
- Test: `toolchain/tests/M46/struct_elem_assign.c`

- [ ] **Step 1: Fixture:** `struct in_addr { unsigned long s_addr; };` a global `struct { struct in_addr route[4]; } g;`, a local `struct in_addr a[3]`, a pointer `p` to `g`; assign `g.route[i] = s`, `a[i] = s`, `p->route[i+1] = a[i]` with `i` a runtime 1; return 42 when all three hold `s`'s value and the neighboring elements are untouched.
- [ ] **Step 2: See it fail** with "struct-array element LHS requires '.field'".
- [ ] **Step 3: Implement:** a struct-typed array element is an lvalue for whole-struct assignment, copied at the struct's size like the existing struct-to-struct assignment path (A.7.17).
- [ ] **Step 4: Run** goldens and `run_runtime.py --names struct_elem_assign`.
- [ ] **Step 5: Commit** `fcc: a struct may be assigned into an array element`, quoting A.7.17.

### Task 5: address plus a constant in an array-of-pointers initializer (item 3.6)

**Files:**
- Modify: `toolchain/src/cc/parse_stmt.c` initializer-list paths (`:4663` / `:9898`, "expected ',' or '}' in init list")
- Test: `toolchain/tests/M46/ptrarr_addr_disp.c`

**Interfaces:**
- Consumes: the address-plus-constant parsing added for struct fields in #45 (`sfld_ptr_addr_init`, `parse_stmt.c`); reuse it, scaled by `elem_size_for`.

- [ ] **Step 1: Fixture:** `char t[10]; int iarr[5]; char *tp[] = { t+4, t, &t[2] }; int *ip[] = { iarr+3, iarr };` with `t[4]=20`, `t[2]=10`, `iarr[3]=12`; `main` returns `*tp[0] + *tp[2] + *ip[0]` (= 42) when `tp[1] == t` and `ip[1] == iarr`.
- [ ] **Step 2: See it fail** at `t+4`.
- [ ] **Step 3: Implement** the `+`/`-` constant arm for pointer-array initializer elements, as for struct fields.
- [ ] **Step 4: Run** goldens and `run_runtime.py --names ptrarr_addr_disp`.
- [ ] **Step 5: Commit** `fcc: an address plus a constant in an array-of-pointers initializer`, quoting A.7.19.

### Task 6: `&` of any lvalue (item 3.7)

**Files:**
- Modify: `toolchain/src/cc/parse_expr.c` (the `&` arms; today `:1780` dies "expected identifier after '&'")
- Test: `toolchain/tests/M46/addrof_lvalue.c`, `toolchain/tests/reject/addrof_bitfield.c`, `toolchain/tests/reject/addrof_register.c`

**Interfaces:**
- Consumes: the uniform lvalue walker (`build_lvalue_suffixes` / `N_LV_CHAIN`); read the current `&` arms first and delete the shape list rather than extend it.

- [ ] **Step 1: Fixture:** `struct sa { int f; }; struct ia { int x; struct sa addr; int arr[3]; };` and a `char *` holding an `ia`'s address; take `&(((struct ia *)cp)->addr)` (2.11BSD's `IA_SIN`), `&(&s->m)->f` (`sblock`'s `&(sb)->sb_flags` with `sb` = `&so->so_snd`), `&(q->p)->addr` (`sorwakeup`'s `&(so)->so_rcv` with `so` = `inp->inp_socket`), `&((q->p)->addr)`, `&p->arr[2]`, `&a[1].addr`, `&*p`; write through each and return 42 when every write landed in the right member.  The audit found the first three failing today; the simple forms already pass.
- [ ] **Step 2: Reject fixtures:** `&s.bits` with `bits` a bit-field (`/* expect: bit-field */`); `&r` with `register int r` (`/* expect: register */`).
- [ ] **Step 3: See the fixture fail** ("expected identifier after '&'"); check whether the two rejects already pass.
- [ ] **Step 4: Implement:** `&` takes its operand through the lvalue walker; the bit-field and register refusals stay.
- [ ] **Step 5: Run** goldens, rejects, `run_runtime.py --names addrof_lvalue`.
- [ ] **Step 6: Commit** `fcc: & takes the address of any lvalue`, quoting A.7.4.2.

### Task 7: struct return by value through a hidden caller pointer (item 3.8)

**Files:**
- Modify: `toolchain/src/cc/parse_stmt.c:8411` (the refusal), the function prologue/`return` path, the call sites in `parse_expr.c` (direct and through a function pointer), the signature sidecar writer/reader in `symtab.c` (`--emit-sigs`), `emit.c` as needed
- Modify: `docs/userland-abi.md` ("Return values" table, the `struct` / `union` row)
- Test: `toolchain/tests/M46/struct_ret.c`, a two-TU fixture (follow an existing multi-TU fixture's layout under `toolchain/tests/`), `toolchain/tests/reject/struct_ret_undeclared.c`

**Interfaces:**
- Produces, the calling sequence (decided in the S0 design, 2026-09-27): the CALLER reserves a temporary of the struct's size in its own frame and passes its address as a hidden 4-byte argument, pushed LAST so it is the shallowest (offset 0, ahead of the named parameters); the callee copies its `return` value through it and also returns that address in `_fcc_fpr0` (so `f().m` reads through it).  A struct-returning function called with no declaration in scope is refused.

- [ ] **Step 1: Fixture** `struct_ret.c`: `struct pt { int x, y; }; struct pt mk(a, b)` returning `{a, b}`; check `mk(1,2).x + mk(3,4).y == 5` (two calls in one expression stay distinct), `s = mk(10, 20)`, `mk(5,6).y` through a function pointer `struct pt (*fp)()`, and a recursive caller; return 42 when all hold.
- [ ] **Step 2: Two-TU fixture:** the function in one file, its caller with an `extern struct pt mk();` declaration in the other; returns 42.
- [ ] **Step 3: Reject fixture:** `/* expect: struct */` -- a call to a struct-returning function defined LATER in the file with no earlier declaration.
- [ ] **Step 4: See all three fail.**
- [ ] **Step 5: Implement** the calling sequence above, including the sidecar carrying the struct return type so other TUs call it correctly.
- [ ] **Step 6: Document** in `docs/userland-abi.md`: replace the "not supported" row with the hidden-pointer sequence (pushed last, offset 0, address back in `_fcc_fpr0`).
- [ ] **Step 7: Run** goldens, rejects, `run_runtime.py --names struct_ret,<two-TU fixture>`.
- [ ] **Step 8: Commit** `fcc: a function may return a struct by value`, quoting A.10.1.

### Task 7a: a call through a function pointer at the end of a member chain

Found by the Task 1 audit: `netinet/if_ether.c:132` and `:339`, `(*ac->ac_if.if_output)(&ac->ac_if, m, &sa)`.

**Files:**
- Modify: `toolchain/src/cc/parse_expr.c` (the postfix call on a member-access chain)
- Test: `toolchain/tests/M46/fnptr_member_chain.c`

- [ ] **Step 1: Fixture:** `struct in { int (*fn)(); int z; }; struct out { int y; struct in s; };` with `fn` set to a function returning its argument plus 20; call `(*p->s.fn)(1)`, `p->s.fn(1)`, `(*q.s.fn)(1)` with `p` a pointer to and `q` a local `struct out`; return 42 when the three calls give 21 each and `p->s.z`/`q.y` are untouched (sum the calls, subtract 21).  Today `(*p->s.fn)(1)` and `p->s.fn(1)` fail "expected ';'" and `(*q.s.fn)(1)` fails "no such field"; `(*p->fn)(1)` and `(*q.fn)(1)` already pass.
- [ ] **Step 2: See it fail.**
- [ ] **Step 3: Implement:** a function call applies to a function-pointer value reached by any member/arrow chain, through the same lvalue walker as Task 6.
- [ ] **Step 4: Run** goldens and `run_runtime.py --names fnptr_member_chain`.
- [ ] **Step 5: Commit** `fcc: a call through a function pointer at the end of a member chain`, quoting A.7.3.2.

### Task 7b: a typedef of a sized array

Found by the Task 1 audit: `pdp/seg.h:127`, `typedef struct segm_reg mapinfo[2];` ("sized array typedef not yet supported").  The PDP `seg.h` itself is not ported, but the declaration is conforming C and fcc refuses it.

**Files:**
- Modify: `toolchain/src/cc/parse_stmt.c` (typedef declarators)
- Test: `toolchain/tests/M46/typedef_sized_array.c`

- [ ] **Step 1: Fixture:** `typedef int vec3[3]; typedef struct pt { int x, y; } pair[2]; vec3 g; pair gp;` and a local `vec3 v;`; check `sizeof(vec3) == 6`, `sizeof(pair) == 8`, store through `v[2]`, `g[1]`, `gp[1].y` and a `vec3` parameter (which adjusts to `int *`); return 42 when all hold.
- [ ] **Step 2: See it fail** ("sized array typedef not yet supported").
- [ ] **Step 3: Implement:** a typedef name may stand for an array of known size; declarations through it get that array type, and a parameter declared with it adjusts to a pointer (A.8.6.3, A.10.1).
- [ ] **Step 4: Run** goldens and `run_runtime.py --names typedef_sized_array`.
- [ ] **Step 5: Commit** `fcc: a typedef may name an array of known size`, quoting A.8.9.

### Task 8: Close S0

- [ ] **Step 1:** Re-run `$SCRATCH/netaudit/audit.sh`.  Expected: every remaining failure is classed "seam"; none is fcc's.
- [ ] **Step 2:** Run `tools/gate.sh`.  Expected: GATE GREEN.
- [ ] **Step 3:** Mark S0 done in `docs/history/plans/2026-11-03-net-multiplex-design.md` section 4.4 with the commits, and list the seam failures the audit left for S1's plan.  Commit `docs: net-mux S0 is done`.
