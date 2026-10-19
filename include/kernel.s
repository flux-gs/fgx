;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     kernel.s
; Purpose:  Kernel data structures, constants, and equates
; Author:   FGX Development Team
; Created:  2025-02-01
;
; This file defines all kernel data structures, system call numbers,
; error codes, and constants. These definitions form the kernel ABI.
;
;==============================================================================

;==============================================================================
; KERNEL MEMORY LAYOUT
;==============================================================================

; Bank assignments
; Note: Banks $00/$01 have IIe compatibility issues ($C000-$FFFF is I/O/LC)
; FGX uses Bank $02 for kernel to avoid these complications.
;
; Bank layout policy: kernel-owned banks pack contiguously from $02.
; Userland starts at FGX_BANK_USER and grows upward.  No userland code
; should hardcode a bank number — go through the EQU here.  Any bump
; to FGX_BANK_USER should be a one-line change.
;
; The Memory Manager claims are the loader's (src/boot/stage2.s), sized from
; cfg/system.cfg through include/config.s: the kernel handle and the
; rest-of-OS handle below.  Nothing in the kernel keeps a claim table of its
; own.
FGX_BANK_SYSTEM      EQU $00         ; Direct page, stacks, system vars
FGX_BANK_AUX         EQU $01         ; IIe aux RAM - reserved, not used
FGX_BANK_KERNEL      EQU $02         ; Kernel code and data
FGX_BANK_KMOD_FIRST  EQU $05         ; First bank of the module window at the
                                     ;   static $02 build.  The live layout is
                                     ;   the REST_*_OFF offsets below (module
                                     ;   window x3 for vfs/ufs/ufsdir, then the
                                     ;   kernel heap).
FGX_BANK_USER        EQU $0A         ; First user memory bank

; --- The two Memory Manager handles.  The sizes and the rest-of-OS region
;     offsets are DERIVED by tools/ninja/genconfig.py from cfg/system.cfg
;     (kernel.banks, rest.*) into include/config.s, the one source stage2.s and
;     tools/mkfgxunix.py read too.  The regions are bank offsets from the
;     runtime rest base (_restBaseBank), which is REST_BASE_DEFAULT at the
;     static $02 build. ---
KERNEL_BANKS         EQU CFG_KERNEL_BANKS       ; kernel handle: core, far, tty.
                                     ;   The loader claims exactly this many,
                                     ;   bank-aligned (_LoaderExactClaim).
RESTOFOS_BANKS       EQU CFG_RESTOFOS_BANKS     ; rest-of-OS claim: the fixed
                                     ;   regions + the user pool.  A working
                                     ;   set, not a ceiling: the kernel heap and
                                     ;   user banks grow at runtime from banks
                                     ;   left with the MM.
RESTOFOS_MIN_BANKS   EQU CFG_RESTOFOS_MIN_BANKS ; floor: the fixed regions +
                                     ;   rest.min_user_banks.  The loader halts
                                     ;   below it.
REST_BASE_DEFAULT    EQU $03         ; $02-build rest base (== old console bank)
; Rest-of-OS region bank-offsets from _restBaseBank:
REST_CONSOLE_BANK_OFF EQU CFG_REST_CONSOLE_BANK_OFF ; console char/attr
REST_FONTS_BANK_OFF   EQU CFG_REST_FONTS_BANK_OFF   ; console fonts
REST_KMOD_FIRST_OFF   EQU CFG_REST_KMOD_FIRST_OFF   ; module window (vfs/ufs/ufsdir)
REST_HEAP_FIRST_OFF   EQU CFG_REST_HEAP_FIRST_OFF   ; kernel heap boot arenas
REST_USER_FIRST_OFF   EQU CFG_REST_USER_FIRST_OFF   ; user memory
; THE MODULE WINDOW holds the modules the boot program stages from /fgxunix
; because they ARE the filesystem (vfs, ufs, ufsdir); every other module, and
; any filesystem type mounted later, is loaded through the root into pool banks.
; tools/mkfgxunix.py refuses a segment table with more kmod segments than the
; window holds, reading rest.kmod_banks from include/config.s, so stage 2 can
; never MVN a module over the heap's first bank.  The heap's boot arenas grow
; past themselves into pool banks on demand (_Kmem_GrowOneArena).

; Kernel bank layout ($02xxxx)
FGX_VECTORS     EQU     $020000         ; Entry vectors
FGX_GLOBALS     EQU     $020400         ; Kernel global variables
FGX_TASK_TBL    EQU     $020800         ; Task table (TCBs)
FGX_CODE        EQU     $021000         ; Kernel code start.  The kernel is
                                        ; MM-relocated (not pinned to bank $02); these
                                        ; are bank-relative offsets.  Live below the
                                        ; code start: FGX_VECTORS ($0000), FGX_GLOBALS
                                        ; ($0400), FGX_TASK_TBL ($0800; NPROC TCBs of
                                        ; 64 B, 32 x 64 = 2,048 B, ending flush at
                                        ; $1000 -- the table has NO pid-0 slot,
                                        ; Task_Alloc scans slots 0..NPROC-1 and pid =
                                        ; slot+1).  Raising NPROC past 32 moves this
                                        ; up 64 B per task.  Lockstep: fgx.link.s
                                        ; ORG, stage2 KERNEL_DEST/KERNEL_DEST_LO, the
                                        ; check_kernel_ceiling.py self-test sample;
                                        ; check_bank0_geometry.py fails a table that
                                        ; runs into the code.
FGX_DATA        EQU     $02EF50         ; Kernel data start: the code (both
                                        ; segments) ends below it and the static
                                        ; data (memmap.s's DUM FGX_DATA) starts
                                        ; here.  Raising it is code room paid for
                                        ; in data room.  The binding guard is NOT
                                        ; the top of the bank but `ERR
                                        ; KMem_KGlobals_end-1/$02FE00` in
                                        ; memmap.s: the main DUM region must end
                                        ; below $FE00, and the KGlobals block at
                                        ; DUM $02FF00 is separately anchored so it
                                        ; does NOT shift with FGX_DATA (raising the
                                        ; canary pin with it is a mistake -- the ERR
                                        ; catches that).  KMem_end lands at $02FDEE,
                                        ; leaving 18 B.  tools/check_kernel_ceiling.py
                                        ; derives the code ceiling from this EQU.
FGX_HEAP        EQU     $030000         ; Kernel heap boundary (bumped from $02C000; reclaims bank-$02 tail)

;--- Far kernel bank -----------------------------------------------------------
; A SECOND statically linked kernel image (bin/fgxfar.bin), a segment of
; /fgxunix loaded by stage 2 and reached by cross-bank JSL.  NOT an FGXM module:
; it is present before the FS exists.  See docs/kernel-banks.md.
;
; LoaderAllocKernelBank claims KERNEL_BANKS contiguous bank-aligned banks for
; the core, far and tty images, so
;
;     far bank == live kernel bank + 1
;
; which the kernel derives from PHK.  There is no second NewHandle, no
; rest-anchor slot and no publication step.  Far_Init still verifies KFAR_MAGIC
; in that bank before using it, so a failed load is caught rather than assumed
; away.
;
; FGX_KFAR_BANK is an ASSEMBLY-TIME convention only, exactly as modules ORG at
; $05.  $08 is the documented "reserved for kernel expansion" bank above; at
; runtime the bank always comes from PHK, never from this constant.
FGX_KFAR_BANK   EQU     $08             ; assembly-time ORG bank (runtime: PHK)
FGX_KFAR_CODE   EQU     $080000         ; far-bank code start
FGX_KFAR_DATA   EQU     $08EC40         ; far-bank statics start (= code ceiling)

;------------------------------------------------------------------------------
; THE TTY BANK - a THIRD statically linked kernel image, at live kernel bank + 2.
;
; Same shape as the far bank above and for the same reason, one bank further on.
; It exists because the BSD tty layer does not fit anywhere else: ~46,900 bytes
; of ported C against 18,411 free in the far bank, and it must be present from
; boot because the input discipline is reached from the 60 Hz heartbeat, long
; before Mod_LoadConf can load a module.  See docs/history/plans/tty-kernel-bank.md and
; docs/history/plans/2026-08-22-tty-bsd-shape-placement-survey.md.
;
; IT COSTS NO NEW HANDLE EITHER, only a bigger one: KERNEL_BANKS went $02 -> $03
; above, so LoaderAllocKernelBank's single claim now covers base, base+1 and
; base+2, and the arithmetic that finds them is unchanged.
;
;     tty bank == live kernel bank + 2
;
; NAMED FOR ITS TENANT, not for its ordinal.  "far" said only "somewhere else",
; which was right when the payload was four unrelated subsystems; this bank is
; the tty layer's home and every increment of apple/fgx#108 lands in it.  If
; something unrelated ever moves here the name should follow the majority, but a
; bank called "third" would tell a reader nothing on the day they need it.
;
; FGX_KTTY_BANK is an ASSEMBLY-TIME convention only, exactly as FGX_KFAR_BANK is;
; at runtime the bank always comes from PHK.
FGX_KTTY_BANK   EQU     $09             ; assembly-time ORG bank (runtime: PHK)
FGX_KTTY_CODE   EQU     $090000         ; tty-bank code start
; RAISED $09EC40 -> $09FC00 -> $09FF00, both on 2026-08-24 (apple/fgx#108 T3).
; NOW 65,280 bytes of code and 256 of statics.
;
; The ORIGINAL split reserved 5,056 bytes for a DUM region that is EMPTY --
; ttybank.s's block holds only its own start marker, and every tty-bank static
; is an fcc data segment INSIDE the code region (2,336 bytes of them, `cfree'
; at 1,024 the largest).  So the reserve was costing the code region four
; kilobytes to hold nothing.  The first raise left 1,024 back; landing
; `ttyinput' (198 lines) with its probe cases went 518 over even so, which is
; what took the reserve down to 256.  It is still EMPTY -- this is not the
; reserve being consumed, it is the reserve being sized to what it holds.
;
; SAFE BECAUSE THE WHOLE BANK IS ALLOCATED, not just the image: stage2 loads
; this image into a bank-aligned, locked multi-bank block (base + 2), so the
; bytes above the image are real RAM either way -- the ceiling only says how
; much of the bank the LINKER may fill.
;
; NOT VERIFIED BY THE CHECKER AGREEING WITH ITSELF.  check_kernel_ceiling
; derives its limit FROM this constant, so it cannot say whether the region is
; actually LOADED; both raises were verified by pushing filler so real code sat
; past the old line and BOOTING, with `tty: clists ok' and `tty: linesw ok'
; asserted PRESENT rather than merely without a failure line.
FGX_KTTY_DATA   EQU     $09FF00         ; tty-bank statics start (= code ceiling)

; System bank layout ($00xxxx)
FGX_DP_KERNEL   EQU     $0000           ; Kernel direct page for the legacy
                                        ; static $02 build only.  The relocated
                                        ; kernel's FGX_Entry sets D to
                                        ; FGX_DP_KKERN (main.s).
FGX_STK_KERNEL  EQU     $0100           ; Kernel stack (256 bytes)
FGX_SYSVARS     EQU     $0200           ; System variables (unused live; was
                                        ; reclaimed by Fix #2 but restored on
                                        ; revert)
FGX_INTVEC      EQU     $0300           ; Interrupt vectors
FGX_BOOTAREA    EQU     $0800           ; Boot block load area
; THE INTERRUPT-TIME KERNEL-C STACK'S SIZE.  512 bytes: it runs ttyinput ->
; ttyecho -> ttyoutput -> putc at a task's syscall depth, and the deepest
; measured chain of that shape was 437 bytes.  An IRQ pushes its frame onto the
; INTERRUPTED stack before anything switches, so every kernel stack also
; carries that frame at whatever depth the interrupt found it.  genconfig.py
; mirrors this number to place the context above the slot stacks.
FGX_KSTK_SIZE   EQU     512

; THE KERNEL-IMAGE SLOTS.  A task's kernel image -- its kernel direct page and
; its kernel stack -- lives in one of FGX_KSLOT_COUNT slots while the task is
; inside the kernel: slot s has the page FGX_KSLOT_DP + s*256, in the mapped
; $D000 bank, and FGX_KSLOT_STK bytes of stack at FGX_STK_KTASKS +
; s*FGX_KSLOT_STK, in the flat 8 KB above $E000.  The scheduler binds a slot
; when it picks the task (task.s, _Slot_Ensure) and publishes the page and the
; stack top for the dispatcher; a task keeps its slot while it sleeps, and is
; parked -- page and live stack copied to its home image, FGX_KHOME_STRIDE
; bytes per pid in one bank -- only when another task needs the slot.  Neither
; block scales with NPROC.  All four are DERIVED (genconfig.py) and checked
; (check_bank0_geometry.py).
FGX_KSLOT_COUNT EQU     CFG_KERNEL_KSLOTS
FGX_KSLOT_STK   EQU     CFG_KERNEL_KSTK
FGX_KSLOT_DP    EQU     CFG_KSLOT_DP
FGX_KHOME_STRIDE EQU    CFG_KHOME_STRIDE
FGX_KSLOT_NONE  EQU     $FF             ; _kSlotOf: no slot, rebasable

; The slot BOOT BORROWS, the top one: main.s seeds S to its top, so boot runs
; on the stack whose BASE is this until the first task exists.  Nothing is
; bound at boot, which is why the borrow is legal; boot's marks survive until
; the scheduler hands that slot to a task.
;
; NAMED because apple/fgx#195 was argued in raw arithmetic and got the answer
; wrong.  A measurement that has to re-derive the address from three constants
; is a measurement that will be re-derived wrongly.
FGX_STK_BOOT    EQU     CFG_STK_BOOT

FGX_STK_KTASKS  EQU     CFG_STK_KTASKS  ; The kernel-image slot stacks: $E000,
                                        ; in the flat 8 KB of language card
                                        ; that _LC_MapRam keeps mapped for the
                                        ; life of the system, FGX_KSLOT_COUNT
                                        ; of FGX_KSLOT_STK bytes, painted and
                                        ; bottom-word canaried at boot (main.s)
                                        ; and reused by task after task; the
                                        ; dispatcher checks the running task's
                                        ; canary at every syscall entry.  A
                                        ; FIXED region, never a NewHandle'd
                                        ; page: a NewHandle'd bank-0 page
                                        ; crashes the syscall handler
                                        ; (3a/3b/3c-1/#3, feedback_cold_boot_
                                        ; smoke_after_dispatcher_change).
; Bounded per-task USER-STACK arena.  posix_spawn'd children's user stacks
; (1..TASK_STACK_MAX_PAGES pages) are carved here by a page-bitmap allocator
; (task.s Task_AllocStack/Task_FreeStack) instead of MM NewHandle, so they
; live inside the canonical TN#27 $00/0800 claim (the MM has no free bank-0
; page once that claim lands).  It runs up to the kernel-C direct page, the
; last page below the I/O space.  A task's user direct page is the first page
; of its reservation, so the arena holds those too.
;
; init does NOT keep a static page: it calls Task_AllocStack like every other
; task, sizing from its executable header's hint.
FGX_STK_ARENA        EQU CFG_STK_ARENA   ; arena base (bank-0 offset), emitted
                                         ; by tools/ninja/genconfig.py, directly
                                         ; above BLK_STAGE.  NPROC does not move
                                         ; it, and neither base moves at all
                                         ; (docs/bank0-blkstage-relocation.md).
                                         ; Only the first 512 B of the BLK_STAGE
                                         ; region is the staging buffer; its MM
                                         ; claim (toolbox.s, stage2.s) is larger
                                         ; and the arena uses the rest of it.
                                         ; DO NOT shrink the claim to match: that
                                         ; would hand those pages BACK to the MM.
FGX_STK_ARENA_PAGES  EQU CFG_STK_ARENA_PAGES
                                         ; DERIVED: whatever is left between the
                                         ; arena base and the kernel-C direct
                                         ; page.  NPROC does not touch it: no
                                         ; per-pid block lives in bank 0.

; --- OVERLAPPING RESERVATIONS (docs/history/plans/2026-09-17-bank0-residency-
; architecture.md, section 5.2) -----------------------------------------------
; Bank 0 is a CACHE of user images.  A task's reservation is RESIDENT while its
; bytes are at their own addresses and PARKED while they sit in a home image in
; the swap pool (task.s, Uimg_*); the running task is always resident.  When
; the arena has no free run for a new reservation, the allocator may place it
; OVER the reservations of tasks that are not running and can be parked: they
; are parked then and there, live extent only, and come back to the same
; addresses when the scheduler next picks them.  Nothing ever moves to a
; different address -- fcc frames hold absolute bank-0 pointers -- so a parked
; task cannot tell it was away.
;
; TASK_STK_OVER_MIN is the knob: a request (pages, before the guard) of at least
; this many may overlap; 0 = never, so a full arena is a spawn-time ENOMEM as
; it always was; 1 = any request.  It is kernel.stkover in cfg/system.cfg,
; where the default and its reasons are.  Task_AllocStack compares the GUARDED
; count, so the test there is against TASK_STK_OVER_MIN+1.
TASK_STK_OVER_MIN EQU   CFG_KERNEL_STKOVER

; HYSTERESIS.  Minimum ticks a RUNNABLE resident keeps its bytes before a task
; that overlaps it may park it at pick time.  A BLOCKED resident is parked
; freely -- it cannot use its bytes until it wakes -- so this governs only the
; contended runnable case, two CPU-bound tasks sharing a range.
;
; Ticks (60 Hz), not context switches: the cost being amortised is wall-clock
; copying, and the switch rate is not something the eligibility predicate
; should have to model.  It is ALSO the anti-starvation bound -- a waiting task
; is delayed by at most this long, after which the resident is parkable
; whatever it is doing.  12 was chosen by measurement on two spinning tasks
; sharing one range: it cuts the hand-overs to a quarter of no dwell, and
; 200 ms is under the threshold where input lag is noticed.
TASK_STK_HOLD_TICKS EQU 12

; THE USER DIRECT PAGE RIDES WITH THE STACK.  A task's direct page is the
; first page of its stack reservation, immediately below TCB_StackBase
; (Task_AllocStack carves the page with the stack and Task_FreeStack frees it
; with the stack), so it parks and returns with the stack when the task's
; range is taken over (task.s, Uimg_*), and adding a process costs no fixed
; bank-0 page.  TCB_DirectPage names it; the dispatcher reaches the running
; task's page through _Sys_UserDP, which swtch loads from the TCB.  A fork
; child borrows its parent's page along with the parent's stack.
;
; There is no per-pid block any more: the pages that held one at the top of
; the arena went back to the arena, and the kernel-C direct page below is the
; last page under the I/O space.
;
; The loader hands the kernel off on FGX_DP_KKERN, the kernel's own page,
; which boot zeroes again before it becomes the template (main.s).

; THE KERNEL-C DIRECT PAGE -- the one page below the I/O space, charged to the
; arena, which ends where it starts.  It is what fcc-compiled kernel
; code runs on, and it has to be a page of its own for a reason that is not
; about space: fcc's register file wants $98-$FF laid out the way a TASK direct
; page is laid out (toolchain/lib/fcc_runtime.s), and $C0-$EF of the KERNEL's
; own direct page is the console's persistent state (include/dpmap.s).  The two
; maps cannot both be true of one page, so kernel C gets its own and the entry
; macro TCDs to it.
;
; It is deliberately NOT per-pid.  A per-pid file would cost NPROC+1 pages and
; only buys something once kernel C can sleep -- 2.11BSD's own rule is that code
; running at raised spl never enters anything that can block, and FGX's FS layer
; today contains no sleep at all.  If kernel C ever crosses _sleep, the register
; file joins what the context switch saves; it does not become a page per task.
; THE KERNEL'S OWN DIRECT PAGE, AND THE TEMPLATE FOR EVERY TASK'S.
;
; NOT a task's user page, and the difference is the whole point.  The page a
; task runs on in USER mode is the first page of its stack reservation.  The
; page the KERNEL runs on while serving a task is the task's SLOT page (FGX_KSLOT_DP,
; above): a copy of this one, made when the scheduler binds the slot, with the
; task's identity stamped in.  A single shared kernel page is what made a
; scratch cell held across a sleep a cross-task hazard (apple/fgx#41,
; apple/fgx#100: one task's staged value read back after another task had
; run); per-task pages retire that class structurally, and a task's page rides
; with its stack when the task is parked, so what it held comes back with it.
;
; This page is boot's own, and the template: its heap base pointers ($20-$4F)
; and table pointers ($F0-$FF) are established once at boot and are identical
; in every copy, which is why a slot page is copied rather than zeroed.
;
; Two things had to move out of the direct page before per-task pages were
; possible, and neither was optional:
;   - the console's cursor/viewport/colour scalars, which are PER-VC and are
;     now CON_VT_STATE $4A..$59 (apple/fgx!159);
;   - the identity of the running task, which is the absolute _kCurPid --
;     the dispatcher needs the pid BEFORE the TCD that selects the page, so it
;     cannot come from the page being selected.  The running task's page
;     itself is the absolute _kCurKDP (task.s), published by the scheduler.
;
; _curTask STAYS a direct-page cell and is a PER-PAGE IDENTITY: a slot page's
; copy holds the pid of the task bound to it, stamped when the slot is seeded
; and never written again; this page's reads 0.  That is what keeps ~170
; "which task am I" reads correct with no edit at all, including the ones in
; modules, where the direct page is the only addressing mode that is free.
FGX_DP_KKERN    EQU     CFG_DP_KKERN    ; DERIVED: $0900, one page, ceiling
                                        ; BLK_STAGE.

FGX_DP_KERNELC  EQU     CFG_DP_KERNELC  ; DERIVED: the page below $C000.

; THE INTERRUPT-TIME KERNEL-C CONTEXT -- apple/fgx#108 T6.
;
; The paragraph above says FGX_DP_KERNELC is "deliberately NOT per-pid", and it
; still is.  This is not a per-pid page either: it is the SECOND page, the one
; a C context entered from an INTERRUPT runs on, so that it and the syscall it
; interrupted do not share fcc's $98..$FF.  include/kernelc.s states the rule
; the pair exists to lift -- "Two C contexts live at once would share it and
; corrupt each other" -- and KTTY_KC_ENTER_IRQ there is what selects this page.
;
; THE STACK IS HALF OF IT, and naming only the register file is how this gets
; under-scoped.  fcc puts frames on the hardware stack, and the heartbeat runs
; on whatever it interrupted: a task's kernel stack, which has measured
; $01BE high-water with 190 bytes spare.  So the context gets a stack of its
; own, FGX_KSTK_SIZE like a task's because it runs the same depth of code.
;
; AND THAT IS THE FIRST WORKING fcc STACK GUARD IN THIS KERNEL.  `_fcc_stkfloor'
; ($B9) is read by every guarded prologue, and `_KcDp_Zero' leaves it ZERO on
; FGX_DP_KERNELC -- a floor of zero passes every test, which is why the guard is
; inert everywhere kernel C runs today (measured, docs/history/plans/tty-kernel-bank.md,
; "Stage 4a").  This page's floor is SEEDED, so an interrupt-time overflow
; reports instead of corrupting.
;
; Both are DERIVED, immediately above the kernel-image slot stacks in the
; language card: the two together are FGX_KSTK_SIZE + 256 bytes off the top of
; that region, which is what bounds the slot count, not NPROC.
FGX_DP_KERNELC_IRQ EQU  CFG_DP_KERNELC_IRQ  ; DERIVED: just above the slot
                                        ; stacks.  See genconfig.py.
FGX_STK_KIRQ    EQU     CFG_STK_KIRQ    ; DERIVED: FGX_DP_KERNELC_IRQ + 256.
FGX_STK_KIRQ_TOP EQU    CFG_STK_KIRQ+FGX_KSTK_SIZE-1

; THE SCHEDULER'S OWN STACK.  swtch moves S here at @sw_pick and stands on it
; through pick_next, Uimg_Ensure, _KcDp_Rest and the idle arm, until the resume
; TCS puts S on the chosen task's saved kernel SP.  So nothing the scheduler
; does -- picking, parking a lane member, idling in WAI, entering kernel C to
; drain tty output -- pushes on the stack of the task that just gave up the
; CPU: a task's kernel stack is written only by that task and by the
; interrupts it takes.
;
; It is the TOP OF THE MAPPED $D000 BANK -- bank 1, which _LC_MapRam selects
; and every ROM-in/RAM-in bracket in the tree restores -- rather than part of
; the flat 8 KB, which the per-pid stacks and the interrupt-time context are
; sized against.  Painted and canaried at boot (main.s) like a per-pid slice,
; so tools/mame_test/kstkhwm_check.py measures its depth, and the canary is
; tested at every @sw_pick.  DERIVED; genconfig.py mirrors the size.
FGX_STK_SWITCH_SIZE EQU 512
FGX_STK_SWITCH  EQU     CFG_STK_SWITCH  ; DERIVED: LC_BANK_TOP - SWITCH_SIZE
FGX_STK_SWITCH_TOP EQU  CFG_STK_SWITCH+FGX_STK_SWITCH_SIZE-1

; P3-3 3.2b: the fcc prologue overflow guard reads a per-task hardware-stack
; floor from a fixed byte in the task's DP page; posix_spawn seeds it after
; Task_AllocStack (process.s).  These MUST match the fcc runtime:
;   FCC_STKFLOOR_DP    == _fcc_stkfloor   in toolchain/lib/fcc_runtime.s ($B9)
;   FCC_STK_FLOOR_MARGIN tracks the linker's stack_measure DEFAULT_PAD (the
;   non-C headroom reserved below the C-frame floor for libc/syscall/IRQ
;   pushes) — keep the two numbers equal.  CALIBRATED 2026-07-08 (task #42):
;   worst measured non-C excursion 26 B; 128 kept as ~5x margin — see
;   docs/history/audits/2026-07-08-p33-42-pad-calibration.md.
FCC_STKFLOOR_DP      EQU $B9              ; DP byte offset of _fcc_stkfloor

; KERNEL TRAP REPORT CELLS (apple/fgx#261) -- fixed bank-0 addresses, written by
; the fcc stack-overflow traps in src/kernel/far/fcc_ktrap.s before they spin.
;
; EQUs HERE rather than only in memmap.s because fcc_ktrap.s is PUT by every
; kernel-C MODULE as well as by the far bank (vfs, ufs, ufsdir, ufsprobe,
; hellokc), and a module includes kernel.s but not memmap.s -- the DUM labels
; are simply not in scope there, which is a build failure and was.
;
; memmap.s RESERVES the same eight bytes and asserts these addresses with an
; ERR, so the two cannot drift apart silently.
;
; NOT $030C AND NOT $030E, BOTH TAKEN, AND NEITHER WAS DECLARED.  The
; apple/fgx#242 language-card instrumentation writes $C0DE to $030C as a
; positive control and parks STATEREG at $030E, both through LITERALS -- so the
; DUM in memmap.s could not see either, and two successive attempts to place
; these cells landed on them.  The first read a magic of $C0DE (the sampler's
; marker); the second read $C500, a byte of $00 laid over the low half every
; heartbeat tick by the STATEREG park.
;
; GREPPING THE SOURCES DID NOT FIND THEM AND THE BUILT LISTING DID.  The
; authoritative survey is `STAL/LDAL $0003xx' over the three kernel listings,
; which reports $030A, $030C, $030E, $032C and $03F4.  All three are declared in
; memmap.s now, so the next claim in this window collides at BUILD time instead
; of being debugged from a wrong value.
KFGX_TRAP_MAGIC EQU     $000310         ; 0 = no trap fired this boot
KFGX_TRAP_D     EQU     $000312         ; D at the trap
KFGX_TRAP_S     EQU     $000314         ; S at the trap
KFGX_TRAP_FLOOR EQU     $000316         ; _fcc_stkfloor through the caller's DP

; THE RUNNING TASK'S KERNEL SLOT PAGE, IN BANK 0 SO A MODULE CAN READ IT.
;
; The scheduler publishes the page it binds to a slot here (task.s), and boot
; seeds it with the template page before any task exists (main.s).  It is the
; only authority for which kernel direct page is live: `_curTask' is a PER-PAGE
; identity, so every kernel routine that reads it -- `_Slp_Block', `_Uarea_Cur',
; `_Sig_Raise' -- answers for whatever page D happens to name, not for the task
; that is running.
;
; BANK 0 AND NOT THE KERNEL BANK, because a module's ENTERK is one of the
; readers and a module cannot name a kernel-bank address: the VFS family has no
; generated kernel_exports.s at all, and `LDAL' would bake a bank at assembly
; time -- ufsdir.s calls that the trap that has cost this tree two sessions.
; Bank 0 is the one bank a module can name as a constant, which is why the
; module gateway ($032E) lives here too.
KFGX_CUR_KDP    EQU     $000318         ; running task's kernel slot page

; THE FLOATING POINT SIMULATOR'S ENTRY, FGX's counterpart of 2.11BSD's
; mch_fpsim.s (docs/history/plans/2026-09-24-fpsim-module-plan.md).  A 4-byte
; JML: user code and libc.so reach the soft double with `JSL FPSIM_TRAMP',
; which needs no relocation for the same reason `JSL SYS_TRAMP' does.  The far
; bank points it at _Fpsim_Absent at boot (SIGILL, as 2.11BSD's trap.c does
; with no FPU and no FPSIM); the fpsim module's mod_init points it at the
; module.  Bank 0 because a module can name it as a constant.
FPSIM_TRAMP     EQU     $000324         ; JML to the soft double's dispatcher
; THE SHARED-LIBRARY REGISTRY'S ENTRY (shared libc SP4): a 4-byte JML into
; ld.mod's dispatcher.  The tty bank plants a JML to _Ld_Absent at boot
; (Tty_BankInit); ld.mod's mod_init re-points it.  JSL LD_TRAMP with A = a
; selector: 0-4 SYS_LDCTL's services (reached only through the syscall,
; which refuses the rest), $80-$84 the kernel's hooks.  Bank 0 because a
; module can name it as a constant.
LD_TRAMP        EQU     $00031A         ; JML to ld.mod's dispatcher
LDS_ACQUIRE     EQU     0               ; services: X/Y = block offset/bank
LDS_GRANT       EQU     1
LDS_COMMIT      EQU     2
LDS_ABORT       EQU     3
LDS_LOOKUP      EQU     4
LDS_COUNT       EQU     5
LDH_EXIT        EQU     $80             ; hooks: Y = the dying pid
LDH_FORK        EQU     $81             ;   Y = the child's pid (parent runs)
LDH_EXEC        EQU     $82             ;   Y = the pid whose image went
LDH_TALLOC      EQU     $83             ;   Y = the pid a slot was given to
LDH_RECLAIM     EQU     $84             ;   -> C=1 a bank went back
WCHAN_LD        EQU     $FF0A           ; ld.mod: a registry row changed state
; The JSL syscall entry (_Sys_InstallVectors plants it).  Here so a module can
; name it too: the fpsim module's stack-overflow exit makes a syscall.
SYS_TRAMP       EQU     $000328         ; JML _Sys_JslEntry
FCC_STK_FLOOR_MARGIN EQU 128              ; bytes reserved below the C floor
FCC_SFP_DP           EQU $BD              ; DP byte offset of _fcc_sfp (offset
                                          ; @ +0..+1, BANK @ +2).  Keep in sync
                                          ; with toolchain/lib/fcc_runtime.s;
                                          ; the loader seeds all three bytes at
                                          ; spawn when the binary asks for a
                                          ; soft-frame bank (header byte 15).

;==============================================================================
; TASK CONTROL BLOCK (TCB)
;==============================================================================

; TCB field offsets — computed via DUM/DEND so adding/reordering fields
; updates all downstream offsets automatically.  Total size ERR-guarded
; at the end.

                DUM     0
TCB_TaskID      DS      2               ; Unique task identifier
TCB_Status      DS      2               ; Task status (see TASK_* constants)
TCB_Priority    DS      1               ; Current priority (0-7)
TCB_BasePriority DS     1               ; Base priority (for aging reset)
TCB_Flags       DS      2               ; Task flags (see TFLAG_*)

TCB_StackBank   DS      2               ; Bank containing task stack
TCB_StackPtr    DS      2               ; Saved stack pointer
TCB_StackBase   DS      2               ; Stack base address
TCB_StackSize   DS      2               ; Stack size in bytes

TCB_DirectPage  DS      2               ; Task's direct page address
TCB_DataBank    DS      1               ; Task's data bank register
TCB_Reserved1   DS      1               ; alignment; always 0

TCB_CodeBank    DS      2               ; Code bank (entry point bank)
TCB_EntryPoint  DS      2               ; Entry point offset

TCB_ParentID    DS      2               ; Parent task ID
TCB_ExitCode    DS      2               ; Exit status (when ZOMBIE)

TCB_WakeTime    DS      4               ; Tick count for timed wakeup
TCB_WaitingOn   DS      2               ; Resource/task being waited for
TCB_WaitType    DS      2               ; Type of wait (v3-only; aliased TCB_SavedPB in v1)

TCB_MsgQHead    DS      2               ; Message queue head index
TCB_MsgQTail    DS      2               ; Message queue tail index
TCB_MsgQCount   DS      2               ; Number of pending messages

TCB_LastRun     DS      4               ; Tick count when last run (for aging)
TCB_CPUTime     DS      4               ; Total CPU time used (ticks)

TCB_NextReady   DS      2               ; Next task in ready queue
TCB_PrevReady   DS      2               ; Previous task in ready queue

; Multi-bank loader (Phase 2 slice 2.1): list of user-pool banks owned
; by this task.  Slot N = bank byte for segment N (0 = unused).  Filled
; at posix_spawn / kernel init time; walked by _Sys_Exit to Bank_Free.
; Replaces the v3-scheduler scratch fields (SavedA/X/Y/P/DBR) which were
; only referenced by orphaned sched.s scaffold.  When v3 multitasking
; lands it'll use a bank-\$02 scratch struct anyway (see sched.s top
; comment about gno-kern's int_A/X/Y/S pattern).
TCB_BankList    DS      8               ; segments 0..7 banks; 0 = unused

TCB_SavedS      DS      2               ; Stack pointer (duplicate for safety)

TCB_SIZE        EQU     *               ; Total TCB size (computed)
                DEND

                ERR     TCB_SIZE-1/$40  ; assembly error if TCB > 64 bytes

;==============================================================================
; v1 PROCESS-MODEL ALIASES
;
; Slice 2 (program execution v1) needs a few fields the v3-scheduler-shaped
; TCB doesn't yet have: a saved 16-bit PC for context restore, a saved PB,
; and a pending-signals mask.  Rather than grow TCB_SIZE past 64 bytes
; (which would break Task_Alloc/Lookup's `ASL x6` index math), v1 aliases
; these onto v3-only fields that aren't in use yet.
;
; If v3's scheduler ever needs the wait/msgq/ready-queue fields back at the
; same time as v1's process model, the TCB shape gets revisited then.
;==============================================================================

TCB_SavedPC     EQU     TCB_WaitingOn   ; v1: 16-bit PC to resume at on RestoreCtx
TCB_SavedPB     EQU     TCB_WaitType    ; v1: PB to resume at (low byte)
TCB_PendingSig  EQU     TCB_MsgQHead    ; v1: 4-byte pending-signal bitmask
                                        ;     (uses MsgQHead+MsgQTail = 4 bytes)
TCB_SigIgnore   EQU     TCB_MsgQCount   ; v1: 2-byte SIG_IGN mask (16 sigs).
                                        ;     Bit set = SIG_IGN; clear = SIG_DFL.
                                        ;     SYS_SIGNAL records disposition;
                                        ;     real delivery is slice-3+.
TCB_StackHandle EQU     TCB_NextReady   ; vi-port slice 2: 4-byte MM handle to
                                        ;     this task's bank-0 user stack
                                        ;     pages.  $0000.0000 means "static
                                        ;     allocation" (e.g. PID 1 init at
                                        ;     $3100), skip DisposeHandle on
                                        ;     Task_Free.  Overlays
                                        ;     TCB_NextReady+TCB_PrevReady = 4
                                        ;     bytes (v3 ready-queue, unused
                                        ;     in v1 since the cooperative
                                        ;     scheduler is queue #4 on the
                                        ;     roadmap and not yet wired).
TCB_FdTablePtr  EQU     TCB_CPUTime     ; Slice-3 B.2: 3-byte long ptr to this
                                        ;     task's fd table (Kmalloc'd in
                                        ;     M_FS, FS_MAX_FDS*3 bytes).  High
                                        ;     byte of the 4-byte slot is unused
                                        ;     padding.  Set by Task_Alloc;
                                        ;     copied parent→child by
                                        ;     _Sys_PosixSpawn; Kfree'd by
                                        ;     Task_Free.  Overlays
                                        ;     TCB_CPUTime (v3 accounting,
                                        ;     unused in v1).

;------------------------------------------------------------------------------
; v1 alias for TCB_Status — spec §3.5 calls it TASK_RUNNABLE/BLOCKED/ZOMBIE.
; The pre-v1 field used TASK_READY/RUNNING/BLOCKED/ZOMBIE.  Map onto same
; bytes; TASK_RUNNABLE = TASK_READY semantically.
;------------------------------------------------------------------------------
TASK_RUNNABLE   EQU     TASK_READY      ; v1 spec name; same value as TASK_READY

;==============================================================================
; TASK STATUS VALUES
;==============================================================================

TASK_UNUSED     EQU     $0000           ; TCB slot is free
TASK_READY      EQU     $0001           ; Task is runnable
TASK_RUNNING    EQU     $0002           ; Task is currently executing
TASK_BLOCKED    EQU     $0003           ; Task is waiting for something
TASK_ZOMBIE     EQU     $0004           ; Task has exited, awaiting collection
TASK_STOPPED    EQU     $0005           ; Job-control stop (^Z/SIGTSTP); skipped by
                                        ; swtch until SIGCONT makes it READY again

;==============================================================================
; TASK FLAGS
;==============================================================================

TFLAG_KERNEL    EQU     %00000001       ; Kernel task (elevated privileges)
TFLAG_SYSTEM    EQU     %00000010       ; System server task
TFLAG_DRIVER    EQU     %00000100       ; Device driver task
TFLAG_EXITING   EQU     %00010000       ; Task is in process of exiting
TFLAG_SIGNALS   EQU     %00100000       ; Signals pending

;==============================================================================
; WAIT CHANNELS (_sleep/_wakeup chan values).  Most channels are an object's
; address (e.g. a parent's TCB byte-offset for waitpid, a socket slot for recv);
; these fixed channels name kernel-global wait sources.  They live in a high
; range that can't collide with a TCB byte-offset ([$0800..$0BFF]).
;==============================================================================
WCHAN_KBD       EQU     $FF01           ; console keyboard ring (Con_GetKey blocks)
WCHAN_SOCK      EQU     $FF02           ; any W5100 socket (recv/connect/send block)
WCHAN_TIMER     EQU     $FF03           ; nanosleep deadline (SE_WakeTime; woken by
                                        ; _Timer_WakeExpired when _kSystemTicks passes)
WCHAN_PIPE      EQU     $FF04           ; any pipe (read/write blocks); coarse
                                        ; wake-all-recheck, mirrors WCHAN_SOCK
WCHAN_SELECT    EQU     $FF05           ; select(2) blocking on ANY of its fds;
                                        ; woken by the kbd/sock/idle wake sites
                                        ; (gated on _nSelSleepers) -> re-scan
WCHAN_VFORK     EQU     $FF06           ; fork train: parent of a vfork/snapshot-fork
                                        ; child; woken by the child's execve/_exit
                                        ; hand-back.  TCB_WaitingOn = child pid, so
                                        ; the wake-all-recheck stays per-pair.
; NOTHING EVER WAKES THIS CHANNEL, and that is the design.  sigsuspend's only
; exit is a signal, and a signal already wakes every blocked task so an
; interruptible _sleep can re-check and report C=1.  A wchan nobody signals is
; therefore exactly right: it parks the task where only _sleep's own
; actionable-signal test can end the wait.  2.11BSD sleeps on &u for the same
; reason -- an address no wakeup() names.
; WCHAN_LBOLT is BSD's `lbolt' -- h/kernel.h:32, "awoken once a second" -- and
; it is the channel a caller sleeps on to mean WAIT A BIT AND TRY AGAIN.
; 2.11BSD's ttwrite uses it three times: after signalling a background writer,
; and twice when the clist pool is empty and output has to be kicked and
; retried.  ufs_alloc.c:118 sleeps on it too, for the same "no space, come
; back" reason.
;
; UPSTREAM WAKES IT FROM THE CLOCK, NOT FROM THE SCHEDULER, and that is the
; property to preserve rather than the spelling.  `wakeup((caddr_t)&lbolt)' is
; the FIRST line of schedcpu (kern_synch.c:36), which init_main.c:203 starts
; once and which re-arms itself with `timeout(schedcpu, 0, hz)' on its last
; line -- so it fires whether or not anything is runnable and whether or not
; anyone makes a syscall.  See _Lbolt_Wake in sched.s for how FGX drives it.
; $FF09 AND NOT $FF07, WHICH IS WHAT IT WAS UNTIL apple/fgx#238.  WCHAN_PTY
; four lines down had held $FF07 since the pty plan of 2026-07-20 and this
; constant, arriving with the tty campaign, took it again -- so every lbolt tick
; woke every pty waiter and every pty wake released every lbolt sleeper.  Both
; sides survived it because both re-test and loop, which is exactly why nothing
; noticed.  What it would have cost is a T4 increment 4 witness: `ptsstart's one
; job is to wake the master, and with the channels merged a `ptsstart' that
; never fired would still look like it worked, the master being woken by the
; timer a fraction of a second later.  tools/check_wchans.py now refuses a
; repeat.
WCHAN_LBOLT     EQU     $FF09           ; "wait a bit and retry"; woken once a
                                        ; second, see _Lbolt_Wake (sched.s)
WCHAN_PAUSE     EQU     $FF08           ; sigsuspend/sigpause: wait for a signal
                                        ; and nothing else (apple/fgx#59)
WCHAN_PTY       EQU     $FF07           ; a pty MASTER waiting on its pair (read
                                        ; on nothing pending, write on a full
                                        ; slave); coarse wake-all-recheck,
                                        ; mirrors WCHAN_PIPE.  It named the two
                                        ; byte RINGS until they retired -- the
                                        ; out half at T4 increment 7, the in
                                        ; half at T6 increment 4a -- and the
                                        ; slave side sleeps on its own clist
                                        ; addresses now, as upstream does
                                        ; (pty subsystem plan 2026-07-20).  $FF07:
                                        ; $FF06 went to WCHAN_VFORK in the fork train.

;==============================================================================
; PIPE DESCRIPTORS (src/kernel/pipe.s) — _pipeTablePtr[NPIPE], PIPE_REC_SZ each,
; accessed [_pipeTablePtr],Y with Y = idx<<4.  Two FCBs per pipe (read/write end)
; share PIPE_PipeIdx; the ring is Kmalloc'd per live pipe and Kfree'd at teardown.
;==============================================================================
NPIPE           EQU     8               ; concurrent pipes
PIPE_BUFSZ      EQU     512             ; INITIAL ring bytes per live pipe (POSIX
                                        ; PIPE_BUF); fork train Stage P grows the
                                        ; Kmalloc'd ring on demand up to the max
PIPE_MAX_BUFSZ  EQU     4096            ; grow-on-full ceiling (Stage P); a writer
                                        ; only blocks once the ring is at max
PIPE_REC_SZ     EQU     16              ; descriptor size (idx<<4 for a clean ASL x4)
PIPE_InUse      EQU     0               ; 1 B: 1 = allocated
PIPE_RdClosed   EQU     1               ; 1 B: read-end FCB gone (all readers closed)
PIPE_WrClosed   EQU     2               ; 1 B: write-end FCB gone (all writers closed)
PIPE_BufPtr     EQU     3               ; 3 B: long ptr to the ring (0 until alloc)
PIPE_Head       EQU     6               ; 2 B: read cursor 0..PIPE_BUFSZ-1
PIPE_Tail       EQU     8               ; 2 B: write cursor 0..PIPE_BUFSZ-1
PIPE_Count      EQU     10              ; 2 B: bytes resident 0..PIPE_BufSz
PIPE_BufSz      EQU     12              ; 2 B: CURRENT ring size (Stage P; init
                                        ; PIPE_BUFSZ, doubles to PIPE_MAX_BUFSZ).
                                        ; Bytes 14-15 of the record stay free.

;==============================================================================
; PRIORITY LEVELS
;==============================================================================

PRIO_REALTIME   EQU     0               ; Highest: interrupt handlers, audio
PRIO_SYSTEM     EQU     1               ; Kernel threads, critical services
PRIO_HIGH       EQU     2               ; Interactive UI, input
PRIO_ABOVE      EQU     3               ; Important user tasks
PRIO_NORMAL     EQU     4               ; Default for user tasks
PRIO_BELOW      EQU     5               ; Background processing
PRIO_LOW        EQU     6               ; Batch jobs, maintenance
PRIO_IDLE       EQU     7               ; Lowest: only when nothing else runs

PRIO_COUNT      EQU     8               ; Number of priority levels
PRIO_DEFAULT    EQU     PRIO_NORMAL     ; Default priority for new tasks

;==============================================================================
; SCHEDULER-STATE TABLE (cooperative multitasking)
;
; Per-task scheduler bookkeeping that does NOT fit the full 64-byte TCB (whose
; spare fields are already EQU-overlaid).  One entry per task slot (indexed
; pid-1, parallel to FGX_TASK_TBL), held in a Kmalloc'd M_KERN block reached
; via the _schedTblPtr DP long-ptr — never a hand-picked static address (see
; project_fgx_kernel_size_layout_heisenbug).  Allocated by _AllocSchedTbl at
; boot; sized TASK_MAX_SLOTS * ST_SIZE.
;==============================================================================

; (SE_ prefix, not ST_ — ST_ is the stat struct in fs.s.)
                DUM     0
SE_KernSP       DS      2               ; saved kernel SP when not running (swtch resume)
SE_KernStkHandle DS     4               ; MM handle to the task's kernel-stack page(s)
SE_KernStkBase  DS      2               ; kernel-stack page base (bank-0 offset)
SE_UareaPtr     DS      4               ; long ptr to this task's u-area (swtch swaps _u)
SE_WaitChan     DS      2               ; sleep channel (0 = not blocked on one)
SE_PGroup       DS      2               ; process-group id (job control)
SE_Flags        DS      2               ; SEF_* flags
SE_UserSP       DS      2               ; saved dispatcher carryover: was _Sys_UserSP
SE_UserDP       DS      2               ;   "                          was _Sys_UserDP
SE_CallerBank   DS      2               ;   "                          was _Sys_CallerBank
                                        ; (swtch save/restores these ↔ the globals so
                                        ;  a task's user-resume carryover survives a
                                        ;  mid-syscall block; cheaper than the _u-area
                                        ;  dispatcher refactor and leaves the hot path
                                        ;  untouched — u-area stays for recv scratch.)
SE_WakeTime     DS      4               ; nanosleep absolute deadline (32-bit _kSystemTicks
                                        ; value); valid only while SE_WaitChan==WCHAN_TIMER.
                                        ; _Timer_WakeExpired wakes the task once now>=this.
SE_SnapPtr      DS      3               ; long ptr to this task's BANK HOME: the
                                        ; descriptor listing a spare for each mutable
                                        ; bank of its image group, where its bytes go
                                        ; while another member is resident (process.s,
                                        ; _Img_BankMove).  0 = none.
SE_SoftBank     DS      1               ; bank-0 stack campaign 1.3: the task's
                                        ; DEDICATED soft-frame stack bank.  0 =
                                        ; none -- the binary has no recursion-
                                        ; cycle members, or predates the campaign.
                                        ; Granted by the loader from FGX2 header
                                        ; byte 15, freed at exit and at execve.
                                        ;
                                        ; It is a WHOLE bank because the soft
                                        ; stack's problem was never size, it was
                                        ; company: sharing the task's DATA bank
                                        ; with bsh's stak arena left it seven
                                        ; sourced commands (apple/fgx#12).
                                        ;
                                        ; This slot WAS SE_SbrkBank, the private
                                        ; sbrk bank, dead since the heap moved to
                                        ; the contiguous BSD `end` layout in the
                                        ; task's own data bank -- nothing has
                                        ; granted it since, and the SE table had
                                        ; no 33rd byte to spare.  Reusing it is
                                        ; not thrift: the lifecycle is identical
                                        ; (granted once, freed at exit and exec,
                                        ; carried across a snapshot fork), so the
                                        ; teardown paths already do the right
                                        ; thing rather than needing new ones.
                DS      32-{*}          ; pad SE_SIZE to 32 (= TCB_SIZE/2) so a
                                        ; task's sched-entry offset is the cheap
                                        ; (TCB_offset - FGX_TASK_TBL_OFF) >> 1 in
                                        ; swtch/_sleep/_wakeup (one SBC + LSR, no
                                        ; multiply).  Errors if fields exceed 32.
SE_SIZE         EQU     *               ; per-slot size (= 32; computed)
                DEND

;==============================================================================
; PER-TASK CWD + PROCESS-NAME TABLES (heap, M_KERN; one slot per pid 0..NPROC)
;
; cwd is process file state (BSD: filedesc.fd_cdir): per-task, reached via the
; curproc-style long-ptr _fsCwdPtr that swtch repoints to the running task's
; slot.  Name table feeds ps.  Both Kmalloc'd at boot (heap = bank $03+), indexed
; by pid with power-of-two slot strides so the offset is a shift, no multiply.
;==============================================================================
CWD_MAX         EQU     128             ; per-task cwd buffer (slot = pid<<7)
PROC_NAME_MAX   EQU     16              ; per-task command name incl NUL (slot = pid<<4)
; (CWD_TBL_BYTES / NAME_TBL_BYTES total sizes are EQU'd after NPROC below.)

;==============================================================================
; PER-TASK HEAP DESCRIPTOR (top of the task's DATA bank)
;
; The BSD contiguous data+bss+heap model: the heap is the tail of the data
; segment, grown by sbrk(2).  Four words at the very top of the bank make it
; SELF-DESCRIBING, so the kernel can report a task's heap without keeping any
; per-task state (the TCB is full at 64 B and the sched entry is exactly 32).
; The loader seeds BASE, HWM and BRK to `end` and LIM to its own address at
; spawn; _Sys_Brk maintains BRK and HWM and refuses a break past LIM.
;
; HEAP_LIM is the heap's ceiling, and it is a CELL rather than a constant so a
; region can sit between the heap and the descriptor: a value below $FFF8
; reserves [value, $FFF8) above the heap.  Fork's snapshot and exchange carry
; [HEAP_LIM, $FFFF] with the data below the break, as 2.11BSD's fork copies
; the data segment and the stack segment at the two ends of the process
; (usr/sys/sys/kern_fork.c:271-273).
;
; HEAP_HWM exists because the break alone answers the wrong question.  A process
; that peaks during startup and frees reads as idle afterwards -- which is
; exactly how tcsh's login path reads, and exactly the current-vs-high-water
; trap the bank-0 stack campaign already paid for once (Task_StkHwm).  See
; apple/fgx#42.
; reboot(2)'s `howto', 2.11BSD usr/sys/h/reboot.h.  Only the bits with a reader
; here are listed -- a second copy of a number drifts -- and they keep upstream's
; values so a flag word means the same thing on both sides of the seam
; (toolchain/include/sys/reboot.h is the userland copy).
RB_AUTOBOOT     EQU     $0000           ; the system booting itself: sync, then
                                        ;   cold-start
RB_NOSYNC       EQU     $0004           ; don't sync before rebooting
RB_HALT         EQU     $0008           ; don't reboot, just halt

HEAP_LIM        EQU     $FFF8           ; the heap limit cell: the first byte
                                        ; the heap may not occupy.  The break
                                        ; may equal it.  The loader seeds it
                                        ; to its own address, $FFF8; a lower
                                        ; value reserves [value, $FFF8) above
                                        ; the heap, which fork carries.  A
                                        ; value above $FFF8 reads as $FFF8.
HEAP_BASE       EQU     $FFFA           ; `end` -- the heap's fixed low bound
HEAP_HWM        EQU     $FFFC           ; highest break ever reached
HEAP_BRK        EQU     $FFFE           ; the live break cursor

; procinfo record returned by SYS_PROCS (PROCINFO_SIZE bytes, fixed; the C
; view is `struct procinfo' in toolchain/include/fgx.h -- the two must move
; together, there is no version tag).
;
; The four bank-0 stack cells were added 2026-08-06 so ps(1) can show what the
; bank-0 stack campaign has only ever been able to read out of docs and the
; kernel log ring: what each task RESERVED and what it has actually TOUCHED.
; The arena pair is meaningful ONLY in the synthetic pid-0 record (a task has
; no arena of its own), which is why it is two dedicated cells rather than a
; unit switch inside PI_StkSize -- see _sp_emitKernel.
PI_Pid          EQU     0               ; 2
PI_PPid         EQU     2               ; 2
PI_PGid         EQU     4               ; 2
PI_State        EQU     6               ; 2
PI_Name         EQU     8               ; 16 (NUL-padded)
PI_StkSize      EQU     24              ; 2  reserved bank-0 stack BYTES (incl the
                                        ;    guard page); 0 = no stack of its own
PI_StkHwm       EQU     26              ; 2  peak BYTES touched, measured by the
                                        ;    STK_PAINT scan; 0 = not measurable
                                        ;    (the region is outside the arena, so
                                        ;    it was never painted -- init)
PI_ArenaUsed    EQU     28              ; 2  PID-0 RECORD ONLY: arena PAGES in use
PI_ArenaFree    EQU     30              ; 2  PID-0 RECORD ONLY: arena PAGES free
PI_HeapHwm      EQU     32              ; 2  the task's HIGH-WATER BREAK, read
                                        ;    straight out of (dataBank:HEAP_HWM).
                                        ;    Bytes the heap has ever had LEFT, at
                                        ;    its tightest, = HEAP_LIM - this.
                                        ;    The PEAK and not the live break: a
                                        ;    process that peaks during startup and
                                        ;    frees reads as idle afterwards, which
                                        ;    is exactly the trap that made the
                                        ;    first read of apple/fgx#42 wrong.
                                        ;    Raw rather than pre-subtracted -- it
                                        ;    is the allocator's own cell.  0 = no
                                        ;    data bank (the kernel's own record).
PI_TtyName      EQU     34              ; 8  the controlling terminal's name,
                                        ;    NUL-padded to TTYNAME_MAX -- the
                                        ;    FIODGNAME spelling ("console",
                                        ;    "ttyv1"), with no "/dev/" prefix.
                                        ;    "" = no controlling terminal.
                                        ;    w(1) matches processes to /etc/utmp
                                        ;    lines by this name; it is the name
                                        ;    and not a device number because
                                        ;    that is what both sides have.
PROCINFO_SIZE   EQU     42

SEF_FRESH       EQU     %00000001       ; never run; first resume -> _Task_FirstRun
SEF_STOPREPORTED EQU    %00000010       ; this stop already reported by a
SEF_REPARENTED  EQU     %00000100       ; inherited orphan (its parent died, so it
                                        ; was reparented to pid 1, which doesn't
                                        ; waitpid inherited orphans).  _Exit_Core
                                        ; auto-reaps such a task's zombie so it
                                        ; doesn't leak its slot.  Cleared on free.
                                        ; waitpid(WUNTRACED); cleared on SIGCONT
SEF_VFORKCHILD  EQU     %00001000       ; fork train: this task borrows its parent's
                                        ; image+stack (vfork).  execve/_exit must NOT
                                        ; free the shared banks — wake the parent
                                        ; (WCHAN_VFORK) and hand the image back.
; --- Controlling terminal (slice D).  Bits 8-10 of SE_Flags hold the task's
; controlling tty as INDEX+1, so 0 = none and the field needs no separate slot:
; the sched entry is exactly full at 32 bytes (SE_SIZE must stay TCB_SIZE/2 so
; a slot offset is a shift, not a multiply), while SEF_* uses only bits 0-4.
;
; ACQUIRED BY OPENING THE TTY, as in BSD -- see _Ttyv_Open.  That is why this is
; not a virtual-console hack: a telnetd session opening a pty slave acquires it
; the same way, which is what job control and signal delivery on a pty need.
; Inherited across fork because the whole sched entry is copied.
;
; 0 = none means "the console", preserving every pre-slice-D task's behaviour
; without touching spawn.
SEF_CTTY_SHIFT  EQU     8
SEF_CTTY_MASK   EQU     %0000011100000000   ; 3 bits: tty index+1, 0..NTTY
SEF_CTTY_CLEAR  EQU     %1111100011111111   ; ~SEF_CTTY_MASK (Merlin has no ~)
; B3 (docs/history/plans/b3-stack-swap-scope.md section 3.3).  Address-preserving stack swap
; is sound only while a PARKED task's stack is untouched by any other context.
; This flag says "the kernel is holding a pointer into THIS task's user stack
; right now", and it is honoured two ways:
;
;   * the swapper (B3.2) must never evict a task carrying it;
;   * `_sleep` PANICS if the CURRENT task carries it, because sleeping
;     interruptibly while someone holds your stack pointer is precisely the
;     combination B3 cannot survive -- a parked task whose bytes are being
;     written behind its back.
;
; LOCK, DO NOT AUDIT.  The survey of paths is the same work either way; the
; difference is the failure mode.  An audit silently expires the first time
; somebody adds a path, whereas the assertion turns that into a loud panic in
; development.  2.11BSD's `lock(2)` is the cautionary case (pdp/kern_pdp.c:71-74):
; a "locked in core" flag the growth path could still override, i.e. a lock not
; honoured on every path, which is worse than no lock at all.
;
; The two windows the B3.0 survey found -- argv/envp staging into a child's
; stack, and the snapshot-fork copy -- both act on a NOT-YET-RUNNABLE task, so
; neither can reach `_sleep` and neither could ever be a swap victim.  They set
; the flag anyway: it costs nothing, it exercises set/clear under the full
; suite, and defence in depth on the eviction path is exactly the lesson above.
SEF_STKLOCK     EQU     %00100000       ; kernel holds a pointer into this task's
                                        ; user stack; unswappable, and must not
                                        ; sleep interruptibly (B3)
SEF_STKLOCK_CLR EQU     %1111111111011111   ; ~SEF_STKLOCK (Merlin has no ~)

; --- SEF_STKBORROW: someone ELSE is running on this task's stack -------------
; The second B3 eligibility condition, and it exists because SEF_STKLOCK above
; STRUCTURALLY CANNOT express this case.
;
; A fork/vfork child owns no stack: _Sys_Vfork copies the parent's StackBank,
; StackPtr, StackBase, StackSize and DirectPage straight across (process.s), so
; the child EXECUTES on the parent's bank-0 pages, at the parent's addresses,
; for the whole borrow window.  The parent meanwhile blocks on WCHAN_VFORK
; through a plain interruptible `_sleep` -- FGX has no uninterruptible variant.
;
; Line that up against the eligibility rule (asleep interruptibly, not locked)
; and a FORKING TASK IS AN ELIGIBLE VICTIM WHILE A RUNNING TASK IS ON ITS
; STACK.  Parking it hands its addresses to another task and overwrites a live
; task underneath it.  fork+exec is how a shell starts anything, and a snapshot
; subshell that never execs (a tcsh pipeline, a backgrounded job) makes the
; window unbounded.
;
; WHY NOT JUST SET SEF_STKLOCK ON THE PARENT.  Because the parent must SLEEP
; while pinned, and `_sleep`'s assertion panics on exactly that.  The two flags
; mean different things over different lifetimes:
;
;   SEF_STKLOCK    "do not swap me right now, and I am not about to sleep"
;                  -- a bounded window inside one syscall, asserted by _sleep.
;   SEF_STKBORROW  "do not swap me for as long as someone else is running on my
;                  bytes" -- spans a sleep by design, so _sleep must IGNORE it.
;
; Both are read by the victim scan; only SEF_STKLOCK is read by the assertion.
;
; ONE BIT IS ENOUGH: vfork blocks the parent until hand-back, so a task can
; never have two borrowers at once.
;
; It also covers _Fork_Restore for free, which the first survey missed: that
; routine writes the parent's stack from the CHILD's context, and it runs BEFORE
; the hand-back clear at both of its call sites, so the parent is still flagged
; ineligible while it happens.
SEF_STKBORROW   EQU     %01000000       ; a fork child is executing on this
                                        ; task's bank-0 stack; unswappable, but
                                        ; MAY sleep (B3)
SEF_STKBORROW_CLR EQU   %1111111110111111   ; ~SEF_STKBORROW

SEF_SNAPCHILD   EQU     %00010000       ; fork train: a snapshot fork child, a member
                                        ; of its parent's image group (the bank home,
                                        ; process.s) until it execs or exits.
SEF_FORKREL     EQU     %10000000       ; a snapshot child that has RELEASED its
                                        ; parent: set by Img_Release at its first
                                        ; interruptible sleep or quantum yield, and
                                        ; cleared with SEF_SNAPCHILD at exec/exit.
                                        ; Until then the child is pinned resident
                                        ; and the parent waits on WCHAN_VFORK.

;==============================================================================
; TTY TABLE (job control, Phase 5.2) — per-terminal foreground process group.
;
; One entry per terminal; NTTY=1 (the console).  TTY_FgPgrp is the process
; group that owns the terminal: keyboard-generated signals (^C/^Z — wired in
; Phase 5.3 once the shell manages this field and ignores SIGINT) target it,
; and a tty read() by a task NOT in this group raises SIGTTIN (default: stop).
; The shell sets/reads it via TIOCSPGRP/TIOCGPGRP.  TTY_Session/TTY_Flags are
; reserved for future controlling-session / line-discipline state.
;
; Until setpgid lands (Task 5.3) every task is in process group 0 and
; TTY_FgPgrp is 0, so the read gate always passes (behavior-preserving).
;
; sgtty(2) state has MOVED OUT (apple/fgx#108 T3 stage 2d): the mode word, the
; speeds and the erase/kill characters are all in the tty bank's `ttys[]' now.
; The console read path still picks its line discipline from the mode word --
; cooked (the default), or char-at-a-time when CBREAK/RAW is set, echoing only
; when ECHO is set -- but it reads t_flags through KTTY_FLAGS_GET.  sg_flags values are
; SG_* in include/loader.s.
;==============================================================================
NTTY            EQU     7               ; terminals: tty[0] = console,
                                        ; tty[1..2] = pty slaves (ttyp0/ttyp1;
                                        ; pty subsystem plan 2026-07-20),
                                        ; tty[3..4] = virtual consoles
                                        ; (ttyv1/ttyv2; slice D, ttyv.s),
                                        ; tty[5] = the SCC chan B serial line
                                        ; (/dev/tty01), apple/fgx#108 T7,
                                        ; tty[6] = ttyv3, the virtual console
                                        ; a Second Sight card displays when
                                        ; sscon.mod finds one (VC_CARD below),
                                        ; and a fourth SHR console otherwise.
; THE CONSOLE A CARD DISPLAYS.  Virtual console VC_CARD (tty[6], /dev/ttyv3)
; renders on the Second Sight card once sscon.mod registers, and then keeps
; rendering while another console is on the IIgs screen: the card is a
; second display, and Option-4 gives that console the keyboard without
; moving the SHR (_kVcFocus against _kVcActive, include/memmap.s).
VC_CARD         EQU     3
                                        ;
                                        ; T7 IS WHY THIS GREW, and the serial
                                        ; line is the first one a MODULE owns:
                                        ; `serial_isr' fills `_sccRxBuf' and
                                        ; `serial_read' pops it, so its bytes
                                        ; met no discipline at all, and
                                        ; `kc_ttyinput(idx, c)' resolves `idx'
                                        ; through `tty_byidx' -- there was no
                                        ; index the receive interrupt could
                                        ; pass.  Chan A gets NO slot: it is
                                        ; AppleTalk's and never fires.
                                        ;
                                        ; CEILING: `SEF_CTTY_MASK' (line 1071)
                                        ; is THREE BITS holding "tty index+1",
                                        ; so index+1 must stay under 8.  Six
                                        ; lines fit and seven would; the eighth
                                        ; needs that field widened first.
                                        ; tty[1..] are explicitly zeroed at
                                        ; boot (main.s @ttyz — DS regions are
                                        ; NOT guaranteed zero in RAM) and take
                                        ; their sgttyb/tchars defaults at pty
                                        ; open (P2).
                                        ;
                                        ; The VCs are APPENDED, never inserted:
                                        ; pair->tty is baked at pty.s:94-102.
                                        ; See the header of src/kernel/ttyv.s.
; TTY_CANON_SZ IS GONE, NOT RESTORED TO 256 (increment 8b).  It was 256 until
; increment 4 put the core bank 42 bytes over its ceiling and the buffer it
; sized was the lever; 128 was always temporary.  8a's deletions returned 698
; bytes and this returns 640 more, so the debt is paid and the constant has
; nothing left to size.
                DUM     0
; TTY_FgPgrp IS GONE (apple/fgx#108 T3 stage 1c).  The foreground process group
; lives in the tty bank's `ttys[].t_pgrp' now -- one field, one bank -- reached
; through _Tty_PgrpOf / _Tty_SetPgrp, or KSVC_TTYPGRP / KSVC_TTYSETPGRP from a
; module.  Deleting it rather than leaving a hole IS the stage: while two copies
; existed the two disciplines could disagree about who is in the foreground,
; which is the desynchronisation this campaign warned about from T1.  Every
; offset below shifts down by two, and all of them are symbolic.
TTY_Session     DS      2               ; reserved: controlling session id
TTY_Flags       DS      2               ; reserved: misc line-discipline flags
; THE sgttyb IMAGE IS GONE (apple/fgx#108 T3 stage 2d).  All five fields live
; in the tty bank now, and NOT as an image: `sg_erase' and `sg_kill' are
; `t_chars.tc_erase'/`tc_kill' (they went with the characters at 2b),
; `sg_ispeed'/`sg_ospeed' are `t_ispeed'/`t_ospeed', and `sg_flags' is the LOW
; WORD of `t_flags'.  That is upstream's own decomposition -- `usr/sys/sys/
; tty.c:1554-1600' copies field by field between a `struct sgttyb' and those
; five members; there is no image to copy in BSD either.
;
; The 10-byte spelling and its `MUST STAY short' note both dated from a version
; of fcc that gave every struct member a 2-byte slot.  fcc has packed `char' at
; one byte since B-8 (2026-07-06), so what was a correct decision about an
; older compiler had become a second truth about a layout the tty bank owns.
; Userland's `struct sgttyb' moved to BSD's 6 bytes in the same commit.
; THE tchars IMAGE IS GONE (apple/fgx#108 T3 stage 2b), and so is TTY_Ltchars
; below it.  Both live in the tty bank's `ttys[].t_chars' now -- one 14-byte
; `struct ttychars' where the core kept a 12-byte tchars image and a separate
; 6-byte packed ltchars one -- because that is where `ttioctl' already reads
; and writes them.  TIOCGETC/SETC/GLTC/SLTC are answered there; the defaults
; come from upstream's `ttydefaults' through `_Tty_Chars'; and pty.mod reaches
; t_intrc/t_quitc through KSVC_TTYINTRQUIT.  Deleting them rather than leaving
; them is the stage: while both copies existed the ioctl and the pty write path
; would disagree about which character interrupts.
; --- the cooked canonical line buffer STOOD HERE (T3 stage 4 increment 8b) ---
; `TTY_CanonLen', `TTY_CanonPos' and a 128-byte `TTY_CanonBuf' per line: the
; core's own copy of the BSD canonical-mode model, assembled by a line editor
; that increment 8a deleted.  The queue is a clist in the tty bank now, and the
; four routines that used to flush a line by zeroing the two cursors ask the
; bank instead -- through `_Tty_Flush' (slot 20), except the signal-delivery
; one, which latches `_kTtyFlushPend' because it can run from the switch path.
; 640 bytes of core-bank data back, five lines' worth.
; --- pty subsystem (plan 2026-07-20) ---
; Byte source + echo sink selector for the line discipline.  $0000 = console
; backend (Con_GetKey / Con_Write, the pre-pty behavior for tty[0]); nonzero =
; the owning pty-pair record's byte offset into the pty table (slave reads
; drain the pair's input ring, echo appends to its output ring).  Appended
; LAST so every pre-existing TTY_* offset is unchanged.
TTY_Backend     DS      2
; THE LOCAL MODE WORD IS GONE TOO (stage 2d), and it never was a separate word
; upstream: `ioctl.h:175-189' defines every L* bit as `((int)(BIT>>16))', so
; LTOSTOP $0040 IS TOSTOP $00400000 shifted down sixteen.  The bank's
; `t_flags' is one long holding both halves, which is why TIOCLGET is
; `*(int *)data = (int)(tp->t_flags >> 16)' and nothing more.  Read through
; KTTY_FLAGS_GET's high word; the LTOSTOP and LNOFLSH masks below are the core's, and
; still what signal.s tests.
; THE struct winsize IMAGE IS GONE TOO (apple/fgx#108 T3 stage 2c), the way
; the tchars pair went at 2b.  `ttys[].t_winsize' is the only copy now, because
; that is where `ttioctl' already reads and writes it -- upstream's own
; TIOCGWINSZ/TIOCSWINSZ arms, `usr/sys/sys/tty.c:556-566'.  The SEED still
; crosses from here: `_Tty_CookedDefaults' gives every line the console
; viewport through slot 15, and pty.mod re-seeds a slave to the BSD 80x24
; through KSVC_TTYWINSZ.
TTY_SIZE        EQU     *

; L* bits of the local mode word that the KERNEL acts on.  MUST match
; toolchain/include/sgtty.h -- the two lists are edited together, and userland
; is the one that sets these.
LTOSTOP         EQU     $0040           ; sgtty.h:130.  SIGTTOU a background
                                        ; process that writes to this line.
                                        ; BSD ttwrite tty.c:1348; off by
                                        ; default there too, so the DEFAULT
                                        ; behaviour is unchanged -- what
                                        ; apple/fgx#74 fixed is that the knob
                                        ; did nothing at all when set.
LNOFLSH         EQU     $8000           ; sgtty.h:129.  Suppress the input flush
                                        ; that INTR otherwise performs (BSD
                                        ; ttyinput's `if ((t_flags&NOFLSH)==0)`;
                                        ; see _Tty_DeliverSig, apple/fgx#56).
                DEND

;==============================================================================
; PER-TASK U-AREA (cooperative multitasking, Phase 3) — BSD `struct user` analog.
;
; Syscall-in-progress state that must survive a mid-syscall block (Phase 3+).
; One per task, Kmalloc'd (M_KERN); SE_UareaPtr holds the 24-bit ptr.  The
; dispatcher swaps the _u DP long-ptr to the current task's u-area on entry, so
; these are reached via [_u],Y.  Everything NOT here stays a shared global
; (non-blocking syscalls never have two live instances).
;==============================================================================
                DUM     0
U_UserSP        DS      2               ; was _Sys_UserSP (per-task carryover)
U_UserDP        DS      2               ; was _Sys_UserDP
U_CallerBank    DS      2               ; was _Sys_CallerBank (low byte; word-aligned)
U_RecvScratch   DS      24              ; recv/read cross-block scratch (Phase 4
                                        ; right-sizes to the _sock*/_Sys_Rd* set)

; Process credentials (credentials campaign P1; plan §2.1).  These were two
; kernel globals (_kProcUid/_kProcGid, memmap.s) until 2026-07-28 — one set for
; the whole machine, which fork could not make sense of.
;
; The u-area is the home BECAUSE the other two per-task structs are physically
; full: the TCB is ERR-guarded at 64 B with every aliasable v3 field already
; claimed, and SE_ sums to exactly 32 with zero pad.  The u-area is Kmalloc'd
; per task with no size ceiling, and is BSD's own home for u_uid/u_gid.
;
; Real vs effective: BSD's getuid(2) returns the REAL id and geteuid(2) the
; effective one.  Both are carried now even though nothing can yet make them
; differ (setuid is P2), so the P2 syscalls set fields that already exist and
; the fork/exec inheritance below never needs revisiting.  Saved-set ids exist
; for the same reason — they are what a non-root setuid(2) is allowed to
; return to.
;
; Supplementary groups (BSD u_groups[NGROUPS]) are deliberately absent — see
; the plan's §6.  A single gid covers everything UFS and telnetd need.
; ORDER IS LOAD-BEARING (P2): each id is a {real, effective, saved} TRIPLE at a
; uniform +0/+2/+4 stride, so setuid and setgid are one shared routine taking
; the triple's base offset — see _Cred_Set in syscall.s.  Grouping by kind
; (all reals, then all effectives) would force two near-identical copies.
U_Ruid          DS      2               ; real uid       (uid triple +0)
U_Uid           DS      2               ; effective uid  (uid triple +2)
U_Svuid         DS      2               ; saved-set uid  (uid triple +4)
U_Rgid          DS      2               ; real gid       (gid triple +0)
U_Gid           DS      2               ; effective gid  (gid triple +2)
U_Svgid         DS      2               ; saved-set gid  (gid triple +4)
U_CRED_REAL     EQU     0               ; triple-relative: real
U_CRED_EFF      EQU     2               ;                  effective
U_CRED_SAVED    EQU     4               ;                  saved-set
U_CREDS_OFF     EQU     U_Ruid          ; first cred field — copy base for fork
U_CREDS_LEN     EQU     *-U_Ruid        ; bytes of contiguous cred state (12)

; File-creation mask (UFS 1.2).  BSD's u_cmask, and 2.11BSD's is a `short`.
;
; DEFAULT 022, WHICH IS RENO'S CMASK (sys/param.h:80); 2.11BSD's is 026
; (h/param.h:61).  Upstream treats this as a patchable policy global read once
; at init -- `int cmask = CMASK;` -- rather than anything structural, which is
; why the two ancestors differ freely.  022 is also what FGX's libc has always
; used, so moving the mask into the kernel changes no behaviour.
U_Cmask         DS      2               ; mask for file creation (BSD u_cmask)

; Resource limits (UFS 1.2).  BSD's u_rlimit[RLIM_NLIMITS], each entry a
; { rlim_cur, rlim_max } pair of longs, in RLIMIT_* index order.
;
; THE COUNT IS 9, WHICH IS NEITHER ANCESTOR'S.  2.11BSD and Reno both say 6
; (h/resource.h:77, sys/resource.h:71); toolchain/include/sys/resource.h says 9,
; having added the 4.4BSD-era MEMLOCK, NPROC and NOFILE.  RLIM_NLIMITS is a
; census of the limits a system HAS rather than a format or an architecture
; choice, so the kernel follows FGX's own header -- a kernel array shorter than
; the header would make setrlimit silently discard the top indices while
; honouring the rest, which is worse than either number.
;
; The two copies of the count are checked at RUNTIME rather than trusted:
; credprobe loops to the header's RLIM_NLIMITS and requires every index to
; answer, so a kernel array that is short fails the test rather than the caller.
;
; RENO READS FIVE OF THESE, and knowing which is what tells a reader whether a
; slot is storage or a contract: RLIMIT_CPU (kern_clock.c:156), RLIMIT_FSIZE
; (ufs_vnops.c:700, 2.11BSD sys_inode.c:190 -- write past the limit is SIGXFSZ
; + EFBIG), RLIMIT_DATA (kern_mman.c:342 and :860), RLIMIT_STACK
; (kern_mman.c:480) and RLIMIT_CORE (kern_sig.c:976).
;
; TWO OF THE FIVE HAVE FGX COUNTERPARTS.  RLIMIT_DATA is enforced by _Sys_Brk
; (process.s), which is the break path Reno checks; RLIMIT_FSIZE arrives with
; the UFS write path.  The other three name machinery FGX does not have -- a
; scheduler with accounting, a growable stack segment, core dumps -- so their
; slots are storage that `limit'/`ulimit' can read back, and nothing more.
U_RLIM_NLIMITS  EQU     9               ; = toolchain/include/sys/resource.h
U_RLIM_ENTLEN   EQU     8               ; sizeof(struct rlimit): two longs
U_RLIMIT_DATA   EQU     2               ; = RLIMIT_DATA, sys/resource.h
U_Rlimit        DS      U_RLIM_NLIMITS*U_RLIM_ENTLEN

; RESTART STATE (apple/fgx#105).  APPENDED, not inserted: the u-area's offsets
; are read from more than one place and inserting in the middle shifts every
; field below it -- measured, four gate tests went red on exactly that.  2.11BSD's tsleep returns ERRESTART rather than
; EINTR for every caught signal not named in u_sigintr, and trap() rewinds the PC
; so the syscall is re-entered.  FGX has no PC to rewind in the kernel -- its
; syscall ABI is `JSL SYS_TRAMP / DFB num`, so the restart is done by rewinding
; the STACKED return PC to the JSL and letting it re-execute.
;
; The re-executed JSL cannot be relied on to still hold the arguments: a signal
; handler runs in between, and _libc_sigtramp (libc_start.s) exits PLX / TXA, so A and X
; come back EQUAL and only two independent register values survive the delivery.
; So the dispatcher overrides them instead -- it saves A/X/Y on entry anyway, and
; on a restart it reloads them from here rather than from the registers.
;
; The u-area is the home for the same reason the credentials are, and its header
; says it above: the TCB is full and ERR-guarded, SE_ has zero pad, and this is
; syscall-in-progress state that must survive a mid-syscall block -- which is
; what this struct is FOR.  It is also where 2.11BSD keeps u_sigintr, which the
; per-signal SV_INTERRUPT half of #105 will need next.
U_RestartFlag   DS      2               ; nonzero: the syscall abandoned its work
                                        ; to a signal WITHOUT delivering anything
                                        ; to the caller, and may be re-entered.
                                        ; Set only by a site that knows it took
                                        ; no side effects; consumed and cleared
                                        ; by the dispatcher.
U_RestartA      DS      2               ; the call's original A/X/Y, captured at
U_RestartX      DS      2               ; the moment the restart is marked, while
U_RestartY      DS      2               ; _Sys_Saved* still hold the caller's args
U_StopSig       DS      2               ; apple/fgx#109: the signal that STOPPED
                                        ; this task, for waitpid(WUNTRACED)'s
                                        ; WSTOPSIG.  2.11BSD keeps it on the
                                        ; process as p_ptracesig and wait1
                                        ; returns (p_ptracesig << 8) | WSTOPPED;
                                        ; FGX had nowhere to put it and built the
                                        ; status from a constant, so ^Z, a
                                        ; background tty READ (SIGTTIN) and a
                                        ; background tty WRITE (SIGTTOU) were all
                                        ; indistinguishable to the parent -- and
                                        ; a job-control shell picks its message
                                        ; ("Stopped (tty input)" vs "(tty
                                        ; output)") from exactly this value.
                                        ;
                                        ; APPENDED, not inserted: every field
                                        ; below an insertion point shifts, which
                                        ; took four gate tests red during #105.

; THE TTY WRITE'S TRANSFER IN PROGRESS (apple/fgx#108 T3 stage 3).  PER TASK,
; AND THAT IS THE WHOLE REASON IT IS HERE rather than a pair of kernel-bank
; statics, which is where the first cut of stage 3 put them.
;
; A uio is a CURSOR: `ttwrite' consumes it as it goes, so it is live across
; everything the discipline does -- including `_PtyS_Write' sleeping on a full
; pty ring, three banks down inside `tty_oproc'.  Two tasks writing at once
; then walked ONE uio: task A slept mid-transfer, task B rebuilt the singleton,
; and A resumed advancing B's cursor.  It presents as CORRUPTION WITHIN A LINE
; -- `ttypeneg' read back "Ihus no jjob control", one character overwritten and
; one doubled -- rather than as a lost write, which is why it survived a green
; `smoke': a single writer cannot collide with itself.
;
; That is apple/fgx#89's shape exactly, and this file's own head note says what
; belongs here: "Syscall-in-progress state that must survive a mid-syscall
; block".  The kernel stack would serve equally, and BSD builds its uio on one;
; the u-area is chosen because the tty bank needs a STABLE FAR POINTER and a
; u-area address is one for as long as the task exists.
;
; APPENDED, not inserted -- see U_StopSig above on what an insertion costs.
U_TtyIov        DS      6               ; struct iovec: iov_base (far) + len
U_TtyUio        DS      16              ; struct uio; src/kernel/vfs/uio.h
;
; U_TtyObuf - `ttwrite's staging buffer, which upstream keeps ON THE KERNEL
; STACK and FGX cannot.
;
; `char obuf[OBUFSIZ]' (2.11BSD tty.c:1322, OBUFSIZ 100 at h/tty.h:95) is a
; fifth of FGX_KSTK_SIZE, and the `/dev' VNODE road reaches `ttwrite' with the
; whole `vn_write' -> `spec_write' -> `spec_chwrite' -> `kc_cddwrite' chain of
; fcc frames still standing under it -- about 136 bytes deeper than the
; registry road was.
; Measured with the painted arena (tools/mame_test/kstkhwm_check.py): 516 of
; 512, and a machine RESET with no diagnostic, because `_fcc_stkfloor' is left
; at zero on FGX_DP_KERNELC and so nothing catches the overrun.
; apple/fgx#246 carries the four numbers and the options.
;
; SO IT MOVES HERE, WHICH IS THE REASON THE TWO FIELDS ABOVE ARE HERE and their
; note already says it: "the tty bank needs a STABLE FAR POINTER and a u-area
; address is one for as long as the task exists".  `ttwrite' holds this buffer
; across `kc_lbolt' and across the high-watermark sleep, so it must also be PER
; TASK -- a static in the tty bank would be apple/fgx#89, two writers sharing
; one buffer across a sleep.
;
; THIS EQU IS THE ONE AUTHORITY ON THE LENGTH, and that is why upstream's
; `OBUFSIZ' #define is gone rather than kept beside it.  The C asks
; `kc_ttobufsz()' where it used to spell OBUFSIZ, so the chunk size and the
; reservation cannot disagree -- there is no second number to keep in step and
; no checker needed to prove they match.  100 is upstream's value.
;
; APPENDED, not inserted -- see U_StopSig above on what an insertion costs.
U_TTYOBUF_LEN   EQU     100             ; = 2.11BSD h/tty.h:95's OBUFSIZ
U_TtyObuf       DS      U_TTYOBUF_LEN

; THE SESSION'S LOGIN NAME, which is setlogin(2)'s storage and getlogin(2)'s
; answer.  2.11BSD keeps it in exactly this place -- `char u_login[MAXLOGNAME]',
; usr/sys/h/user.h:143 -- and its kern_prot.c says why the u-area rather than a
; session structure: "since 2.11 doesn't have sessions and it's almost
; impossible to know if a process is `login' or not we simply restrict this
; call to the super user".  FGX has no sessions either, so it inherits both the
; storage and the rule.
;
; THE U-AREA IS WHAT MAKES IT INHERITED, and that is the whole point of the
; call: the name belongs to the SESSION and must survive fork, exec and a
; change of uid, so that `who am I really' still answers after su(1).
; U_INHERIT_LEN below is U_SIZE, so appending here is inherited by fork with no
; further work.  Zeroed with the rest of the u-area at task creation, so a task
; nobody ever called setlogin for has an empty name -- which getlogin reports
; as "no login name", upstream's answer when setlogin was never called.
;
; APPENDED, not inserted -- see U_StopSig above on what an insertion costs.
U_LOGIN_LEN     EQU     16              ; = 2.11BSD h/param.h:132's MAXLOGNAME
U_Login         DS      U_LOGIN_LEN

; U_Aiov - readv(2)/writev(2)'s copy of the caller's vector, which 2.11BSD keeps
; on the kernel stack (`struct iovec aiov[16]', sys_generic.c:65) and FGX cannot:
; 96 bytes is a fifth of FGX_KSTK_SIZE, for the reason U_TtyObuf gives.  PER TASK
; because uiomove advances these entries while the transfer sleeps.  U_TtyUio
; points at it for a vector call and at U_TtyIov for read(2)/write(2).
;
; APPENDED, not inserted -- see U_StopSig above on what an insertion costs.
UIO_MAXIOV      EQU     16              ; = 2.11BSD's aiov[16]
U_Aiov          DS      6*UIO_MAXIOV
U_SIZE          EQU     *               ; total u-area size (computed)

;------------------------------------------------------------------------------
; INHERITANCE IS BY DEFAULT, AND THE EXCEPTIONS ARE NAMED.  This is BSD's
; polarity and it is the safer one.
;
; BSD's fork duplicates the WHOLE u-area (2.11BSD kern_fork.c:240 mallocs USIZE
; and copies) and then explicitly clears the few fields that must not carry
; over -- u_ru, u_cru, u_acflag, the return registers.  FGX did the opposite
; until UFS 1.2: Task_AllocUarea zeroed the child and _Uarea_InheritCreds
; copied the one block that had to survive.
;
; THE COST OF THAT POLARITY IS WRITTEN IN ITS OWN COMMENT: "without this a
; forked child would silently come up as root regardless of its parent."  Under
; zero-by-default, a field that SHOULD inherit but was left off the copy list
; gets zero -- and for a uid, zero is root.  For a creation mask, zero masks
; nothing.  The forgotten case fails PERMISSIVE, every time, because zero is
; the permissive value for almost everything a u-area holds.
;
; Under copy-by-default the forgotten case is a field that inherits when it
; should not, which is a correctness bug rather than a privilege one, and it is
; visible to the process that notices it.
;
; U_NOINHERIT_* names the exception list.  IT IS EMPTY TODAY and that is not an
; oversight: the only live fields are the credentials (which inherit) and
; U_Cmask (which inherits).  U_UserSP/U_UserDP/U_CallerBank/U_RecvScratch are
; reserved for a carryover migration that has not happened -- nothing in the
; tree reads or writes them -- so copying them copies zeros.  When the first
; genuine exception arrives it goes here, beside the reason.
U_INHERIT_LEN   EQU     U_SIZE          ; copy the whole thing, then except
                DEND

;==============================================================================
; SYSTEM CALL NUMBERS
;
; Authoritative list lives in include/loader.s — that file's numbering
; follows 2.11BSD's <sys/syscall.h> per the program-execution design spec.
; The Feb-1 SYS_* table that lived here was unused (no dispatcher, no callers)
; and has been removed to prevent collision with the BSD-numbered scheme.
;==============================================================================

;==============================================================================
; ERROR CODES
;==============================================================================

ERR_NONE        EQU     $0000           ; No error (success)
ERR_NOTASK      EQU     $0001           ; Task does not exist
ERR_NOMEM       EQU     $0002           ; Out of memory
ERR_INVAL       EQU     $0003           ; Invalid parameter
ERR_BUSY        EQU     $0004           ; Resource busy
ERR_TIMEOUT     EQU     $0005           ; Operation timed out
ERR_NOPORT      EQU     $0006           ; Port does not exist
ERR_MSGFULL     EQU     $0007           ; Message queue full
ERR_MSGEMPTY    EQU     $0008           ; No messages available
ERR_PERM        EQU     $0009           ; Permission denied
ERR_NODEV       EQU     $000A           ; Device not found
ERR_IO          EQU     $000B           ; I/O error
ERR_NOTREADY    EQU     $000C           ; Resource not ready
ERR_BADHANDLE   EQU     $000D           ; Invalid handle
ERR_EXISTS      EQU     $000E           ; Resource already exists
ERR_NOENT       EQU     $000F           ; Entry not found
ERR_FAULT       EQU     $0010           ; Memory access fault
ERR_NOCHILD     EQU     $0011           ; No child processes
ERR_INTR        EQU     $0012           ; Operation interrupted
ERR_AGAIN       EQU     $0013           ; Try again
ERR_NOSYS       EQU     $00FF           ; System call not implemented

;==============================================================================
; WELL-KNOWN PORTS
;==============================================================================

PORT_KERNEL     EQU     1               ; Kernel services
PORT_MEMORY     EQU     2               ; Memory manager
PORT_FILESYS    EQU     3               ; File system server
PORT_VIDEO      EQU     4               ; Video driver
PORT_INPUT      EQU     5               ; Input manager (keyboard, mouse)
PORT_AUDIO      EQU     6               ; Audio driver
PORT_DISK       EQU     7               ; Disk driver
PORT_CONSOLE    EQU     8               ; Console/shell

;==============================================================================
; READY QUEUE STRUCTURE
;==============================================================================

; Per-priority queue (8 bytes each)
RQ_Head         EQU     $00             ; [2] First task in queue (or 0)
RQ_Tail         EQU     $02             ; [2] Last task in queue (or 0)
RQ_Count        EQU     $04             ; [2] Number of tasks in queue
RQ_Reserved     EQU     $06             ; [2] Reserved
RQ_SIZE         EQU     $08             ; Size per queue

;==============================================================================
; SYSTEM LIMITS
;==============================================================================

; Maximum simultaneous tasks.  Single knob: NPROC comes from cfg/system.cfg
; (kernel.nproc -> CFG_KERNEL_NPROC, generated into include/config.s which is
; PUT before this file).  It sizes the TCB table (TASK_MAX_SLOTS), the
; scheduler-state table, and the per-task kernel-stack/u-area pool.
NPROC           EQU     CFG_KERNEL_NPROC
; Preemption P1 (Model A): scheduling quantum in VBL ticks.  Every
; QUANTUM_TICKS VBLs the heartbeat requests a resched, honored at the next
; syscall boundary.  Chartered by the P0 survey: ~66 ms sits well clear of
; typical syscalls (a worst-case posix_spawn is ~10 quanta and simply runs).
QUANTUM_TICKS   EQU     4
; BSD's `hz' for the lbolt wake: the VBL is 60 Hz, so 60 ticks is upstream's
; once-a-second `timeout(schedcpu, 0, hz)'.  Not shared with QUANTUM_TICKS on
; purpose -- one is a scheduling quantum and the other is a wall-clock period,
; and they answer to different things if either is ever retuned.
LBOLT_TICKS     EQU     60
; CPU states the heartbeat charges each tick to, as 2.11BSD's h/dk.h numbers
; them (`cp_time[cpstate]++', sys/kern_clock.c:198).  _kCpState holds one:
; the dispatcher sets CP_SYS on entry and CP_USER on every way back to user
; code, swtch's idle loop sets CP_IDLE around its WAI.  CP_NICE is never set:
; the heartbeat runs on the interrupted task's direct page and cannot read
; its nice value, so niced user time is charged to CP_USER.
CP_USER         EQU     0
CP_NICE         EQU     1
CP_SYS          EQU     2
CP_IDLE         EQU     3
CPUSTATES       EQU     4
; apple/fgx#242: how many heartbeat ticks run the ISR-context bracket probe
; (toolbox.s) before it stands down.  Enough that _hbLcRuns is a denominator
; and not a single sample; small enough that the cost is a compare per VBL for
; the rest of the boot.  _KcIrqProbe reports the result as case 13.
LC_PROBE_TICKS  EQU     8
; Per-task cwd/name table total sizes = (NPROC+1)*stride, for pid 0..NPROC.
; Written mult-first so left-to-right evaluation = (NPROC+1)*stride WITHOUT
; parens (Merlin32 rejects '(' inside #{} immediate expressions).
CWD_TBL_BYTES   EQU     NPROC*CWD_MAX+CWD_MAX
NAME_TBL_BYTES  EQU     NPROC*PROC_NAME_MAX+PROC_NAME_MAX

;==============================================================================
; COP SIGNATURE FOR SYSTEM CALLS
;==============================================================================

FGX_COP_SIG     EQU     $80             ; COP signature byte for FGX syscalls

; System call format:
;   COP   $80           ; FGX system call
;   DFB   syscall_num   ; System call number follows COP instruction

;==============================================================================
; END OF FILE
;==============================================================================

;==============================================================================
; THE KERNEL LOG RING'S SIZE.
;
; HERE AND NOT IN memmap.s, WHICH IS WHERE THE RING'S STATE LIVES, because two
; banks need this one: the core kernel wraps its write index on it (log.s) and
; klog.mod wraps its read cursor on it (src/modules/klog).  memmap.s is itself a
; PUT file and Merlin32 does not nest PUT, so the constant cannot be shared from
; there; include/kernel.s is PUT before memmap.s (src/kernel/main.s:28 against
; :32) and by the module as well, so one declaration reaches both.
;
; A SHARED DECLARATION AND NOT A SCRAPED SYMBOL.  The module's other kernel
; imports come through its generated kernel_exports.s, which resolves ADDRESSES
; out of the kernel listing.  This is a VALUE, and putting it in that manifest
; broke the kernel build identity -- a sum over sampled exported symbols that
; Merlin evaluates symbolically and the generator recomputes in Python, which do
; not agree about an EQU that is a size rather than a location.
;
; IT HAS BEEN RESIZED ONCE: 1792 -> 4096 on 2026-08-07, when the third console
; landed, because at 1792 the ring wrapped fast enough to clip a line that had
; already been written.  A copy in the module is the thing that would not have
; moved with it.
;==============================================================================
KMEM_LOGBUF_SIZE        EQU $1000           ; kernel log ring size (4096 B); the
                                            ;   ring itself is heap, reached
                                            ;   through the _kLogBufPtr DP
                                            ;   long-pointer
