# Net-mux S2 -- substrate running Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a probe kernel the 2.11BSD stack sends and receives real packets: ARP resolves the gateway, an ICMP echo goes out over the Uthernet II's MACRAW socket 0 and the reply comes back, loopback works, timers fire and netdump still captures, ready for the maintainer's run on real hardware.

**Architecture:** `netintr` moves to a stack of its own, with fcc's stack floor set so an overflow halts with a diagnostic.  The W5100 driver is an `ifnet` in C over a few assembly primitives, drained from `netintr` and never from the interrupt, which only marks the drain.  Callouts are 2.11BSD's list, ticked from the same drain.  bpf becomes a tap the driver feeds.

**Tech Stack:** fcc, Merlin32, `tools/build_bsdnet.py`, FGXM modules, MAME via `tools/mame_test/`, `examples/marinetti/w5100s-ds-v128e.pdf`.

**Spec:** `docs/history/plans/2026-11-03-net-multiplex-design.md`, sections 4.1, 4.3, 4.4, 4.4.1, 5 and 7.  Read them.

## Calls this plan makes that the spec does not

For the maintainer's review.  Task 7 writes the accepted ones into the spec.

1. **`netintr` gets its own 1024-byte stack.**  Spec 7 asks S2 to choose between that, keeping the 512-byte switch stack with a halting check, and running `netintr` only at syscall exit.  Measuring first, as the spec says, is impossible: the reachable chain does not exist until this phase runs it, and the static figure of about 460 bytes, plus about 30 of entry and an interrupt frame, already leaves no margin against a driver that is a guess.  Syscall exit only is rejected because the idle case then needs a task to wake, adding latency to the machine's most common case.  The cost is 1 KB in the mapped `$D000` bank, whose `$D700`-`$DDFF` holds nothing.  `netintr` never sleeps and the drain is not re-entered, so one stack serves both drain sites.  It is painted, and Task 3 reports its real high-water mark, so a wrong size shows.
2. **The modules stay out of `/etc/rc.in` for S2.**  S1's inherited list put this here.  Loading the stack takes socket 0 for good, and socket 0 is the fourth endpoint ftp's data connection needs, while nothing yet uses the kernel stack.  So a default boot in S2 would lose a socket for nothing.  S3 adds them, when UDP moves and frees a socket in the same change.
3. **Drain, then checksum.**  Spec 4.3 folds the checksum into the copy from the chip.  S2 copies plainly and lets `ip_input` call `in_cksum`, because the fused loop has to reach into `ip_input`'s check, which is a change to ported code with no measured need yet.  Section 5's numbers decide it at S4.
4. **The callout list is private to the network modules** (`machine/net_callout.c`), the same algorithm as `sys/kern_clock.c`.  Spec 4.3 says "a callout facility"; nothing else in the kernel asks for one.  A second user moves it.
5. **The driver reaches the chip through slot-indexed long addressing,** `LDAL $E0C085,X`, not the self-modified sites net.mod and bpf.mod use.  By the 65816's cycle table as I recall it, not yet checked against the manual, `LDA long` and `LDA long,X` both take 5 cycles, so it should cost nothing and needs no patch table, and it keeps the driver able to run a second card.

## Global Constraints

- Branch `feat/net-mux` in `~/apple/fgx`.  Commit there; never push, never open a PR.
- Announce every checkout and rebuild of the tree.
- Toolchain-first: an fcc defect is fixed in fcc, with a fixture in `toolchain/tests/M46/` (oracle 42) that fails first.
- Before an fcc change, open the governing K&R Appendix A page (`kr_c`) and QUOTE it in the commit.  Name the BSD file and function in every seam commit.
- Every written-for-FGX file has its `docs/PROVENANCE.md` row and header; `tools/check_provenance.py` holds this.
- Nothing Uthernet-specific above the driver (spec section 2, anti-goals): only `net/if_w5.c` and `machine/w5_asm.s` name the chip.
- Protocol code never runs from an interrupt; that is what `splnet` masking nothing rests on.  The interrupt may only mark.
- The core bank has 20 bytes free; S2 spends at most 16 (Tasks 2 and 4).  The tty bank is the place for anything else.
- Commit bodies are informational, American spelling, ASCII only, no Co-Authored-By or session trailers.  Comments describe the current state only.
- MAME runs headless (`SDL_VIDEODRIVER=dummy`), and a passing run must not be marked `(cached)`.  Never `git stash`.
- Every new test gets a mutation or control that shows it can fail, recorded in the ledger.
- No new test goes in `tools/gate.sh`.  `tools/gate.sh` is green at the end of every task that changes code, built at `kernel.netprobe = 0`.

## Review Focus

1. **A burst larger than the ring.**  With 2 KB of socket 0 receive buffer until S4, a burst overruns it.  Expect dropped frames, a counted `if_ierrors`, and a machine that carries on with a consistent read pointer.  Task 4 case 44.
2. **A frame the chip reports with a nonsense length,** from a corrupt 2-byte header or a read racing the chip.  Expect the socket closed and reopened and the count bumped, never a copy of a wild length into an mbuf.  Task 4 case 45.
3. **Mbufs exhausted during a drain.**  `netintr` cannot wait.  Expect the frame skipped by advancing `Sn_RX_RD`, `if_iqdrops` counted, and no spin.  Task 4 case 46.
4. **A sleep inside `netintr`,** on the shared network stack, where a second entry would overwrite the first.  Expect a panic that names it.  Task 1 case 34.
5. **The card absent, or socket 0 already held by a hardware connection.**  Expect the stack to load with `lo0` only and say so, or to refuse to attach with EBUSY as bpf does, and no touch of the chip.  Task 4 case 47.

---

### Task 1: S1's leftovers, and `netintr`'s own stack

**Files:**
- Modify: `tools/ninja/genconfig.py`, `include/kernel.s`, `include/config.s`, `tools/check_bank0_geometry.py`, `src/kernel/bsdnet/machine/net_asm.s`, `machine/net_kern.c`, `machine/net_intr.c`, `machine/bsdnet_init.c`, `tools/build_bsdnet.py`, `netprobe.c`, `cfg/system.cfg`, `netprobe5.c`
- Test: `tools/mame_test/tests/netprobe.json`

**Interfaces:**
- Produces: `FGX_STK_NET` (`$DA00`), `FGX_STK_NET_SIZE` (1024), `FGX_STK_NET_TOP`; `int net_in_intr` (nonzero while `netintr` runs); `int net_stack_hwm()` (bytes used, read from the paint).

- [ ] **Step 1: Do S1's deferred minors that this phase would trip on.**  `net_hookinit()` runs first in `bsdnet_init`, because S2's initializers schedule.  `check_mx` runs on bsdnetd's listing.  Fix the stale text in `netprobe.c`'s header and `cfg/system.cfg`.  Note beside `SYS_KCALL` in `include/modules.s` that `machine/net_asm.s` reads its bank byte.  Commit.
- [ ] **Step 2: Write the failing cases** in `netprobe5.c`.  Hook, on its first pass: case 32, the address of a local is inside `FGX_STK_NET`..`FGX_STK_NET_TOP`; case 33, a function that recurses with a large local array until it traps halts through `_fcc_stkoflow`, tested by a separate gate, `kernel.netprobe = 2`, whose manifest `netstkovf.json` expects the trap's message and `lacks` a clean prompt.  Case 34, at `kernel.netprobe = 2` as well, `sleep()` called from the hook panics with `sleep in netintr`.  Failures log `bsdnet: BROKEN <n>`.
- [ ] **Step 3: Run them.**  Expected: case 32 fails.
- [ ] **Step 4: Implement.**  `genconfig.py` derives `CFG_STK_NET` below the switch stack, `check_bank0_geometry.py` holds it clear of the slot pages and the switch stack.  `netintr_enter` saves S, moves to `FGX_STK_NET_TOP`, saves and sets `_fcc_stkfloor` to `FGX_STK_NET` plus a margin for the trap's own frame, sets `net_in_intr`, and undoes all of it on the way out.  `sleep()` panics when `net_in_intr` is set.  `bsdnet_init` paints the stack with `$A5A5`.
- [ ] **Step 5: Run them.**  Expected: `netprobe` and `netstkovf` pass, not cached.  Mutate `netintr_enter` to stay on the caller's stack and see case 32.
- [ ] **Step 6: Run `tools/gate.sh`; commit.**

### Task 2: Callouts

**Files:**
- Create: `src/kernel/bsdnet/machine/net_callout.c`
- Modify: `machine/s2_stubs.c`, `machine/net_intr.c`, `src/kernel/toolbox.s`, `netprobe5.c`, `docs/PROVENANCE.md`, `vendor/2.11BSD/usr/sys/sys/kern_clock.c`, `src/kernel/bsdnet/split.list`

**Interfaces:**
- Produces: `timeout(int (*fun)(), caddr_t arg, int t)`, `untimeout(int (*fun)(), caddr_t arg)`, as `sys/kern_clock.c`; `net_softclock()`, called first in `netintr`.
- Consumes: `kc_ticks()`.

`NCALLOUT` is 20.  `conf/param.c`'s `NCALL` sizes a whole kernel; this table holds only what the stack arms: `pfslowtimo`, `pffasttimo`, `if_slowtimo`, `arptimer`, with room for the driver and for S3.  Overflow panics, as upstream's does.

The heartbeat marks the drain every 8th tick, about 133 ms, by adding to `_HBTickTask`'s body: `LDA _kSystemTicks / AND #7 / BNE +3 / INC _kTtyOutAny`, 11 bytes.  That also makes the driver's backstop poll (Task 4).  Its cost on a kernel with no network modules is one `kc_ttdrain` line scan 7.5 times a second.

- [ ] **Step 1: Write the failing cases:** case 35, `timeout(f, 0, 30)` has not fired at once, and fires once after 30 ticks within a bound of 8 more; case 36, `untimeout` before it fires stops it; case 37, three armed out of order fire in order of expiry; case 38, `pfslowtimo` has run at least once, read from a counter the hook samples, so domaininit's timers really do run.  The answers arrive after load, so the hook logs `bsdnet: callouts ok` or `bsdnet: BROKEN <n>`.
- [ ] **Step 2: Run them.**  Expected: FAIL, the stubs do nothing.
- [ ] **Step 3: Implement.**  `net_softclock` takes elapsed ticks from `kc_ticks`, walks the delta list as `softclock` does, and calls each due function with `net_in_intr` set and I clear.
- [ ] **Step 4: Run them.**  Expected: PASS.  Mutate the delta arithmetic in `timeout` and see case 37.
- [ ] **Step 5: Run `tools/gate.sh`; check `tools/check_kernel_ceiling.py`; commit.**

### Task 3: `lo0` and ICMP through the real path

**Files:**
- Create: `src/kernel/bsdnet/netprobe6.c`
- Modify: `machine/bsdnet_init.c`, `split.list`, `tools/net_stack_depth.py`, `docs/history/plans/2026-11-03-net-multiplex-design.md`

**Interfaces:**
- Produces: `bsdnet_init` in `sys/sys_net.c` `netstart`'s order: `mbinit`, `loattach`, `ifinit`, `domaininit`, then `lo0` addressed 127.0.0.1 through `in_control(SIOCSIFADDR)`; `net_echo(u_long dst)`, the probe's ICMP echo sender.

Read `vendor/2.11BSD/usr/sys/sys/sys_net.c` `netstart` first, and vendor it.

- [ ] **Step 1: Write the failing cases** in `netprobe6.c`: case 40, `lo0` is `IFF_UP` and has its address; case 41, `net_echo(127.0.0.1)` builds an ICMP echo in an mbuf, sends it with `ip_output`, and `icmpstat.icps_inhist[ICMP_ECHO]` and `[ICMP_ECHOREPLY]` both advance once the drain has run, read by the hook, which logs `bsdnet: lo0 echo ok`; case 42, a deliberately bad header checksum counts `ipstat.ips_badsum` and is not answered, which shows `in_cksum` is really being checked.
- [ ] **Step 2: Run them.**  Expected: FAIL.
- [ ] **Step 3: Implement.**  A failure here is most likely in ported code meeting the machine for the first time; a defect found goes in its own commit with a BSD reference, not in the probe.
- [ ] **Step 4: Run them.**  Expected: PASS.  Log `net_stack_hwm()` after the echo as `bsdnet: net stack <n> of 1024`.
- [ ] **Step 5: Correct `tools/net_stack_depth.py`** (S1's deferred M2): exclude `PRU_CONTROL`, add `raw_usrreq -> rip_output`, and print the measured figure beside the static one in spec section 7.
- [ ] **Step 6: Run `tools/gate.sh`; commit.**

### Task 4: The MACRAW driver

**Files:**
- Create: `src/kernel/bsdnet/net/if_w5.c`, `src/kernel/bsdnet/machine/w5_asm.s`, `tools/mame_test/tests/netw5.json`
- Modify: `src/kernel/uthernet.s`, `tools/gen_kernel_exports.py`, `tools/build_bsdnet.py`, `machine/net_intr.c`, `machine/bsdnet_init.c`, `split.list`, `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: `arpresolve`, `arpinput`, `ipintrq`, `schednetisr` (upstream); `_u2Slot`, `_u2SltBit`, `_u2Locked`, `_u2Imr`, `_u2RxReady`, `_w5SockInUse` through a generated `bsdnet` export list, which makes these modules build-locked as net.mod and bpf.mod are.
- Produces: `w5attach()`, `w5output(ifp, m, dst)` shaped as `pdpif/if_de.c`'s `deoutput`; `w5rint()`, called from `netintr` after `net_softclock`; assembly `w5_lock()`, `w5_unlock()`, `w5_rreg(reg)`, `w5_wreg(reg, val)`, `w5_rxcopy(char *dst, int n)`, `w5_txcopy(char *src, int n)`.

**First read the chip.**  `examples/marinetti/w5100s-ds-v128e.pdf` section 4.6 says "MACRAW Mode SOCKET 0 does not receive any Data Packet for other SOCKET but it receives ARP Request and PING Request", which agrees with spec 4.1 on what S3's coexistence needs.  That document is the W5100S and the Uthernet II carries the W5100, so fetch WIZnet's W5100 datasheet, vendor it under `examples/`, and read its MACRAW section and `MR_PB` before writing the driver.  If they disagree with 4.1, stop and report it.

Facts already read: `Sn_MR` `$44` is MACRAW with the MAC filter; `Sn_SR` `$42` is open; a frame carries a 2-byte big-endian length that includes itself; `Sn_RX_RD` commits with `Sn_CR` RECV `$40`; a socket-0 receive buffer is at `$6000` with mask `$07FF` at `RMSR = $55`, which stays until S4.

The existing lazy ISR (`_Uthernet2_ISR`, `src/kernel/uthernet.s`) already sets `_u2RxReady` and disarms `IMR`.  Add one store there, `INC _kTtyOutAny`, on the socket-0 RECV arm, 3 bytes in core.  `w5rint` re-arms `_u2Imr` after draining.  The chip's address pointer is shared with net.mod: every driver sequence holds `_u2Locked`, as net.mod's `U2_LOCK` does, with interrupts open except around the flag.

Attach claims `_w5SockInUse` bit 0, and returns EBUSY as `bpf_open` does if it is held.  It sets `MR_PB`, so `icmp_input` answers pings rather than both.  It reads SHAR, SIPR, SUBR and GAR back from the chip, which DHCP filled, and gives the `ifnet` that address through `in_control`.

- [ ] **Step 1: Write the failing cases,** in `netw5.json` (real network, not in the gate) and the probe: case 43, attach logs `w5: attached, <mac>` and `if_flags` has `IFF_UP`; a broadcast ARP from the LAN raises `if_ipackets`; case 44, a burst from the host (`tools/mame_test`'s `peer_script`, flooding UDP to the machine) overruns the ring and the machine still answers afterward, with `if_ierrors` nonzero or `if_ipackets` below the count sent; case 45, the probe forces a bad length through a test seam in `w5rint` and the socket is reopened and counted; case 46, with the pool emptied, a frame is dropped, `if_iqdrops` rises and `netintr` returns; case 47, with no card (run with MAME's slot empty) the stack logs `w5: no card, lo0 only`, and with socket 0 held the attach logs `w5: socket 0 busy`.
- [ ] **Step 2: Run them.**  Expected: FAIL.
- [ ] **Step 3: Implement `w5_asm.s`.**  `X` is `_u2Slot << 4` for every chip access, so `LDAL U2_DAT_0,X`, with `U2_DAT_0` the slot-0 address.  Save and re-assert `SLTROMSEL` from `_u2SltBit` as the ISR does.  `w5_rxcopy` and `w5_txcopy` copy with `Y` as the count and handle the ring's wrap, which is the caller's arithmetic but the primitive's address reload.
- [ ] **Step 4: Implement `if_w5.c`.**  Output builds the Ethernet header at the front of the chain, copies to the transmit ring when `Sn_TX_FSR` has room, and otherwise queues on `if_snd`, as `destart` does, and counts.  Trailers off: `if_flags` has `IFF_NOTRAILERS`.  `w5rint` loops while `Sn_RX_RSR` is nonzero; a frame goes into one mbuf if it fits in `MLEN`, else a cluster, else a chain, and dispatches by `ether_type` as `deread` does.  It bounds its own loop at 8 frames so a flood cannot hold the drain, and asks for another pass with `setsoftnet`.
- [ ] **Step 5: Run them.**  Expected: PASS.  Controls: skip the re-arm and see the interrupt path go quiet with the 133 ms poll still draining, which shows the backstop works; remove the length check and see case 45.
- [ ] **Step 6: Run `tools/gate.sh`; check the ceiling; commit** the assembly and the driver separately.

### Task 5: ARP and an echo on the wire

**Files:**
- Modify: `netprobe6.c`, `tools/mame_test/tests/netw5.json`
- Create: `tools/mame_test/tests/netnoreply.json`

**Interfaces:**
- Consumes: `net_echo` (Task 3), the attached `w5` interface (Task 4).

This is spec S2's proof.

- [ ] **Step 1: Write the failing cases:** case 48, `net_echo(gateway)`, GAR's address, leads to `bsdnet: arp resolved <mac>` then `bsdnet: echo reply from gateway`, logged by the hook from `arptab` and `icps_inhist[ICMP_ECHOREPLY]`; `netnoreply.json` sends to an unused LAN address and expects `bsdnet: arp unresolved` after `arptimer` has aged the entry, with no echo line, which is the control.  Case 49: hardware TCP still works beside it: `ftp` to the LAN peer, a `get`, checked against the host's copy, with the stack loaded, proving the chip routes by port as 4.1 says.
- [ ] **Step 2: Run them.**  Expected: FAIL on the first; a pass here without Task 4's code would mean the chip answered, not the stack.
- [ ] **Step 3: Implement,** fixing what the first real traffic finds, each in its own commit.
- [ ] **Step 4: Run them.**  Expected: PASS, not cached.
- [ ] **Step 5: Commit.**

### Task 6: bpf as a tap

**Files:**
- Modify: `src/modules/bpf/bpf.s`, `src/modules/bpf/w5100_patchsites.s`, `src/kernel/bsdnet/net/if_w5.c`, `src/kernel/bsdnet/machine/w5_asm.s`
- Create: `tools/mame_test/tests/netdumptap.json`

**Interfaces:**
- Produces: `w5_tap(struct mbuf *m, int outbound)`, called from `w5rint` and `w5output`.
- Consumes: the capture block at `_bpfBase` (`BPF_CapState`, `BPF_SnapBuf`, `BPF_SNAPLEN` 60), its record format `{caplen.w, datalen.w, frame...}`, netdump's reader.

`bpf_open` asks `Mod_FindVtable` for `VT_BSDNET`.  With the stack loaded it leaves socket 0 alone and sets `BPF_CapState`; with no stack it keeps today's direct capture, so a default boot's netdump does not change.  `bpf_read` in tap mode takes the next record from a ring of 8 in the capture block, which grows to hold them, and bumps `BPF_Sat` on overflow, so netdump's `[saturated]` line keeps its meaning.  The driver copies the first 60 bytes under `splimp`; it never blocks.

- [ ] **Step 1: Write the failing test:** `netdumptap.json` loads the stack, runs `netdump` in the background, sends the Task 5 echo, and expects netdump's lines for the ARP request, the ARP reply, the echo and the reply: so both directions.  A second run with no stack loaded expects today's capture.
- [ ] **Step 2: Run it.**  Expected: FAIL; `bpf_open` answers EBUSY.
- [ ] **Step 3: Implement.**  Regenerate `src/modules/bpf/w5100_patchsites.s`.
- [ ] **Step 4: Run it.**  Expected: PASS.  Control: skip the outbound tap and see the requests go missing.
- [ ] **Step 5: Run `tools/gate.sh`; commit.**

### Task 7: Measure, hand over, close

**Files:**
- Modify: `docs/history/plans/2026-11-03-net-multiplex-design.md`, `docs/CHANGELOG.md` if the branch's convention wants it

- [ ] **Step 1: Measure and record in spec sections 5 and 7:** the module footprint in banks; `net stack <n> of 1024` after echoes and a flood; round-trip time of the echo; frames per second `w5rint` drains in the flood; drop counts.  Update the risks.
- [ ] **Step 2: Update the spec.**  S2 done with its commit range; the calls above; what S3 inherits: `/etc/rc.in`, the single `u`, `sleep`'s signal answer, `s2_stubs.c`'s remainder.  If the W5100 datasheet changed anything in 4.1, correct it.
- [ ] **Step 3: Verify.**  Expected: `tools/gate.sh` green at `kernel.netprobe = 0`; `netprobe`, `netpartial`, `netw5`, `netnoreply`, `netdumptap` green at 1, not cached.
- [ ] **Step 4: Leave a hardware image and STOP.**  Build `kernel.netprobe = 1` to a named image outside the tree's default output, with one page in `docs/history/` naming the commands to type on the real IIgs and what each should print.  Spec section 7 requires the maintainer's run before S3 starts: "If a real chip does not hand port-unclaimed TCP and UDP to MACRAW while other sockets are open, the 'UDP first, TCP later' phasing goes".  Report and wait.
- [ ] **Step 5: Leave the tree** on `feat/net-mux`, built at `kernel.netprobe = 0`, and say so.  Commit.
