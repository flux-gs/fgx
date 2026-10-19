;==============================================================================
; kernelc.s - THE KERNEL-C SEAM.  The asm->C boundary, and the direct page it
; switches to.
;
; fcc-compiled code cannot run on the kernel's own direct page: fcc's register
; file wants $98-$FF laid out the way a TASK direct page is laid out, and
; $C0-$EF of the kernel's page is the console's persistent state.  So kernel C
; gets a page of its own, FGX_DP_KERNELC (include/kernel.s, the page below
; $C000, from tools/ninja/genconfig.py), and every asm->C call switches D to it
; and back.
;
; The slot map itself is src/kernel/far/fcc_dp.s, GENERATED from
; toolchain/lib/fcc_runtime.s by tools/gen_fcc_dp.py -- the compiler's copy is
; the only authored one.
;
;------------------------------------------------------------------------------
; WHERE KERNEL C LIVES: THE FAR BANK.
;
; Not a choice of convenience -- the two ABIs already match.  fcc emits
; functions that end in RTL and are reached by JSL, and the far bank's export
; contract independently REQUIRES exactly that: an export-table target ends in
; RTL, which tools/check_far_rtl_calls.py enforces.  The core kernel already
; reaches those targets with `JSL <farbank>:KFAR_slot` and a _kfpNNN patch site
; for the bank byte.  A C function therefore drops into the existing mechanism
; with no new call convention invented for it.
;
; The core bank could not host it in any case: 3.7 KB free there against 48 KB
; in the far bank.
;------------------------------------------------------------------------------
; REENTRANCY: the register file is SHARED, so kernel C is not reentrant.
;
; 2.11BSD's rule is the one to hold to, and it is stronger than "interrupt
; handlers must not call C": code running at raised spl never enters anything
; that can sleep.  Here that reads as -- an interrupt handler must not cross
; this boundary at all, because it would land on a direct page a suspended C
; frame still owns, and the clobber is silent.
;
; The bar is affordable today because there is exactly one caller class:
; syscall-context kernel code, which is cooperative.  It stops being free the
; moment kernel C can sleep, at which point the register file joins what the
; context switch saves -- the same way BSD saves registers.  It does NOT
; become a page per task; that would cost NPROC+1 pages of bank 0 to buy
; something the sleep rule already gives.
;
; THE SAVE IS 104 BYTES, NOT 68.  An earlier version of this comment priced it
; at 68 by taking the register file to be $BC-$FF.  It is $98-$FF: the eight
; promoted-local registers _fcc_fpr0..7 are FOUR bytes each and start at $98,
; and _fcc_stkfloor ($B9) and _fcc_fb ($BB) sit below $BC as well -- ten of the
; thirty-three slots are under the floor that number assumed.  It matters
; because the figure is the price of the sleep design and it lands on the
; context-switch path: 104 bytes each way, not 68.
;
; DO NOT COPY THAT NUMBER ANYWHERE.  tools/gen_fcc_dp.py now emits KC_DP_LO and
; KC_DP_BYTES into the generated slot map, and the switch code must use those.
; A literal in the switch is a second copy of the map, and when it disagrees
; the symptom is C state quietly corrupted across a sleep, in the victim rather
; than the culprit.  Guessing the widths is how the wrong number was produced
; twice: first 68, then 102 from a re-measurement that took _fcc_ptr2 at $FC
; for two bytes when it is four.
;
; The conclusion survives the correction: saving the file beats giving every
; task its own page.  As built (sched.s _kcDpSave) it is NPROC slots on a
; 128-byte stride, 1408 bytes, against 3072 for a page per task -- there is no
; pid-0 slot and none is needed.  An earlier version of this line said "NPROC+1
; save areas at 104 bytes is 1,248", which is the paragraph about number drift
; drifting; the implementation is the authority.
;==============================================================================

;------------------------------------------------------------------------------
; KCPROBE - **1 IS THE ONLY VALUE THAT BUILDS, AND THAT IS NOT A REGRESSION --
; IT IS WHAT THE SYSTEM BECAME.**  apple/fgx#204, measured 2026-08-26.
;
; THE ORIGINAL DESCRIPTION IS KEPT BELOW because the reasoning was right when it
; was written and the answer changed underneath it, which is worth being able to
; see.  It said: "is any kernel C actually COMPILED IN?  0 in a shipping
; kernel."  Both halves stopped being true.
;
;   The far bank's WHOLE fcc runtime is inside `DO KCPROBE=1' (far.s:643) --
;   fcc_rt.s, fcc_ktrap.s, fcc_runtime_data.s, kc_probe.s AND the VFS inward
;   seam.  Far slots 28-30 (`_Vfs_SeamEntry', `_Vfs_DescAlloc',
;   `_Vfs_DescFree') JMP into that payload from an UNGATED slot table, because
;   a slot table's shape is ABI and cannot depend on a build flag.  So at 0 the
;   far bank does not assemble, and if it did it would have a slot table
;   pointing at routines that are not there.
;
;   `_KcDp_Zero' is called ungated from boot (main.s ~316, where apple/fgx#225
;   moved it), so the CORE bank does not assemble at 0 either.
;
;   And kernel C is no longer optional in any case: vfs.mod's C sleeps in
;   `getblk' and `biowait' and src/modules/vfs/vfs.s states that the module is
;   NOT gated on this, and the TTY BANK is kernel C in its entirety with a real
;   sleep of its own since T4 increment 4 (`ttywait').
;
; MEASURED, not inferred: `kernel.kcprobe = 0' was built on 2026-08-26 and
; failed in three banks in turn.  The configuration this file called the
; SHIPPING one had been unbuildable since apple/fgx#225's fix landed, and
; nothing noticed because nothing builds it.
;
; WHAT WAS ACTUALLY DANGEROUS ABOUT THE CLAIM, and is now fixed: the kernel-C
; per-task register file (`_KcDp_Save'/`_KcDp_Rest' in sched.s) was gated on
; this knob, so the sentence above read as "a shipping kernel does not need
; it".  It is UNGATED now -- kernel C exists whatever this says, so the register
; file behind it does too.  What the knob still decides is `JSR _KcProbe', the
; boot self-test, and the far-bank payload; the probe's BODY is ungated for the
; reason the tty bank's probes' bodies were (a gated body makes the TRACKED patchsite tables
; differ per config).
;
; THE GUARD BELOW IS THE POINT.  Setting this to 0 used to produce three
; cryptic merlin32 errors in three different banks over three build attempts.
; It fails here instead, at the declaration, next to the reason.  Retiring the
; knob outright is the real cleanup and is deliberately NOT done here: it
; touches far.s's PUT structure, main.s, syscall.s and memmap.s, and it is not
; this change.
;
; --- the original text, kept: ---
;
; The SEAM -- these macros, the direct page, the slot map -- costs nothing when
; off: EQUs and MACs emit no bytes.  What the gate controls is the payload: the
; extracted fcc runtime, its traps, a compiled translation unit, the export
; slot that reaches it, and the boot-time call that proves the boundary works.
; That is ~3.9 KB of far bank, one of the 32 export slots, and a probe running
; on the boot path -- none of which belongs in a kernel nobody is debugging.
;
; WHEN THIS IS 0 NOTHING VERIFIES THE SEAM.  The boundary is exercised by
; exactly one thing, and it is behind this gate; a green smoke run on a
; production kernel says nothing about whether kernel C still works.
;------------------------------------------------------------------------------
KCPROBE         EQU     CFG_KERNEL_KCPROBE
                ERR     KCPROBE-1       ; see above: 0 does not assemble

;------------------------------------------------------------------------------
; VFSPROBE - does the boot path run the buffer cache's WIRING probe?
;
; A SECOND GATE, because the two questions are not the same one.  KCPROBE asks
; whether kernel C is compiled in and whether the seam works; that is
; self-contained and writes nothing.  This asks whether the buffer cache
; actually reaches the disk, and the only honest way to answer it is to WRITE
; two device blocks and read them back -- the cache's own flags cannot settle a
; question about the cache.
;
; So a kernel with this on scans every online device for a 2.11BSD superblock
; and scribbles on the one it finds, at every boot.  That is right for a
; development kernel and wrong for any other, however carefully the probe
; identifies its target first.  They shared KCPROBE until the write got
; noticed.
;
; VFSPROBE=1 implies KCPROBE=1: the probe is C, and without the payload there
; is nothing for slot 29 to point at.  The ERR below refuses the combination
; rather than letting it assemble into a slot that halts the machine.
;------------------------------------------------------------------------------
VFSPROBE        EQU     CFG_KERNEL_VFSPROBE
; UFSPROBE is the filesystem's own gate (the 1.10a superblock and the 1.10b
; allocators, split from VFSPROBE at 1.10b for bank room -- see
; cfg/system.cfg).  Implies KCPROBE like the others: the probe is C.  It is
; also an ALTERNATIVE to VFSPROBE rather than a companion; the two do not fit
; in one module bank, and the ERR at the end of src/modules/vfs/vfs.s is what
; says so.
UFSPROBE        EQU     CFG_KERNEL_UFSPROBE
; UFSVNPROBE is the filesystem's VNODE-OPERATION gate (the mount, the in-core
; inode, the read path, the name lookup and 1.12a's write path, split from
; UFSPROBE at 1.12a for bank room -- see cfg/system.cfg for the measurements).
; Implies KCPROBE like the others: the probe is C.  It is an ALTERNATIVE to
; UFSPROBE, not a companion -- 1.12a's shipping code alone put the two together
; over the ufs.mod bank -- and the ERR at the end of src/modules/ufs/ufs.s is
; what says so.
UFSVNPROBE      EQU     CFG_KERNEL_UFSVNPROBE
; UFSWPROBE is the WRITING half of the same, split from UFSVNPROBE at 1.12b for
; bank room a third time -- see cfg/system.cfg for the measurement.  Implies
; KCPROBE like the others, and is an ALTERNATIVE to both of the others.
; UFSANYPROBE -- either filesystem gate.  The module's driver, its _Probe_Drive
; call and its PROBE_ENTRY are shared by both, and `DO` takes one expression:
; writing the pair out twice at each of those sites is three more places for
; the two to drift apart.  It is a SUM rather than an OR because the ERR below
; has already refused the case where both are 1.
UFSWPROBE       EQU     CFG_KERNEL_UFSWPROBE
; UFSDEVPROBE is the DEVICE-FILE gate, split from UFSWPROBE at 1.13a -- and the
; first split forced by the size of the PROBE module rather than of the module
; under test.  cfg/system.cfg carries the measurement.
UFSDEVPROBE     EQU     CFG_KERNEL_UFSDEVPROBE
; VNOPSPROBE is the FILE/VNODE GLUE gate, UFS 1.7c.  It is in this family and
; not beside VFSPROBE because it uses the same driver, the same PROBE_ENTRY and
; the same scratch volume as the four above -- what it exercises is a different
; layer, not a different harness.
VNOPSPROBE      EQU     CFG_KERNEL_VNOPSPROBE
UFSANYPROBE     EQU     UFSPROBE+UFSVNPROBE+UFSWPROBE+UFSDEVPROBE+VNOPSPROBE
                DO      UFSVNPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.ufsvnprobe = 1 needs kernel.kcprobe = 1
                FIN
                DO      UFSPROBE=1
                ERR     1 ; kernel.ufsvnprobe and kernel.ufsprobe are exclusive
                FIN
                FIN
                DO      UFSWPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.ufswprobe = 1 needs kernel.kcprobe = 1
                FIN
                DO      UFSPROBE=1
                ERR     1 ; kernel.ufswprobe and kernel.ufsprobe are exclusive
                FIN
                DO      UFSVNPROBE=1
                ERR     1 ; kernel.ufswprobe and kernel.ufsvnprobe are exclusive
                FIN
                FIN
                DO      UFSDEVPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.ufsdevprobe = 1 needs kernel.kcprobe = 1
                FIN
                DO      UFSPROBE=1
                ERR     1 ; kernel.ufsdevprobe and kernel.ufsprobe are exclusive
                FIN
                DO      UFSVNPROBE=1
                ERR     1 ; kernel.ufsdevprobe and kernel.ufsvnprobe are exclusive
                FIN
                DO      UFSWPROBE=1
                ERR     1 ; kernel.ufsdevprobe and kernel.ufswprobe are exclusive
                FIN
                FIN
                DO      VNOPSPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.vnopsprobe = 1 needs kernel.kcprobe = 1
                FIN
                DO      UFSPROBE=1
                ERR     1 ; kernel.vnopsprobe and kernel.ufsprobe are exclusive
                FIN
                DO      UFSVNPROBE=1
                ERR     1 ; kernel.vnopsprobe and kernel.ufsvnprobe are exclusive
                FIN
                DO      UFSWPROBE=1
                ERR     1 ; kernel.vnopsprobe and kernel.ufswprobe are exclusive
                FIN
                DO      UFSDEVPROBE=1
                ERR     1 ; kernel.vnopsprobe and kernel.ufsdevprobe are exclusive
                FIN
                FIN
                DO      VFSPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.vfsprobe = 1 needs kernel.kcprobe = 1
                FIN
                FIN
                DO      UFSPROBE=1
                DO      KCPROBE=0
                ERR     1 ; kernel.ufsprobe = 1 needs kernel.kcprobe = 1
                FIN
                FIN

;------------------------------------------------------------------------------
; FLIPPING IT IS A THREE-STEP, AND ONE DIRECTION FAILS SILENTLY.
;
; The kernel-C call site carries a _kfpNNN marker, so it appears in the
; generated core->far bank-patch table -- and that table, like
; w5100_patchsites.s, is a TRACKED INPUT to the very assembly whose listing
; generates it.  It is only CHECKED by the build, never regenerated by it, so a
; config that changes the site list leaves both tables stale.  This is the
; first gated _kfp site in the tree; every other one exists unconditionally.
;
; Turning it OFF fails loudly: Merlin cannot evaluate `DA _kfp340+3` for a
; label that no longer exists, and the build stops.
;
; Turning it ON fails SILENTLY.  The assembly succeeds with the site simply
; missing from the table, so its JSL operand keeps the baked bank byte and the
; call lands in bank 0 -- a dead machine, from a build that reported success.
; The kernel-checks edge does catch it, but only after the image is written.
;
;   1. edit cfg/system.cfg     kernel.kcprobe = 0 | 1
;   2. ninja disk              (expected to FAIL when turning OFF)
;   3. python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt \
;              src/kernel/far_patchsites.s core
;      python3 tools/gen_w5100_patchsites.py \
;              build/fgx_S01_KernelMain_Output.txt src/kernel/w5100_patchsites.s
;   4. ninja disk              (again; the kernel moved when the tables did)
;
; Turning OFF additionally needs the `DA _kfp340+3` line deleted from
; far_patchsites.s by hand before step 2, because step 2 is what produces the
; listing step 3 reads.
;
; Verified both ways 2026-08-10: without the payload the kernel is 56391 B core
; / 11497 B far and passes `smoke`; with it, 56945 / 15517, and it passes
; `kcprobe` plus the whole runtime suite.  (The 2026-08-09 figures this line
; used to carry, 54193/54296, predate the telnetd merge -- a size quoted in a
; comment goes stale on somebody else's commit, so treat a mismatch here as
; documentation rot rather than as a failure.)
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; KC_ENTER / KC_LEAVE - bracket every asm->C call.
;
; Entry:  MX %00.  Exit: MX %00.  Clobbers A; X and Y are untouched.
;
; IT SWITCHES DBR AS WELL AS D, and that is not decoration.  fcc addresses
; globals and its own runtime scratch DBR-relative, and kernel C's statics --
; fcc_rt.s's scratch, fcc_runtime_data.s's cells, any C global -- live in the
; FAR bank.  A JSL into the far bank sets the program bank and leaves DBR
; pointing at the core kernel, so without this every one of those reads and
; writes would land at a far-bank offset in the wrong bank.
;
; The far bank is the live kernel bank plus one (main.s Far_Init computes it
; the same way), so the macro derives it with PHK rather than reading a
; variable -- correct under relocation, and usable before any init has run.
;
; THE PUSHES MEAN ARGUMENTS GO AFTER KC_ENTER, NOT BEFORE.  This is the whole
; trap in the macro: the callee reads its arguments at n,S relative to the JSL
; return address, so the saved bank and direct page wedged between the
; arguments and the JSL put every argument three bytes deep and the callee
; reads its own return address as argument one.  KC_ENTER first, then the
; pushes.
;
; KC_ENTER pushes and KC_LEAVE pulls, so the pair nests and an early exit
; between them leaks the frame -- keep the bracket on one path.
;
; The C callee is reached DIRECTLY through its export slot: the slot is a JMP,
; so the core's JSL frame is exactly the 3-byte return the fcc ABI expects, and
; the callee's RTL returns straight here.  There is no _fw_ shim, and there
; must not be one -- the PHB/PHK/PLB wrapper the console's exports use would
; insert four more bytes between the arguments and the callee's frame.  That is
; why DBR is set on this side.
;
;   MX      %00
;   KC_ENTER                ; bank and page switched BEFORE anything is pushed
;   LDA     #arg2
;   PHA
;   LDA     #arg1
;   PHA                     ; fcc reads arguments RIGHT-TO-LEFT, so arg1 last
; _kfpNNN JSL     KFAR_SLOT       ; bank byte baked 0, patched to the live far
;                                 ; bank at boot off the _kfpNNN label; the C
;                                 ; callee returns via RTL, which is what the
;                                 ; far bank's export contract already demands
;   TAY                     ; return value is in A; the PLAs clobber it
;   PLA                     ; caller pops its own arguments...
;   PLA
;   KC_LEAVE                ; ...then restores D and DBR, in that order.
;------------------------------------------------------------------------------
KC_ENTER        MAC
                PHB                     ; caller's data bank
                PHD                     ; caller's direct page
                SEP     #$20
                MX      %10
                PHK
                PLA                     ; A.lo = LIVE kernel bank
                INC                     ; far bank = kernel bank + 1
                PHA
                PLB                     ; DBR = far bank
                REP     #$20
                MX      %00
                LDA     #FGX_DP_KERNELC
                TCD
                <<<

KC_LEAVE        MAC
                PLD                     ; mirror image: D was pushed last
                PLB
                <<<

;------------------------------------------------------------------------------
; KTTY_KC_ENTER / KTTY_KC_LEAVE - the same bracket, for C compiled into the TTY
; KERNEL BANK (docs/history/plans/tty-kernel-bank.md).
;
; KC_ENTER above derives the FAR bank as the live kernel bank plus one; the tty
; bank is plus two, and that is the only difference.  A separate macro rather
; than a parameterised one because the derivation is three instructions and a
; parameter would make every call site read as though the bank were a choice.
;
; THE SINGLETON RULE STILL APPLIES, and it applies ACROSS the two banks: both
; brackets point D at the same FGX_DP_KERNELC, so far-bank C and tty-bank C are
; one register file between them.  Neither may be entered from inside the other.
;
; THE ONE EXCEPTION IS BELOW.  KTTY_KC_ENTER_IRQ selects a SECOND page (T6,
; apple/fgx#108), so C entered from an interrupt shares nothing with the
; syscall it interrupted.  That is an exception for the INTERRUPT and not a
; general relaxation: two contexts on this page are still one register file.
;
; Arguments go AFTER the bracket, for the reason KC_ENTER's comment gives at
; length: the pushes would otherwise sit between the arguments and the callee.
;------------------------------------------------------------------------------
KTTY_KC_ENTER   MAC
                PHB                     ; caller's data bank
                PHD                     ; caller's direct page
                SEP     #$20
                MX      %10
                PHK
                PLA                     ; A.lo = LIVE kernel bank
                INC
                INC                     ; tty bank = kernel bank + 2
                PHA
                PLB                     ; DBR = tty bank
                REP     #$20
                MX      %00
                LDA     #FGX_DP_KERNELC
                TCD
                <<<

KTTY_KC_LEAVE   MAC
                PLD                     ; mirror image: D was pushed last
                PLB
                <<<

;------------------------------------------------------------------------------
; KTTY_STUB2 - a whole INWARD stub for a two-argument C entry.  ]1 = the C.
;
; THE NINTH COPY IS WHY THIS EXISTS.  apple/fgx#268 moves core-bank seam
; wrappers into this bank one at a time, and every one of them lands as the
; same seventeen lines: stage, PHB/PHD/PHK/PLB, point D at FGX_DP_KERNELC,
; re-push the two arguments right-to-left, pile-call the C, park the result
; past the pops.  `_KTty_Modem' is the copy this macro was lifted from, and
; ttybank.s carries eight more that differ only in a target and a return.
;
; THE STACK ARITHMETIC IS NOT DERIVED, IT IS CARRIED, and that is the whole
; reason a macro is safe here.  KTTY_KC_ENTER pushes PHB+PHD = 3 bytes and so
; does this stub, so the core wrapper's `LDA 4,S' and `LDA 8,S' are this
; stub's `LDA 4,S' and `LDA 8,S' unchanged.  Moving a wrapper is a transcription
; and #268 priced the risk as a transcription slip; a macro has nothing left to
; transcribe.
;
; `PEA *+7' IS THE RETURN ADDRESS, and it is spelled that way because merlin32
; resolves local labels before macro expansion, so no label inside a MAC can be
; a branch or PEA target -- the same constraint KTTY_KC_LEAVE_IRQ records as
; `BEQ *+6'.  The 7 is the three PEA bytes, the PHK, the second PEA's three and
; the RTL, less one: RTL adds one to what it pops.
;
; THE C IS REACHED BY A PILE CALL because fcc emits RTL routines and a
; same-bank JSL would bake this file's ORG bank ($09) into the operand, not the
; bank the kernel runs in.  PHK supplies the live one; check_far_rtl_calls.py
; is what notices when someone writes the JSR instead.
;
; IN:  A = arg1 (conventionally the tty index), X = arg2.  MX %00.
; OUT: A = the C's return value.  Y IS PRESERVED; X IS NOT, having been an
;      argument.  That is `_KTty_Modem's contract, which is in turn the
;      contract of the core wrappers this shape replaces.
;------------------------------------------------------------------------------
KTTY_STUB2      MAC
                MX      %00
                PHY
                PHA                     ; staged: arg1
                PHX                     ; staged: arg2
                PHB
                PHD
                PHK
                PLB                     ; DBR = the LIVE tty bank
                LDA     #FGX_DP_KERNELC
                TCD
                LDA     4,S             ; D(2) B(1) then arg2
                PHA                     ; arg2  (fcc reads RIGHT-TO-LEFT,
                LDA     8,S             ;   so arg1 goes last)
                PHA                     ; arg1
                PHK
                PEA     *+7             ; the byte after the RTL, less one
                PHK
                PEA     ]1-1
                RTL                     ; pile call into the C
                TAY                     ; park it; the pops clobber A
                PLA                     ; drop the two arguments
                PLA
                PLD
                PLB
                PLA                     ; drop the two staged words
                PLA
                TYA
                PLY
                RTL
                <<<

;------------------------------------------------------------------------------
; KTTY_KC_ENTER_IRQ / KTTY_KC_LEAVE_IRQ - the tty bank's bracket for C entered
; from an INTERRUPT.  apple/fgx#108 T6.
;
; THIS IS THE PAIR THAT LIFTS THE SINGLETON RULE ABOVE, and it lifts it by
; giving the interrupt a context of its own rather than by relaxing anything.
; A C context is THREE things and the register file is only the first:
;
;   D  -> FGX_DP_KERNELC_IRQ, so fcc's $98..$FF is a different 104 bytes from
;         the one the interrupted syscall is standing on.  That is the whole of
;         "a second register file": fcc addresses its file at fixed DIRECT-PAGE
;         offsets (toolchain/lib/fcc_runtime.s), so the file a context uses IS
;         whatever page D names.  No compiler change; one constant.
;   S  -> FGX_STK_KIRQ, because fcc puts FRAMES on the hardware stack and the
;         heartbeat runs on whatever it interrupted.  That is a task's kernel
;         stack, FGX_KSTK_SIZE bytes, measured at $01BE high-water with 190
;         spare -- not a margin, a coin toss.
;   _fcc_stkfloor, which comes free with the page and is SEEDED for it
;         (_KcDpIrq_Zero, main.s).  It is the first working fcc stack guard in
;         this kernel: the floor on FGX_DP_KERNELC is left at zero, and a floor
;         of zero passes every test.
;
; BOTH OF THOSE ADDRESSES ARE IN THE BANK-0 LANGUAGE CARD, AND THE LANGUAGE
; CARD IS READ-MAPPED TO ROM WHILE THE FIRMWARE HEARTBEAT INTERRUPT HANDLER IS
; DISPATCHING -- which is the one interrupt this bracket exists to serve.  So
; ENTER banks it in and LEAVE puts back what it found (apple/fgx#242).
;
; MEASURED, 2026-08-27, from inside the heartbeat body, 1,477 ticks, WITH A
; POSITIVE CONTROL: STATEREG reads $08 during the dispatch, against $00 for the
; state `_LC_MapRam' establishes at boot -- so it differs in bit 3 and nothing
; else.  A store/read-back at FGX_STK_KIRQ ($00FCF0) and at
; FGX_DP_KERNELC_IRQ+$98 ($00FA98) failed on every one of those ticks, while
; the same store/read-back against LOW bank 0 ($00030C, the $030A..$031F gap)
; failed on none -- the control that separates "the card is ROM" from "the
; sampler never ran or its CMP is inverted".
;
; BIT 3 IS THE WHOLE OF THE STATE WE CAN READ.  "Bit 3 = RDROM status (read
; only RAM/ROM (0/1))" -- IIgs Firmware Reference, Appendix E, STATEREG.  The
; write-enable flip-flop is not in STATEREG and is not readable at all ("The
; only way that you can find out whether or not the language-card RAM is
; write-enabled is by trying to write" -- IIgs Hardware Reference ch.3, quoted
; at boot_console.s:136-140), which is why LEAVE re-runs a soft switch instead
; of writing a saved STATEREG back.  Same reasoning, same idiom, opposite
; direction: `boot_console.s' forces ROM and restores RAM; this forces RAM and
; restores ROM.
;
; WHY `BEQ *+6' AND NOT A LABEL: merlin32 resolves local labels before macro
; expansion, so neither `]1' nor `:label' can be a branch target inside a MAC
; (both measured -- "Can't find format for element").  The 6 skips the four-byte
; `LDAL' below it, and there is nothing else between.
;
; LEAVE DESTROYS A AND NOTHING ELSE.  X IS LIVE ACROSS IT at every call site --
; each one does `TAX' to save the C return value before popping its arguments
; and reads X after -- so the restore may not use an index register, which is
; what rules out computing the soft-switch address instead of branching to it.
;
; IT IS NOT REENTRANT WITH ITSELF, and nothing makes it so.  ENTER resets S to
; the top of the interrupt stack, so a second entry from inside the first would
; drop the outer frame on the floor.  What guarantees there is no second entry
; is that the ISR runs with I set for its whole duration -- so this is a rule
; the caller keeps, stated here rather than enforced.
;
; THE CALLER'S S RIDES THE NEW STACK, not a static.  It is the one place this
; bracket already owns, it cannot be aliased, and it costs no storage -- the
; same reasoning apple/fgx#235 settled for the heartbeat's signal byte.
;
; DESTROYS A AND X.  KC_ENTER destroys only A; this one needs a register to
; carry the new stack top past the TSC that reads the old one, and X is it.
; Said here because a caller with a live X and a memory of the other macro is
; exactly how this would be found the hard way.
;
; Arguments go AFTER the bracket, as for every other bracket in this file --
; and here it is not merely a convention: the arguments must be pushed on the
; INTERRUPT stack, which does not exist until ENTER has run.
;------------------------------------------------------------------------------
KTTY_KC_ENTER_IRQ MAC
                SEP     #$20
                MX      %10
                LDAL    $E0C068                 ; STATEREG
                AND     #$08                    ; bit 3 = RDROM (see above)
                PHA                             ; caller's stack, below the two
                                                ;   pushes: LEAVE pulls it last
                LDAL    $E0C08B                 ; read RAM, write-enable, bank 1
                LDAL    $E0C08B                 ;   ...TWICE.  "Perform two reads
                                                ;   to $C083; then ... language
                                                ;   card write enabled" -- IIgs
                                                ;   Firmware Reference, Appendix
                                                ;   E, STATEREG.  Same as
                                                ;   main.s _LC_MapRam.
                PHB                     ; caller's data bank  (caller's stack)
                PHD                     ; caller's direct page
                PHK
                PLA                     ; A.lo = LIVE kernel bank
                INC
                INC                     ; tty bank = kernel bank + 2
                PHA
                PLB                     ; DBR = tty bank
                REP     #$20
                MX      %00
                TSC                     ; A = the caller's stack pointer
                LDX     #FGX_STK_KIRQ_TOP
                TXS                     ; ...and from here we are on our own
                PHA                     ; the caller's S, first word down
                LDA     #FGX_DP_KERNELC_IRQ
                TCD
                <<<

KTTY_KC_LEAVE_IRQ MAC
                PLA                     ; the caller's stack pointer
                TCS                     ; back onto the caller's stack
                PLD                     ; mirror image: D was pushed last
                PLB
                SEP     #$20
                MX      %10
                PLA                     ; STATEREG bit 3 as ENTER found it
                BEQ     *+6                     ; it was RAM: ENTER's force is
                                                ;   what was already there
                LDAL    $E0C08A                 ; put ROM back: read ROM,
                                                ;   write-protect, bank 1
                REP     #$20
                MX      %00
                <<<

;------------------------------------------------------------------------------
; MOD_KC_ENTER / MOD_KC_LEAVE - the same bracket, for C compiled into an FGXM
; MODULE rather than the far kernel bank.
;
; SIMPLER THAN KC_ENTER, and the difference is the whole point.  KC_ENTER has to
; DERIVE its target bank -- the far bank is the live kernel bank plus one, so it
; does PHK/PLA/INC.  A module's C lives in the module's OWN bank, and PHK in a
; module already yields exactly that, so PHK/PLB is the whole bank switch.  The
; module needs no idea where it was loaded, which is the property that makes a
; C module possible at all.
;
; USE THIS AND NOT PLAIN PHK/PLB.  fcc addresses globals, string literals and
; its own runtime scratch (fcc_runtime_data.s) DBR-relatively, and a module runs
; with DBR = the KERNEL bank.  Without the switch every one of those reads and
; writes lands at a module-relative offset in the kernel's bank -- apple/fgx#93
; exactly, but across every global the module has rather than one table.
;
; D matters as much as DBR.  fcc keeps its register file, frame pointer and
; stack floor in the direct page, so the C cannot run a loop on the caller's D.
; FGX_DP_KERNELC is a SINGLETON: kernel C is compiled -fno-safepoints and runs
; to completion inside a syscall, which is what makes one register file safe.
; Two C contexts live at once would share it and corrupt each other, so a C
; module must not be re-entered from far-bank C or from itself.
;
; THE PUSHES MEAN ARGUMENTS GO AFTER MOD_KC_ENTER, exactly as for KC_ENTER: the
; callee reads its arguments at n,S relative to the JSL return address, and the
; saved bank and direct page wedged between would put every argument three bytes
; deep.  Bracket first, then push, then JSL.
;
; The callee is fcc output and therefore ends in RTL, so it is reached by JSL
; even though it is in the same bank.
;------------------------------------------------------------------------------
MOD_KC_ENTER    MAC
                PHB                     ; caller's data bank
                PHD                     ; caller's direct page
                PHK
                PLB                     ; DBR = THIS module's bank (see above)
                LDA     #FGX_DP_KERNELC
                TCD
                <<<

MOD_KC_LEAVE    MAC
                PLD                     ; mirror image: D was pushed last
                PLB
                <<<

;------------------------------------------------------------------------------
; THIS FILE EMITS NO BYTES, AND THAT IS LOAD-BEARING.
;
; far.s PUTs it BEFORE its `ORG FGX_KFAR_CODE`, alongside the other EQU-only
; includes, because the macros must be defined before the export table uses
; them.  Merlin32 does not pad between two ORGs -- it emits only real bytes --
; so a single byte emitted from here lands on top of the export table and
; displaces every slot in it.  That was not hypothetical: a page-zeroing
; routine drafted here assembled GREEN with its code at 08/0006 and export
; slot 0 at 08/0006 as well.  The `ERR` after the table in far.s now catches
; it.
;
; Zeroing FGX_DP_KERNELC belongs with the first kernel C that runs on it --
; _fcc_stkfloor ($B9) and _fcc_fb ($BB) are both read before they are written
; -- and it belongs AFTER the ORG, with the rest of the far bank's code.
;------------------------------------------------------------------------------

