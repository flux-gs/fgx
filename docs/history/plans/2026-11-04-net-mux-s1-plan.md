# Net-mux S1 -- machine seam and packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2.11BSD's networking code builds into loadable kernel modules with its real machine seam, and on a probe kernel it loads, links across banks, allocates mbufs, checksums, masks interrupts and runs `netintr`, while the shipping kernel's networking is unchanged.

**Architecture:** Several code banks share ONE data bank, so 2.11BSD's globals stay ordinary globals and its sources stay verbatim.  Two small fcc options and one generator provide that.  The seam headers select the word-size arms of the PDP-11 code and the layout arms of the VAX code.  `netintr` runs from the kernel's existing deferred-work drain, never from an interrupt.

**Tech Stack:** fcc (`toolchain/src/cc/`), Merlin32, FGXM modules, ninja via `tools/ninja/gen.py`, MAME via `tools/mame_test/`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md`, sections 4.2, 4.3 and 4.4.  Read it.

## Calls this plan makes that the spec does not

Each is for the maintainer's review.  Task 8 writes the accepted ones into the spec.

1. **One shared data bank, not import tables for data.**  Spec 4.3 says "a multi-module split with import tables (the VFS precedent)".  That precedent covers calls only.  A module's C runs with DBR on its own bank (`MOD_KC_ENTER`, `include/kernelc.s`), so one module cannot name another's global, and the stack's layers share named globals: the mbuf macros' `mfree`, `mclfree`, `mbstat` and `mclrefcnt` at 26 direct macro sites across the `.c` files, plus `ifnet`, `in_ifaddr`, `ipintrq`, `netisr`, `ip_defttl` and more (a source scan, not a link; Task 4 gives the real list).  With DBR on a shared data bank those are plain globals, a cross-bank call is a `JML` stub that adds no stack frame, and no BSD source changes.  Far-pointer externs in fcc were rejected: they touch every global-addressing path and slow every crossing access.  `#define ifnet (*p)` was rejected: it also rewrites `struct ifnet`.
2. **`pdp11` is not defined.**  The S0 audit compiled under `-Dpdp11`.  With 4-byte pointers that arm is WRONG: `ih_pad`, `ipq_pad` and `ipf_pad` (`netinet/ip_var.h:20,38,76`) exist to pad 2-byte pointers up to the VAX layout, so here they would misplace every overlaid IP header, and `BYTE_ORDER` becomes `PDP_ENDIAN` (`netinet/ip.h:26`).  A new symbol `fgx` selects per site (Task 3's table).  S0's "all 23 files compile" has to be re-earned under it.
3. **`splnet` masks nothing; `splimp` and `splhigh` set the I flag.**  `netintr` only runs at the drain sites, and kernel code is never preempted (Model A, `src/kernel/sched.s`), so nothing can enter the network code past a `splnet` except across a sleep, which 2.11BSD also allows.  Masking interrupts through TCP processing would stop the VBL heartbeat.
4. **`netintr` rides `_Tty_DrainOutPend`** (`src/kernel/ttyv.s:2105`).  That routine already runs at every drain site at the cost of one test.  The core bank has 12 bytes free, which does not fit a second drain.
5. **The callout facility and bpf stay in S2,** following the 4.4 table over 4.3's "S1 is 4.3 minus the driver".  **`in_cksum` lands here,** because IP cannot link without it; the fused drain version stays with the driver in S2.
6. **The modules are built and staged but not loaded by a shipping boot.**  S1 therefore costs no process banks.  S2 adds them to `/etc/rc.in`.

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR.
- Announce every checkout and rebuild of the tree.
- Toolchain-first: an fcc defect is fixed in fcc with a fixture in `toolchain/tests/M46/` (oracle 42) that fails first; never in a ported file, never with sed over output.
- Before an fcc change, open the governing K&R Appendix A page (`kr_c`) and QUOTE the deciding sentence in the commit.
- Name the BSD file and function in every seam commit.  Every ported file gets a `docs/PROVENANCE.md` row and the required header; `tools/check_provenance.py` holds this.
- Ported `.c` files stay verbatim.  Only the sites in Task 3's table and the `##` of `uipc_domain.c`'s `ADDDOMAIN` differ; each is listed in its provenance row.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.
- Comments describe the current state only.
- MAME runs headless (`SDL_VIDEODRIVER=dummy`); never `git stash`.
- The core bank has 12 bytes free (`tools/check_kernel_ceiling.py`, measured at 5458ddf).  S1 spends at most those 12.
- Do not add a test to `tools/gate.sh`: its time budget has no headroom.  `netprobe` is a gated-config manifest, as `ufsprobe` is.
- `tools/gate.sh` green at the end of every task that changes code.

## Review Focus

1. **A cluster below its mbuf.**  `m_off` is `u_short` and `MCLGET` stores a pointer difference, so a cluster at a lower address wraps; a plain 32-bit add in `mtod` carries into the next bank.  Expect the right address either way.  Task 4 case 3.
2. **`MGET` at interrupt level.**  `(ms&0340) <= 0100` (`h/mbuf.h:110`) reads a PDP PS.  FGX's `spl` returns the I bit, so that test is always true and an interrupt-level `M_DONTWAIT` would run the protocol drains.  Expect plain failure with no drain.  Task 5 case 4.
3. **`netintr` scheduled from inside `netintr`.**  Expect it to run again before returning to the task, as `pdp/net_trap.s` loops.  Task 6 case 3.
4. **A wait channel crossing 16 bits.**  `KSVC_SLEEP` takes a 16-bit channel and BSD passes far addresses, so a channel can alias a fixed kernel channel (`tools/check_wchans.py`).  Expect a sleeper woken only by its own channel, or by an alias on a path that re-tests.  Task 5 case 5.
5. **The stack under TCP.**  A task's kernel stack is 512 bytes (`FGX_KSTK_SIZE`), and fcc frames live on it.  Expect a measured answer before S2 relies on it.  Task 7.

---

### Task 1: fcc options for a shared data bank

**Files:**
- Modify: `toolchain/src/cc/main.c`, `globals.c`, `fcc.h`, `emit.c` (the indirect call at about lines 3324 and 3388), and the file-scope declaration path in `parse_stmt.c`
- Test: `toolchain/tests/M46/shared_data_flag.sh`, `toolchain/tests/M46/common_tentative.sh`

**Interfaces:**
- Produces: `--shared-data` (implies `--module-bank`) and `--common`, consumed by Task 2's ninja rule.

- [ ] **Step 1: Read K&R.**  A.10.2 for tentative definitions, A.7.3.2 for the call.  Quote both in the commits.
- [ ] **Step 2: Write the failing tests.**  `shared_data_flag.sh` compiles a function that calls through a pointer, once with `--module-bank` and once with `--shared-data`.  It asserts the first output has the `PLB` sequence around the call and the second has none between the target frame and the return label, and that `RTL` still reads the bank from the pointer.  `common_tentative.sh` compiles `int a; int b = 2; int c[3];` with `--common` and asserts the data output has `*COMMON a 2` and `*COMMON c 6` lines and an ordinary definition for `b`.
- [ ] **Step 3: Run them.**  Expected: FAIL, unknown option.
- [ ] **Step 4: Implement `--shared-data`.**  The indirect call reads the bank from the cell, as `--module-bank` does, and leaves DBR alone both ways.  `&function` cells stay `MOD_FN_PTR`.
- [ ] **Step 5: Implement `--common`.**  A file-scope definition with no initializer and no `static` emits `*COMMON name bytes` where it emitted `DS`.  An initialized definition is unchanged.
- [ ] **Step 6: Run the tests and the suite.**  `cd toolchain/tests && ./run.sh && ./run_reject.sh`.  Expected: the new tests pass and goldens are byte-identical, since neither option is on by default.
- [ ] **Step 7: Commit each option separately.**

### Task 2: Packaging and the cross-bank probe

**Files:**
- Create: `tools/gen_bsdnet_split.py`, `src/kernel/bsdnet/split.list`, `src/kernel/bsdnet/netprobe.c`, `src/kernel/bsdnet/netprobe2.c`, `src/modules/bsdnetd/`, `src/modules/bsdnet0/`, `src/modules/bsdnet1/`, `src/modules/bsdnet2/` (each with its `.link.s` and root `.s`), `tools/mame_test/tests/netprobe.json`
- Modify: `tools/ninja/gen.py`, `tools/gen_modplace.py` (`ORDER` append, `OWN_BANK` ordinals 8-11), `src/kernel/modload.s` (`MOD_BANK_MAX` 8 to 12), `include/modules.s` (`VT_BSDNET`), `include/kernelc.s` (`BSDNET_KC_ENTER`/`LEAVE`), `include/config.s`, `tools/check_module_data_refs.py`

**Interfaces:**
- Consumes: Task 1's options.
- Produces: `split.list`, one line per TU: `<stem> <module>`, modules being `d`, `0`, `1`, `2` by source placement.  `BSDNET_KC_ENTER` (`PHB`, `PHD`, DBR from the module's `_bnDataBank` cell, `D = FGX_DP_KERNELC`).  Config gate `kernel.netprobe`.

The layout the generator produces:

| Module | Holds | Assembled |
|---|---|---|
| `bsdnetd` | every `.data.s`, one set of `fcc_runtime_data.s`, each `*COMMON` name once | first |
| `bsdnet0`-`2` | a generated header of `EQU`s for the data symbols; a jump table at the start of the text with one `JMP` per exported function, in `split.list` order; one `name JML $00nnnn` stub per imported function; the TU code; `fcc_runtime.s` | after `bsdnetd` |

Slots are fixed by list position, so code modules never need each other's listings and the build has no cycle.  A `*COMMON` name with an initialized definition takes the definition; two different sizes for one name fail the build.  A `MOD_FN_PTR` cell in `bsdnetd` resolves to the target's slot.  Every module registers under `VT_BSDNET`; the LAST to load stamps all stub and cell bank bytes from `_modBankTab`, then enters `bsdnet_init()`.

- [ ] **Step 1: Write the failing probe.**  `netprobe.c` (in `bsdnet0`) and `netprobe2.c` (in `bsdnet1`) print `bsdnet: ok` or `bsdnet: BROKEN <n>` through `klog`:
  1. a global written in bank 0 reads back in bank 1, and the reverse;
  2. a `*COMMON` global declared in both TUs is one object (a write through its address in one, a read by name in the other);
  3. a direct call from bank 0 to bank 1 passes two `int`s and a pointer, and returns a `long`;
  4. a call through a function-pointer cell in the data bank reaches bank 1 and returns;
  5. a string literal in `netprobe2.c`, read from `netprobe.c` through a returned pointer, compares equal;
  6. `long` multiply and divide run in both banks with a live value in the other (the runtime's scratch is shared).

  `netprobe.json` requires `kernel.netprobe=1`; `screen_contains` `bsdnet: ok` and `fgx#`; `screen_lacks` `bsdnet: BROKEN`, `BRK`, `PANIC`, `GUARD stkhwm`.
- [ ] **Step 2: Run it.**  Expected: FAIL; the modules do not exist.
- [ ] **Step 3: Implement** the generator, the module roots, the bracket and the ninja edges.  Follow `ufsprobe` for the gate and for how a gated module joins the boot's load list, so `tools/check_modload_lists.py` still holds.  Add `tools/check_module_data_refs.py`'s module-level waiver for the four modules, and refuse a data image over 64 KB with an assembly-time `ERR`.
- [ ] **Step 4: Run it.**  Build with `kernel.netprobe = 1`, then `FGX_MAME_PRIMARY=inject python3 tools/mame_test/run.py netprobe`.  Expected: PASS, and not marked `(cached)`.
- [ ] **Step 5: Prove it can fail.**  Build case 1 with `--module-bank` in place of `--shared-data` and see `bsdnet: BROKEN 1`.  Restore.
- [ ] **Step 6: Check the shipping config.**  With `kernel.netprobe = 0`, `tools/check_kernel_ceiling.py` passes and `tools/gate.sh` is green.
- [ ] **Step 7: Commit.**

### Task 3: Port the source and write the seam

**Files:**
- Create: `vendor/2.11BSD/usr/sys/` additions for every network file not yet vendored; `src/kernel/bsdnet/{sys,net,netinet,h,machine}/`, ported copies; `src/kernel/bsdnet/machine/{machparam.h,seg.h,net_mac.h}`; `src/kernel/bsdnet/h/param.h`, `user.h`
- Modify: `docs/PROVENANCE.md`, `tools/ninja/gen.py`

**Interfaces:**
- Produces: a ninja edge per TU with `--pile --shared-data --common -fno-safepoints -Dfgx -DKERNEL -DINET -DSUPERVISOR`; the port set of spec 4.2 plus `net/af.c`, `net/raw_cb.c`, `net/raw_usrreq.c` (2.11BSD has them outside `uipc_`, and `raw_ip.c` needs them).

Every `pdp11` site in the port set, and the arm `fgx` takes:

| Site | Arm | Why |
|---|---|---|
| `netinet/ip.h:26`, `tcp.h:26` `BYTE_ORDER` | `LITTLE_ENDIAN` | the 65816's order |
| `netinet/ip_var.h:20,38,76` pads | none | 4-byte pointers already give the VAX layout |
| `h/mbuf.h:120,191` | pdp11 | a static pool; no `m_clalloc` |
| `sys/uipc_mbuf.c:116` | pdp11 | same |
| `net/if.h:150` `IFQ_MAXLEN`, `h/socketvar.h:63` `SB_MAX` | pdp11 | 16-bit `int` counts |
| `netinet/in_systm.h:33` `UCHAR` | pdp11 | used unconditionally by the callers |
| `h/types.h:31` | neither | FGX has no `label_t` |
| `net/netisr.h:26` `setsoftnet` | new | Task 6 |
| `sys/uipc_syscalls.c:139,740` | decide on reading | record it in the row |

`mbuf.h`'s data model, in the `fgx` arm: `MSIZE` stays 128, `MMINOFF` 10, `MTAIL` 4, so `MLEN` is 114 (a VAX has 112, and `struct socket`, `inpcb` and `tcpcb` fit it).  `dtom(x)` masks through `long`.  `mtod(x,t)` keeps the bank and adds `m_off` in 16 bits.  `cltom` and `mtocl` work on the low 16 bits and assume one bank, which holds: the pool is one static array pair in `bsdnetd`.

`net_mac.h`: each `KScall`/`SKcall` macro becomes the direct call, since there is no supervisor space.

The S0 stubs were in scratch and are gone; their content is in spec 4.4's S0 row.  Port `FMARK`, `FDEFER`, `FREAD` and `FWRITE` from `vendor/4.3BSD-Reno/sys/file.h`; do not port `h/signal.h`; write `ADDDOMAIN` with `##`.

- [ ] **Step 1: Write the failing check.**  Add the edges.  Run `ninja` on them.  Expected: FAIL at the first missing header.
- [ ] **Step 2: Copy and vendor** in one commit per layer, verbatim, with provenance rows.
- [ ] **Step 3: Write the seam headers,** reading each PDP original first.
- [ ] **Step 4: Compile the set.**  Every file compiles.  A failure that is fcc's becomes its own commit under the fcc rule above; expect some, because the non-pdp arms were never audited.
- [ ] **Step 5: Run `tools/gate.sh`.**  Expected: green, nothing shipping having changed.
- [ ] **Step 6: Commit.**

### Task 4: Link the stack; mbufs run

**Files:**
- Create: `src/kernel/bsdnet/machine/net_leaf.s` (`panic`, `printf`, `log`, `bcopy`, `bzero`, `bcmp`, `sleep`, `wakeup`), `src/kernel/bsdnet/machine/s2_stubs.c`
- Modify: `src/kernel/bsdnet/split.list`, `netprobe.c`

**Interfaces:**
- Consumes: Task 2's generator, Task 3's objects.
- Produces: `bsdnet_init()` calling `mbinit()` and `domaininit()`; the real per-bank size report.

`uipc_syscalls.c` and `uipc_usrreq.c` compile but do not link until S3 and S4, which give them a file table.  `s2_stubs.c` holds what S2 replaces, each calling `panic` by name: `timeout`, `untimeout`, the callout users' entry.  Leaf routines reach the kernel the way `kc_sys.s` and the KSVC table do; read those first and reuse them rather than adding core entries.

`u`: a reduced `struct user` in `bsdnet/h/user.h` with only the fields the linked set reads.  It is ONE global, so it is not yet safe across a sleep; S3's plan owns that, because S3 is the first phase with a task behind a socket.

- [ ] **Step 1: Write the failing cases** in `netprobe.c`, after Task 2's:
  1. `sizeof(struct mbuf) == 128`, `MLEN == 114`, `sizeof(struct ipovly) == 20`, `sizeof(struct ip) == 20`, `sizeof(struct tcpiphdr) == 40`, and `struct inpcb`, `struct tcpcb`, `struct socket` each `<= MLEN`;
  2. `dtom(mtod(m, char *) + k) == m` for `k` of 0, 1 and `MLEN - 1`;
  3. `MCLGET` on an mbuf above its cluster and on one below it: `M_HASCL` is true, `mtod` equals the cluster's address, and both reach `MFREE` and return the cluster to `mclfree` (Review Focus 1);
  4. `m_get(M_DONTWAIT, MT_DATA)` until NULL returns exactly the free count without a panic, every mbuf in one bank; freeing all restores `mbstat`;
  5. `m_copy`, `m_pullup` and `m_adj` over a three-mbuf chain give the expected bytes.
- [ ] **Step 2: Run it.**  Expected: FAIL at link, listing the undefined names.  Print the COUNT of names.
- [ ] **Step 3: Implement** the leaf routines and stubs; place TUs in `split.list` with the mbuf and socket code in `bsdnet0`, `if` and `ip` and `udp` in `bsdnet1`, TCP in `bsdnet2`, moving a TU if a bank overflows.
- [ ] **Step 4: Run it.**  Expected: PASS.
- [ ] **Step 5: Record the sizes** of all four modules in the commit body, against spec 7's memory estimate.
- [ ] **Step 6: Run `tools/gate.sh`; commit.**

### Task 5: `spl`, `in_cksum`, sleeping

**Files:**
- Create: `src/kernel/bsdnet/machine/in_cksum.s`
- Modify: `src/kernel/bsdnet/h/mbuf.h`, `machine/machparam.h`, `tools/check_spl_balance.py`, `netprobe.c`, `docs/PROVENANCE.md`

**Interfaces:**
- Produces: `splnet()`, `splimp()`, `splhigh()`, `splx(s)`; `in_cksum(struct mbuf *m, int len)`, 65816 assembly, the semantics of `pdp/in_cksum.c`.

`splimp`/`splhigh` set I and return the I bit as it was, as `kc_spltty` does; `splnet` returns the bit and changes nothing; `splx` restores it.

- [ ] **Step 1: Write the failing cases:**
  1. `splimp` then `splx` restores I from both a clear and a set start; `splnet` leaves I as found;
  2. `in_cksum` of one mbuf against values computed by an independent Python one-liner and written into the test;
  3. `in_cksum` of the same bytes split across three mbufs with an odd-length middle, and one with a zero-length mbuf, gives the same answer;
  4. with the pool empty and I set, `m_get(M_DONTWAIT, ...)` returns NULL with `mbstat.m_drain` unchanged (Review Focus 2);
  5. a sleeper on a channel in the data bank is woken by `wakeup` of that address, and not by `wakeup` of a fixed kernel channel with the same low 16 bits (Review Focus 4).  If the case shows aliasing, map the channel as far as `kc_sleep`'s callers already do, and name that in the commit.
- [ ] **Step 2: Run them.**  Expected: FAIL.
- [ ] **Step 3: Implement,** with the `fgx` arm of `MGET` testing `ms` for the masked state in place of the PS comparison.  Extend `tools/check_spl_balance.py` to the bsdnet directory; a verbatim upstream shape it flags is seen and decided, as `ttyunblock` was.
- [ ] **Step 4: Run them.**  Expected: PASS, not cached.
- [ ] **Step 5: Run `tools/gate.sh`; commit** per seam.

### Task 6: `netintr` at the drain

**Files:**
- Create: `src/kernel/bsdnet/machine/net_intr.c`
- Modify: `src/kernel/bsdnet/net/netisr.h`, `src/kernel/tty/ld_hooks.s` or a sibling, `src/kernel/ttyv.s` only if the budget allows, `include/modules.s`, `docs/PROVENANCE.md`, `netprobe.c`

**Interfaces:**
- Consumes: `_kTtyOutAny`, `KTTY_KC_TTDRAIN` (`src/kernel/ttyv.s:2105`).
- Produces: `setsoftnet()`; `netintr()`, ported from `pdp/net_trap.s` (`ENTRY(netintr)`), with the `IP` and `RAW` arms; a tty-bank vector `_netDrainVec`, 0 until the stack loads.

Flow: `schednetisr` sets `netisr` under upstream's own `splimp`, and `setsoftnet` sets the core's `_kTtyOutAny`.  The drain enters the tty bank as it does today; after `ttdrain`, the tty bank calls `_netDrainVec` if nonzero, through `BSDNET_KC_ENTER`.  No C context is live at that point, so the singleton register file holds.  A shipping kernel with no stack loaded pays one test.

Reaching `_kTtyOutAny` from a module takes at most one new KSVC, at most 8 bytes in core; with Task 2's 4 that is the whole 12.  If the ceiling check refuses it, move a core routine to the far bank in its own commit rather than dropping the drain.

- [ ] **Step 1: Write the failing cases:**
  1. after `schednetisr(NETISR_RAW)`, a probe counter is still 0 before the probe's C returns (not synchronous);
  2. the counter reaches 1 after a `sleep` or a return through a syscall boundary;
  3. a handler that schedules itself once runs twice in one `netintr` entry (Review Focus 3);
  4. a compute-bound task running: the drain still fires within a second, which is the safepoint's yield and states the worst-case latency in the commit.
- [ ] **Step 2: Run them.**  Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them.**  Expected: PASS.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**

### Task 7: Measure the kernel stack under the stack

**Files:**
- Create: `tools/net_stack_depth.py`
- Modify: `docs/history/plans/2026-11-03-net-multiplex-design.md` (section 7)

**Interfaces:**
- Consumes: the bsdnet module listings.
- Produces: worst-case stack bytes for three roots: `netintr` to `ipintr` through `tcp_input`, `tcp_output`, `ip_output` to `if_output`; `sosend` from a system call to the same leaf; `soreceive`.

Static: frame sizes from fcc's prologues, the call graph from the listing, the indirect calls (`pr_input`, `pr_usrreq`, `pr_output`, `if_output`) from a table written in the tool.  It is a report with no build edge, since a number it prints decides a design point once.

- [ ] **Step 1: Write its check.**  `--self-test` on a small invented listing with a known answer, including one recursion, which it must name rather than loop on.
- [ ] **Step 2: Run it.**  Expected: FAIL, then implement it and see it pass.
- [ ] **Step 3: Run it on the real listings.**  Print the deepest chain for each root.
- [ ] **Step 4: Write the numbers into spec section 7,** against `FGX_KSTK_SIZE` 512.  If a root exceeds about 300 bytes (the room a syscall leaves), STOP and bring the numbers to the maintainer, because the answer is a design choice: a larger kernel stack costs bank-0 space per task, and a dedicated network stack changes what can sleep.
- [ ] **Step 5: Commit.**

### Task 8: Close S1

**Files:**
- Modify: `docs/history/plans/2026-11-03-net-multiplex-design.md`, `docs/fcc-known-issues.md` if touched, `docs/CHANGELOG.md` if the branch's convention wants it

- [ ] **Step 1: Update the spec.**  Mark S1 done with the commit range, correct 4.3's import-table sentence, S0's `-Dpdp11` claim, and section 3 with the accepted calls above; list what S2 inherits: the `s2_stubs.c` names, the single `u`, and `/etc/rc.in`.
- [ ] **Step 2: Verify.**  Expected: `tools/gate.sh` green at `kernel.netprobe = 0`; `netprobe` green at 1; a final `tools/check_kernel_ceiling.py` figure in the commit.
- [ ] **Step 3: Leave the tree** on `feat/net-mux`, built at `kernel.netprobe = 0`, and say so.
- [ ] **Step 4: Commit.**
