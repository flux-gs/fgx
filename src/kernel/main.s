;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     main.s
; Purpose:  Kernel entry point and initialization
; Author:   FGX Development Team
; Created:  2025-02-01
;
; This is the main kernel module for FGX v0.1.0.
;
; v0.1.0 Target:
;   - Initialize SHR 640x200 with dark grey background
;   - Display FGX logo (Sun-style, colorful)
;   - Detect and display hardware info
;   - Halt
;
;==============================================================================

                MX      %00             ; 16-bit A, X, Y (native mode default)

;==============================================================================
; INCLUDES
;==============================================================================

                PUT     ../../include/config.s
                PUT     ../../include/hardware.s
                PUT     ../../include/kernel.s
                PUT     ../../include/errno.s
                PUT     ../../include/fs.s
                PUT     ../../include/console.s
                PUT     ../../include/memmap.s
                PUT     ../../include/dpmap.s
                PUT     ../../include/vfs_equ.s    ; GENERATED from fsparam.h
                PUT     ../../include/macros.s
                PUT     ../../include/loader.s
                PUT     ../../include/modules.s
                PUT     ../../include/kfar.s
                PUT     ../../include/ktty.s
                PUT     ../../include/kernelc.s
                PUT     far/fcc_dp.s            ; KC_DP_LO/KC_DP_BYTES: swtch has
                                                ; to save the kernel-C register
                                                ; file, and the band must come
                                                ; from the generated map, never a
                                                ; literal.  EQUs only, no bytes.
                PUT     ../../include/chardev.s
                PUT     ../../include/pty.s     ; shared with pty.mod
                PUT     ../../include/ifnet.s
                PUT     ../../include/socket.s
                PUT     ../../include/fgxm.s
                PUT     ../../include/ramdisk.s

; Cross-segment externals — block driver is link-file segment #2.
Blk_Init        EXT
Blk_LogBootDev  EXT                     ; the boot drive's own inventory line
Blk_Read        EXT
Blk_Write       EXT
_BlkCache_InvalAll EXT
_BlkCache_PinGet EXT
_BlkCache_Unpin EXT
_BlkCache_PinAllocZ EXT
                DO      BLKPROBE=1
_BlkCache_Probe EXT
                FIN
Blk_Status      EXT
Blk_DetectCaps  EXT
Blk_CapsFlags   EXT
Blk_DibSubtype  EXT
_blkSmartJump   EXT
_blkFwCall      EXT

;==============================================================================
; KERNEL ENTRY POINT
;==============================================================================
                ORG     FGX_CODE        ; $022000


;=============================================================================
; FGX_Entry - Kernel entry point
;-----------------------------------------------------------------------------
; Called by boot loader after kernel is loaded into bank $02.
; Initializes hardware, displays boot info, and halts.
;=============================================================================
FGX_Entry
                ; Native mode, 16-bit A/X/Y.
                CLC
                XCE
                REP     #$30

                ; Kernel direct page + stack.  Pick the DP page by build:
                ;  - Relocating loader: zeroed the kernel's own page
                ;    (FGX_DP_KKERN) and hands the kernel off on it.
                ;  - Legacy $02 loader: keeps the zero-page boot DP (FGX_DP_KERNEL).
                ; A zero-page kernel DP puts the kernel's DP soft-globals in
                ; $00:0000-00FF, which the IIgs ROM / ProDOS / ADB firmware uses on
                ; REAL hardware during IRQ/keyboard handling -> SIM dispatch +
                ; keyboard-IRQ corruption (invisible in MAME, which doesn't drive
                ; the real ADB IRQ path).  $0900 keeps it clear of the firmware ZP.
                ; FGX_RELOC isn't visible to the kernel build, so detect the build
                ; from the loader-written anchor bank at $00:032C ($02 = legacy).
                SEP     #$20
                MX      %10
                LDAL    $00032C                 ; KFGX_ANCHOR = live kernel bank
                CMP     #$02
                REP     #$30
                MX      %00
                BEQ     @fe_dpLegacy
                LDA     #FGX_DP_KKERN           ; reloc: the loader zeroed it
                BRA     @fe_dpSet
@fe_dpLegacy    LDA     #FGX_DP_KERNEL          ; legacy $02: zero-page boot DP
@fe_dpSet       TCD
                LDA     #FGX_STK_KERNEL+$FF
                TCS

                ; PAINT THE BOOT STACK, so its depth can be MEASURED rather
                ; than inferred from whether the machine survived
                ; (apple/fgx#172).
                ;
                ; FGX_STK_KERNEL is 256 bytes and everything Mod_LoadConf
                ; drives lives inside it -- every module's mod_init, and every
                ; on-disk probe those run.  UFS 1.11a did not fit: the chain ran
                ; off the bottom of page 1 into page ZERO, which is fcc's
                ; register file and the kernel direct page, and the machine
                ; wandered with a blank screen.  That cost two sessions,
                ; because an overflow here is SILENT -- every *_STKGUARD in the
                ; module build is 0, so _fcc_stkoflow never fires -- and the
                ; margin that survived was never a number, only "it booted".
                ;
                ; EACH BYTE IS PAINTED WITH ITS OWN LOW ADDRESS, not a constant.
                ; The scan after Mod_LoadConf reports the lowest byte that
                ; CHANGED, and a constant fill would mis-report that mark
                ; upward whenever the stack happened to store the constant
                ; there -- an error in the reassuring direction.  Position
                ; painting needs the stack to have written a byte's own low
                ; address at that byte to fool it.
                ;
                ; PAGE 1 IS ENTIRELY FREE HERE.  FGX_Entry is jumped to by the
                ; loader, not called, so nothing is live below the TCS above.
                SEP     #$30
                MX      %11
                LDX     #$00
@fe_stkPaint    TXA
                STAL    $000000+FGX_STK_KERNEL,X
                INX
                BNE     @fe_stkPaint
                REP     #$30
                MX      %00

                ; Set DBR = PB = the live kernel bank so STA abs / LDA abs
                ; default to the kernel bank ($02 = assembly ORG; PHK sources
                ; the runtime bank under reloc).  Without this, abs accesses go
                ; to bank 0 (CPU reset default).  Existing kernel code mostly
                ; used STAL/LDAL (bank-explicit) so it didn't notice; the new
                ; syscall dispatcher and program loader use STA abs for
                ; module-local state and need DBR=kernel-bank to be sane.
                PHK                             ; push PB (= live kernel bank)
                PLB                             ; DBR = kernel-bank

                ; Wave-E reloc self-mod: patch the 29 baked-$02 operand BANK bytes
                ; in modload/signal/syscall/jumptable (STAL/LDAL sites that run at
                ; DBR != kernel bank, so they can't be DBR-rel'd) from $02 to the
                ; live kernel bank.  ONCE, here, before any of them first executes
                ; (module load / syscall dispatch / chardev reg).
                JSR     _RelocPatchWaveE

                ; Keep IRQs off; we run polled for now.
                SEI

                ; Zero kernel globals before any write (owner: main.s).
                ; Write canaries at every region boundary so subsequent
                ; subsystem inits can be validated.
                JSR     _KMem_ClearGlobals
                JSR     _KMem_WriteCanaries

                ; Cache the kernel direct page (FGX_DP_KKERN, the loader's
                ; hand-off page, set via TCD at FGX_Entry) into _kFgxDPKernel so SYS_* dispatch can
                ; restore D after switching to a caller's DP.  TDC reads the live
                ; 16-bit D (always bank-0 for 65816).  MUST come AFTER
                ; _KMem_ClearGlobals: _kFgxDPKernel lives inside the KMem_KGlobals
                ; region, so caching it before the zero would be wiped out (and the
                ; old reloc-no-op zeroer hid this by never touching the live bank).
                ; --- the kernel's own direct page, zeroed ---
                ; Boot has run on it since the hand-off, and nothing on it is
                ; live across this point.  It is the kernel's own page AND the
                ; template every task's slot page is copied from (_Slot_Seed),
                ; so it has to be clean before anything establishes a heap or
                ; table pointer -- those are the cells the copies exist to
                ; carry -- and _curTask must read 0 (no task is running) rather
                ; than whatever early boot left behind.
                REP     #$30
                MX      %00
                LDX     #0
                LDA     #0
@kdp_zero       STAL    $000000+FGX_DP_KKERN,X
                INX
                INX
                CPX     #256
                BCC     @kdp_zero
                STA     _kCurPid                ; A is still 0: no task yet
                LDA     #FGX_DP_KKERN
                TCD
                STA     _kFgxDPKernel
                STAL   KFGX_CUR_KDP             ; boot's page is the template's,
                                                ;   until the scheduler binds a
                                                ;   task's slot (task.s)

                ; Two-handle MM model: seed _restBaseBank from the bank-0
                ; KFGX_REST_ANCHOR (loader-written).  Default to REST_BASE_DEFAULT
                ; ($03) when the magic is absent — the static $02 build, or before
                ; Task 2 wires the loader.  DBR = kernel bank here (set above).
                SEP     #$20
                MX      %10
                LDAL    KFGX_REST_ANCHOR_MAG
                CMP     #$4B
                BNE     @rb_default
                LDAL    KFGX_REST_ANCHOR        ; loader-written rest-of-OS base bank
                BRA     @rb_store
@rb_default     LDA     #REST_BASE_DEFAULT      ; $03 (== old console bank)
@rb_store       STA     _restBaseBank
                REP     #$20
                MX      %00

                ; Phase 2B: derive the cached rest-of-OS region banks from the base
                ; (_restBaseBank + REST_*_OFF).  Done once here, before any console
                ; use, so per-region code loads the dynamic bank not a baked $03-$06.
                LDA     _restBaseBank
                AND     #$00FF
                CLC
                ADC     #REST_FONTS_BANK_OFF
                STA     _kFontsBank             ; pre-expanded fonts (was fixed $04)
                LDA     _restBaseBank
                AND     #$00FF
                CLC
                ADC     #REST_USER_FIRST_OFF
                STA     _kUserFirstBank         ; user-task bank pool floor (was fixed $0A)
                LDA     _restBaseBank
                AND     #$00FF
                CLC
                ADC     #REST_CONSOLE_BANK_OFF
                STA     _kConsoleBank           ; console framebuffers (was fixed $03)
                ; Slice D: VC 0 IS the console, so its registry entry is the
                ; console bank and is never 0 ("unallocated").  Seeding it here
                ; rather than leaving it 0 means the switch and the write path
                ; need no "is this the console?" special case -- VC 0 is just
                ; the one VC whose bank was allocated before the pool existed.
                ; _kVcBank[1..] stay 0 until first WRITE to that line.
                STA     _kVcBank                ; _kVcBank[0] = console bank
                STZ     _kVcActive              ; the console is on screen
                STZ     _kVcFocus               ; ...and has the keyboard
                STZ     _kVcCard                ; no card console yet
                STZ     _kVcSwitchReq           ; no pending switch

                JSR     Kern_LogInit            ; run before any subsystem logs
                JSR     _BootCon_Init           ; patch CoutTramp JSL from
                                                ; loader handoff ($02FF07/08)
                JSR     _JT_Init                ; build $00:032E bank-0 JT gateway
                                                ; (was $02FE00; relocatable kernel)
                JSR     _Sys_InstallVectors     ; COP vector + bank-0 trampoline
                JSR     Bank_Init               ; the user pool's page map
                JSR     Task_Init               ; zero task table; _curTask = 0

                ; Phase 5.2: init tty[0] (the console).  FgPgrp=0 = "no foreground
                ; group set yet" — matches the all-group-0 world before setpgid
                ; (Task 5.3), so the tty read() gate passes for everyone.  MX %00
                ; here (boot runs 16-bit), so each STZ clears a full TTY word.
                ;
                ; pty P1b: FIRST zero the WHOLE table.  A DS region is NOT
                ; guaranteed zero in RAM (the multipass image load leaves stale
                ; buffer bytes; this is why every tty[0] field below is
                ; explicitly initialized, and why _KMem_ClearGlobals exists) —
                ; found the hard way when tty[0].TTY_Backend read $679C at boot
                ; and every discipline read took the pty stub arm.  This also
                ; readies tty[1..NTTY-1] (the pty slaves): all-zero until their
                ; pair opens and installs sgttyb/tchars defaults (P2).
                LDX     #NTTY*TTY_SIZE-2
@ttyz           STZ     _ttyTable,X
                DEX
                DEX
                BPL     @ttyz
                JSR     _Pty_Init               ; pty P2: zero pair state +
                                                ; bake pair->tty linkage

                ; Console tty[0] cooked defaults (sgttyb + tchars + ltchars +
                ; local-mode + empty canonical buffer) — shared routine in
                ; pty.s, X = tty entry offset (0 = console).  The console boots
                ; line-edited + echoing, exactly as before.
                LDX     #0
                JSR     _Tty_CookedDefaults

                JSR     _ConfigureHardware

                ; Far kernel bank: verify KFAR_MAGIC and patch every core->far
                ; JSL operand bank byte.  MUST precede the FIRST cross-bank call,
                ; which is the _KCaptureBootTime line immediately below.  It sat
                ; after Blk_Init originally and the clock move overtook it: the
                ; unpatched JSL kept the assembler's FGX_KFAR_BANK ($08) and
                ; jumped into an unrelated bank, landing in ROM with a blank
                ; screen well before any console existed to report it.
                ;
                ; Far_Init needs only kernel DP and the live bank number -- no
                ; Kmalloc, no filesystem, no console -- so this is safe to run
                ; this early, and earlier is the only correct direction.
                JSR     Far_Init

                ; CLEAR THE TRAP REPORT FIRST, and it must be first: it has
                ; to be zero BEFORE the first guarded prologue can fire, or a
                ; trap that does fire is indistinguishable from whatever the
                ; last run left at these addresses.  A report that cannot be
                ; trusted to be absent is worse than no report -- it invents
                ; the failure it was added to diagnose.  apple/fgx#261.
                ; LDA #0 + STAL, not STZ: the 65816's STZ has no
                ; absolute-LONG mode, and DBR here is the kernel bank, so a
                ; plain `STZ' would zero four words of the kernel bank instead.
                REP     #$30
                MX      %00
                LDA     #0
                STAL    KFGX_TRAP_MAGIC
                STAL    KFGX_TRAP_D
                STAL    KFGX_TRAP_S
                STAL    KFGX_TRAP_FLOOR

                ; ZERO THE KERNEL-C DIRECT PAGE BEFORE ANY KERNEL C RUNS.
                ; Here because the far bank is now callable and _BootScreen --
                ; which reaches guarded C through the console's font load -- is
                ; still 250 lines below.  apple/fgx#225 is what happens when
                ; this is late: see _KcDp_Zero.
                JSR     _KcDp_Zero

                ; ...AND THE INTERRUPT-TIME ONE, for the same reason one line
                ; earlier.  Nothing enters it until T6 arms the heartbeat, but
                ; it is zeroed here rather than at its first use because that is
                ; exactly the mistake apple/fgx#225 was: a page seeded inside a
                ; PROBE, so a kernel built without the probe seeded it not at
                ; all -- and the symptom was a spin with no console to report
                ; it.  Seeding both together is what keeps that from being two
                ; rules.
                JSR     _KcDpIrq_Zero

                ; The TTY kernel bank, brought up the same way Far_Init brings
                ; up the far one and for the same reasons; nothing on the boot
                ; path calls into it yet, so it has no `MUST precede' of its own.
                JSR     Tty_Init                ; the THIRD bank, same mechanism
_kfp020         JSL     KFAR_CAPTURE_BOOTTIME   ; far bank; freeze wall-clock for uptime
                JSR     _DetectHardware         ; populate RAMBanks/RAMSizeKB/
                                                ; ROMVersion/CPUSpeedMHz (silent;
                                                ; Kmem_Init needs RAMBanks).
                JSR     _LC_MapRam              ; per-pid kernel stacks live in
                                                ; language-card RAM; map it
                                                ; before any task can exist

                ;--- LEAVE PAGE 1 FOR GOOD (apple/fgx#185, apple/fgx#172) -----
                ; PAGE 1 BELONGS TO THE FIRMWARE AND THE INTERRUPT HANDLER, and
                ; the boot stack sitting on it is the anomaly, not the rule.
                ; Four sites bounce S there deliberately before an
                ; emulation-mode excursion (block.s, clock.s x2,
                ; boot_console.s), and so does EVERY interrupt, because the
                ; ROM's handler "Switches to emulation mode" going to the
                ; interrupt environment (Apple IIgs Firmware Reference, ch.8)
                ; and emulation mode forces the stack high byte to $01.  No
                ; operand in this tree can move that one.
                ;
                ; While boot ran on page 1 that was a RULE every caller had to
                ; honour -- do not move S off page 1 while a live page-1 frame
                ; is still there to return through -- and apple/fgx#183 was the
                ; bill for it: _Probe_Drive moved to its own stack, the
                ; heartbeat task wrote over mod_init's frame one VBL later, and
                ; the probe returned into FGX_SYSVARS.  Moving here makes the
                ; rule a STATIC PROPERTY instead: from this instruction on,
                ; nothing the kernel returns through is in page 1, so there is
                ; nothing for an excursion to land on.
                ;
                ; IT HAS TO BE HERE.  _LC_MapRam above is what makes $E000
                ; readable, and everything below -- Mod_LoadConf and every
                ; mod_init and probe it drives -- is what needs the depth.  The
                ; boot stack was 256 bytes and the UFS chain alone measures 437.
                ;
                ; NOTHING IS STRANDED.  FGX_Entry is JUMPED to by the loader and
                ; never returns, so the page-1 frames abandoned here belong to
                ; no caller.  And the slot borrowed at the top of
                ; FGX_STK_KTASKS holds no task yet: the scheduler hands slots
                ; out only once tasks exist, so boot's scribble belongs to
                ; nobody until then.
                ; PAINT EVERY SLOT ON THE WAY IN (apple/fgx#195).
                ; Boot is about to run its entire chain -- Mod_LoadConf, every
                ; mod_init, every probe -- on the top slot's stack, and
                ; nothing else ever measures how much of it that takes.
                ; probe_dev.s measures a 768-byte window of it, but only when
                ; ufsprobe.mod is configured in, and only for that one chain.
                ;
                ; THE PAINT GOES DOWN BEFORE THE TCS.  After it, the loop would
                ; be writing over the frames it is standing on: it fills upward
                ; from $E000 and boot's stack grows downward from the top of the
                ; same region.  Here nothing in the slots is live -- no task
                ; exists yet -- and page 1 still holds the frames this returns
                ; through.
                ;
                ; The paint and the bottom-word canaries are laid ONCE, here: a
                ; slot is reused by task after task, so its mark is the deepest
                ; any of them went, which is the number that sizes it, and its
                ; canary is what the dispatcher tests at every syscall entry.
                PHX
                LDX     #0
                LDA     #STK_PAINT
@fe_paintL      STAL    $000000+FGX_STK_KTASKS,X
                INX
                INX
                CPX     #FGX_KSLOT_COUNT*FGX_KSLOT_STK
                BCC     @fe_paintL
                LDX     #0
                LDA     #$C5C5
@fe_canaryL     STAL    $000000+FGX_STK_KTASKS,X ; each slot's bottom word
                TXA
                CLC
                ADC     #FGX_KSLOT_STK
                TAX
                LDA     #$C5C5
                CPX     #FGX_KSLOT_COUNT*FGX_KSLOT_STK
                BCC     @fe_canaryL
                ; THE SCHEDULER'S OWN STACK gets the same paint and the same
                ; bottom-word canary, so kstkhwm_check.py measures it beside
                ; the slices and swtch's @sw_pick has a word to test.  It is
                ; the top of the mapped $D000 bank, which _LC_MapRam mapped
                ; with the rest of the card; nothing has stood on it yet.
                LDX     #0
                LDA     #STK_PAINT
@fe_paintSw     STAL    $000000+FGX_STK_SWITCH,X
                INX
                INX
                CPX     #FGX_STK_SWITCH_SIZE
                BCC     @fe_paintSw
                LDA     #$C5C5
                STAL    $000000+FGX_STK_SWITCH  ; canary at the bottom word
                PLX
                LDA     #FGX_STK_BOOT+FGX_KSLOT_STK-1   ; the top slot's top
                TCS
                JSR     _Shadow_InhibitUnused   ; stop shadowing the display
                                                ; regions FGX never shows
                JSR     _SimInitExitTable       ; cache ROM-gated SIM exit JML
                                                ; cells before any IRQ can be
                                                ; steered through them
                JSR     _DetectAppleTalkPort    ; populate _apTalkPort (= 0
                                                ; under raw-IIgs)
                JSR     Kmem_Init               ; libc-core heap arenas
                JSR     _AllocLogBuf            ; _kLogBufPtr = Kmalloc(KMEM_LOGBUF_SIZE,
                                                ; enables the kernel-log ring (was a
                                                ; static FGX_DATA buffer).  First, so
                                                ; later alloc panics reach the ring.
                ; THE OPEN-FILE TABLE, carved once the heap exists and before
                ; anything opens a file.  Not later: Mod_LoadConf opens files
                ; through _Fcb_Alloc and Mod_LoadConf is what LOADS vfs.mod, so
                ; a table owned by that module would not exist the first time
                ; anything opened a file.  Not earlier: the table is a Kmalloc,
                ; and before Kmem_Init seeds the arenas a Kmalloc grows a heap
                ; arena into a pool bank that Kmem_Init's reset then forgets --
                ; the table kept a whole bank to itself that way.
_kfp903         JSL     KFAR_VFS_FILEINIT       ; slot 31; bank byte patched
                ; ...and it hands back the 24-bit base of the per-process
                ; descriptor arrays, A = offset, X.lo = bank.  The FS layer
                ; reads `struct file' through this rather than calling into the
                ; far bank per syscall -- see _Fcb_FileOf.  Zero here means the
                ; far bank is absent, which _kFarReady already gates.
                STA     _kOfilePool
                SEP     #$20
                MX      %10
                TXA
                STA     _kOfilePool+2
                REP     #$30
                MX      %00

                ; DeskStartUp moved to the loader (stage2.s, after MTStartUp) so the
                ; ROM toolsets come up before the kernel runs (2026-06-14).  Keep the
                ; 16-bit set for the allocator calls below.
                ; SAY WHAT THE MACHINE IS, AND SAY IT FIRST.  This ran after
                ; _BootScreen until now, which put it BELOW the storage
                ; inventory -- Blk_Init and Dev_Init log long before the
                ; console exists, so their lines arrive through the ring replay
                ; and anything logged live lands under them.
                ;
                ; IT CANNOT GO ANY EARLIER THAN THIS LINE.  _DetectHardware
                ; fills the fields back at :362 and moving the call up there
                ; looked right and printed NOTHING: the ring is Kmalloc'd by
                ; _AllocLogBuf immediately above, and until it exists
                ; _kernLogPutByte drops the byte -- the console is not armed
                ; yet either, so the message went nowhere at all.  Measured,
                ; not reasoned about: the summary simply vanished from the log.
                JSR     _LogDetectedHardware
                REP     #$30
                MX      %00
                JSR     _AllocDevTable          ; dev_table_ptr = Kmalloc(512, M_KERN)
                JSR     _AllocProcNameTbl       ; per-task name table (seed [kernel])
                                                ; before the first spawn (init)
                JSR     Blk_Init
                ; THE CONTROLLER, THEN ITS UNITS -- BSD's order, and it is the
                ; CALL order that produces it rather than the log order.
                ;
                ; `blk: ... (dev subtype $FF)' reports what the boot unit
                ; answered to a DIB status, and `Blk_DetectCaps' is what asks:
                ; ahead of that call the line reads `subtype $00', which is BSS
                ; rather than a card answering 0.  So Blk_DetectCaps sits right
                ; after the Blk_Init it requires ("MUST run after Blk_Init,
                ; which fills _busTable[0].BS_Slot" -- its own header), and the
                ; enumeration follows the card whose read path it uses.
                JSR     Blk_DetectCaps          ; pick the read architecture from
                                                ; the bus's $CnFB capability byte
                JSR     _LogBlkCaps             ; ...say which path that was
                JSR     Blk_LogBootDev          ; ...the drive it booted from
                JSR     Dev_Init                ; ...and everything else on it
                JSR     Fs_Init                 ; zero the fs buffers
                JSR     _Chardev_InitBuiltins   ; registers /dev/null
                                                ; (cheap; pure-table write)

                ; THE RAW DISKS, /dev/rsd0..rsd7 (apple/fgx#330).  WITH THE
                ; BUILT-INS, because that is what they are: the driver is
                ; assembled into this bank, so its indices should depend on the
                ; kernel alone.  It sits after _Chardev_InitBuiltins rather than
                ; inside it only because the registry table is Kmalloc'd there,
                ; and after Dev_Init because it walks the device table for the
                ; units that are online.  The built-ins take 0..8 and the raw
                ; disks 9..16; /sbin/modload runs from /etc/rc, so serial.mod
                ; and bpf.mod come after both.  gen.py's DEV_NODES and
                ; RAW_DISK_NODES bake those numbers as inode rdevs, and
                ; the `fsckraw' test is what notices if the order moves: it
                ; opens /dev/rsd1 by NAME, so a shifted registry hands fsck
                ; some other driver and the check cannot read the volume.
                JSR     _RawDisk_Register
                JSR     _AllocModReg            ; _modRegPtr = Kmalloc(96, M_KERN)
                                                ; before any Mod_Register* below
                JSR     _AllocSigHnd            ; _sigHndPtr = Kmalloc(
                                                ;   SIGHND_BLK_SIZE, M_KERN)
                                                ; before any signal syscall/delivery
                JSR     _BlkTab_Init            ; M-1 arena block table (row 0 =
                                                ; boot REST claim) — first real
                                                ; _kHeapCur consumer
                DO      BLKPROBE=1
                JSR     _BlkCache_Probe         ; F2-a cache-core self-test (block
                FIN                             ; segment; cache shares the block too)
                JSR     _AllocIfTable           ; _ifTablePtr = Kmalloc(128, M_KERN)
                                                ; before _ProbeUthernet2 registers ifaces
                JSR     _AllocSockTable         ; _sockTablePtr = Kmalloc(32, M_KERN)
                                                ; before any socket() syscall
                JSR     _AllocPipeTable         ; _pipeTablePtr = Kmalloc(NPIPE*16, M_KERN)
                                                ; before any pipe() syscall
                JSR     _AllocSchedTbl          ; _schedTblPtr = Kmalloc(NPROC*ST_SIZE,
                                                ; M_KERN) before any swtch/sched use

                ; Toolbox state at kernel entry (set up by stage 2 loader):
                ;   - TL/MT started; _GetNewID issued (loader's userID is
                ;     not exposed to us — Toolbox_GetOwnID allocates a
                ;     separate kernel userID below).
                ;   - All FGX-owned banks MM-claimed: kernel image, FGX_DATA,
                ;     FGX_HEAP, CON_CHARBUF, CON_FONTS, KMOD_FIRST/LAST,
                ;     BLK_STAGE, FGX_STK_TASKS, heap arenas $07..$09, user
                ;     banks $0A..$1F.
                ;   - Kernel's bank-0 DP page allocated; D pre-set; address
                ;     cached above into _kFgxDPKernel.
                ; Per-process direct pages (with their stacks, Task_AllocStack)
                ; and the heartbeat are still kernel responsibilities.
                JSR     Toolbox_GetOwnID        ; _GetNewID → _kFgxUserID
                ; (RamDisk_Init MOVED OUT: the /RAM5 driver is ramdisk.mod, and
                ; its mod_init does the detect-or-create when Mod_LoadConf
                ; loads it.)
                JSR     _KernIrq_Install        ; patch $E10010 with our IRQ
                                                ; trampoline (passthrough in
                                                ; phase 1; SCC dispatch later)
                JSR     Toolbox_InstallHB       ; install HB task, enable VBL, CLI

                ; PID 1 task setup.  Must precede any Fs_Open (dispatch
                ; or legacy) because _Fcb_Alloc writes through
                ; [_fd_table_ptr],Y.  Slice 5k moved this ahead of
                ; _BootScreen so the console font load's Fs_Open has a
                ; valid fd table, and so the early module registration below
                ; has one too.  X = TCB offset throughout.
                JSR     Task_Alloc
                BCS     @kern_haveTCB
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_haveTCB   JSR     Task_AllocFdTable
                BCS     @kern_fdOK
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_fdOK      LDA:    TCB_FdTablePtr,X
                STA     _fd_table_ptr
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X
                STA     _fd_table_ptr+2
                REP     #$20
                MX      %00
                ; BOOT IS A PROCESS, AND _curTask NOW SAYS SO.  This is
                ; 4.3BSD-Reno's `u.u_procp = p` (kern/init_main.c:73), which
                ; sets up proc0 before any I/O so that "who am I" always has an
                ; answer.  FGX has had the task since Task_Alloc above -- what
                ; it did not have was a cell reflecting it, so kc_curpid
                ; answered 0 for the whole of boot.
                ;
                ; IT MATTERS BECAUSE FGX DIVERGES FROM RENO TWICE OVER.  Reno
                ; never needs a pid this early: mountroot (init_main.c:175)
                ; mounts the root through VFS internals, and the first open(2)
                ; is in icode, after newproc creates init at :198.  FGX's
                ; Mod_LoadConf opens files through Fs_Open, so the descriptor
                ; layer runs at a point BSD's never does -- and a descriptor
                ; needs an owner.  Answering with the boot task is the honest
                ; answer, not a special case invented for boot.
                LDA:    TCB_TaskID,X
                STA     _curTask

                ; Park the TCB offset so we can recover X after Mod_Load /
                ; _BootScreen / Sound_* / Mod_LoadConf clobber it.
                ;
                ; IN ITS OWN CELL, not in _curTask.  _curTask is the current
                ; PID and kc_curpid hands it to kernel C; borrowing it here
                ; meant that for the whole of module load -- which is where
                ; boot opens its files -- anything asking for the running pid
                ; got a TCB offset.  Nothing consumed it that way YET, which is
                ; the only reason this was survivable.
                STX     _bootTcbSave

                ; Bootstrap-first via pre-staged banks: stage 2 carries the
                ; FGXM bytes inside the kernel image, MVN's them into
                ; successive kmod banks, and writes a zero-terminated list of
                ; those banks at _PreStaged_Banks ($02FF08..$02FF17).  We
                ; iterate the list, registering each module from memory -- this
                ; avoids the Fs_Open-during-bootstrap cycle (the legacy
                ; chicken-and-egg documented in
                ; feedback_fop_legacy_bootstrap_chain).  The first registered
                ;
                ; THERE IS NO FALLBACK: the loop below stops on a zero slot,
                ; and there is no module on disk to load if the list is empty.
                REP     #$20
                MX      %00
                LDX     #0                      ; X = slot index (16-bit)
@kern_psLoop    SEP     #$20
                MX      %10
                LDA     |_PreStaged_Banks,X     ; DBR-rel: kernel bank
                BEQ     @kern_psDone
                REP     #$20
                MX      %00
                AND     #$00FF
                PHX                             ; save loop idx
                JSR     Mod_RegisterPreLoaded   ; announces 'mod: <name> loaded' itself
                BCC     @kern_psFail
                BRA     @kern_psPostReg
@kern_psFail    JSR     _Kern_LogLoadErr        ; log; idx still on stack
@kern_psPostReg PLX                             ; restore loop idx
                INX
                CPX     #MAX_PRESTAGED
                BCC     @kern_psLoop
@kern_psDone    REP     #$20
                MX      %00
                JSR     _BootScreen             ; SHR console + log mirror.
                JSR     _RAM_FloorCheck         ; refuse to run below the floor.
                                                ; AFTER _BootScreen on purpose:
                                                ; everything before it goes to
                                                ; the log ring, which only this
                                                ; call mirrors to the display,
                                                ; so an earlier halt is a BLANK
                                                ; SCREEN -- measured.
                                                ; the font load's Fs_Open
                                                ; now goes through dispatch
                                                ; (or legacy if Mod_Load
                                                ;  above failed).
                JSR     _LogFarBank             ; far kernel bank state
                JSR     _LogTtyBank             ; tty kernel bank state
                JSR     _ClistInit              ; tty bank's clist pool -- NOT a
                                                ;  probe, and not gated: cinit is
                                                ;  what makes getc/putc work
                                                ; (no seam of its own, so its
                                                ;  position does not matter)
                ; The buffer-cache wiring self-test is vfs.mod's own mod_init,
                ; at Mod_LoadConf a few lines down.  What it needs is ENUMERATED
                ; DEVICES (Blk_Init) rather than mounts, and Blk_Init is long
                ; past by then.

_kfp011         JSL     KFAR_SOUND_INIT         ; far bank; configure DOC oscillators 0/1
                ; Boot chime.  It lives in the far bank because Sound_Beep
                ; does.
_kfp012         JSL     KFAR_BOOT_CHIME         ; far bank; gated internally

                ; Boot card scan + W5100 slot-bind, BEFORE Mod_LoadConf so that
                ; net.mod/bpf.mod mod_init self-patch (_W5_PatchSlot) sees the
                ; detected slot in _u2Slot.  _ScanSlots clobbers X; the LDX _curTask
                ; below restores X for the user-task setup.
                JSR     _ScanSlots              ; boot card scan -> _slotTab/_u2Slot
                JSR     _W5_PatchSlot           ; bind kernel U2_* sites to _u2Slot
                                                ; (slot-1 = no-op; self-mod, slotscan B)

                ; Restore X = TCB offset for the user-task setup below.
                LDX     _bootTcbSave

                ; THE INWARD SEAM, brought up once every module is in.  It
                ; lives in the FAR bank -- that is where kernel C and fcc's
                ; runtime are, and the VFSCORE import shims must be entered
                ; from C.  Slot 28 was `bufinit' until the VFS became a module;
                ; it is the kernel-to-VFS call coming back.
                ;
                ; NOT CHECKED HERE: a machine with no vfs.mod in
                ; /etc/modload.conf still boots, and the seam reports itself.
                ;
                ; This call was disabled for a day because it killed the boot
                ; with no output, and the question in the 1.7d RESUME -- "why
                ; is kernel C callable at _KcProbe time and not here?" -- had
                ; a positional answer, not a temporal one: _KcProbe reaches C
                ; through a PATCHED export-slot JSL and an in-bank JMP, while
                ; the seam's far side reached its C with `JSL vfs_seam_check`,
                ; whose bank byte assembles from the far bank's ORG ($08) and
                ; is patched by nothing -- the boot jumped into the bank-$08
                ; heap arena.  Fixed in vfs_seam_entry.s, where the evidence
                ; is written up: the far bank never JSLs a far-bank symbol.
_kfp902         JSL     KFAR_VFS_SEAM           ; slot 28

                ; LOAD BOOT MODULES FROM /etc/modload.conf.  Non-fatal: any
                ; per-line failure sets a yellow border + kern-log entry, but
                ; boot continues so the user can still investigate.
                ;
                ; IT SITS PAST THE VFS SEAM: vfs, ufs and ufsdir are PRE-STAGED,
                ; so the seam does not need this call to have run.  Device
                ; drivers -- serial, pty -- arrive here.
                JSR     Mod_LoadConf

                ; MOUNT THE ROOT.  What this needs is ufs.mod and ufsdir.mod up
                ; -- iget refuses to mint a vnode until the second of them is --
                ; and both are PRE-STAGED, registered by the boot program before
                ; the kernel runs.
                ;
                ; `vfs_mountinit' RUNS FROM root_mount, because root_mount is
                ; what runs on every machine.
                ;
                ; THE RESULT IS NOT LOGGED.  What a log line would say,
                ; `root_mounted' says better: it is far-bank data a test can
                ; read directly, where a message is a claim about one.
                ; ufsboot.json asserts it.
_kfp905         JSL     KFAR_VFS_ROOTMOUNT      ; slot 44; bank byte patched

                ; ROOT ON sd0 -- what BSD says once it has one, and what this
                ; log could not say until the root had a block node to name.
                ;
                ; A IS THE RESULT and it is safe to read here.  root_mount()
                ; returns 0 mounted, -1/-2 refused, and the seam's own no-ufs
                ; arm answers -3 explicitly ("DISTINCT from the C's -1") rather
                ; than falling through with whatever it had -- so zero cannot
                ; be reached by a mount that did not happen.  Anything else
                ; stays SILENT: the boot dies a few lines later with `init load
                ; failed', which says more than a second message here would.
                ;
                ; THE UNIT IS BAKED AND THAT IS NOT A GUESS.  root_mount.c
                ; carries `ROOT_UNIT 0' with the reason -- "THE BOOT DEVICE IS
                ; UNIT 0 AND IS NOT SCANNED FOR.  Blk_Init registers it as
                ; _devTable[0] before any enumeration runs" -- and /dev/sd0 is
                ; the node this tree bakes for that unit.  The two agree by
                ; construction, so the literal is the same fact the mount used.
                CMP     #$0000
                BNE     @rootQuiet
                LDA     #@msg_rooton
                STA     _conStrPtr
                JSR     Kern_LogStr
@rootQuiet      ANOP

                ; THE CLOCK, FROM THE ROOT AND THEN THE BATTERY CLOCK -- 2.11BSD
                ; init_main.c:197 sets `time' here, right after mounting the
                ; root: `time.tv_sec = fs->fs_time; if (toytime = toyclk())
                ; time.tv_sec = toytime;'.  tod_init (tty/kern_time.c) is that,
                ; with root_mount's `_kRootFsTime' as the base, 0 when the root
                ; did not mount.  The heartbeat has been ticking a zeroed clock
                ; until now, and nothing has read it.
                KTTY_KC_ENTER                   ; DBR = tty bank, D = kernel-C
_ktp101         JSL     KTTY_TOD_INIT           ; slot 43: inittodr
                KTTY_KC_LEAVE

                ; AND NOTHING AFTER IT, which is what BSD does: 2.11BSD's
                ; kernel mounts the ROOT and nothing else, everything in
                ; fstab(5) being mount(8)'s from /etc/rc.

                ; Resolve ramdisk.mod's VT_BLOCKDEV vtable and patch the two
                ; dispatch stubs in src/drivers/ramdisk/ramdisk.s, which is what
                ; block.s's EXT call sites reach.  Must be BEFORE the
                ; enumeration below: that is the first thing to ask the device
                ; to read a block, and an unpatched stub answers EIO.
                JSR     _Ram_LoadOpsPtr

                ; Resolve pty.mod's VT_CHARDEV vtable and rewrite the twelve
                ; chardev ops entries + the two syscall.s stub sites in
                ; src/kernel/pty.s.  Order does not matter against the mount
                ; enumeration below (no pty is opened until userland), but it
                ; must be after Mod_LoadConf -- now directly above -- and
                ; before init runs.
                JSR     _Pty_LoadOpsPtr

                ; Resolve vfs.mod's uiomove for the TTY BANK (apple/fgx#108
                ; T3).  This said "must be after Mod_LoadConf -- vfs.mod does
                ; not exist before it"; vfs.mod is pre-staged at UFS 2.4, so
                ; what it actually needs is only to be before the bank's first
                ; read or write, which is what uses uiomove.
                JSR     _Tty_LoadVfsPtr

                ; THE TTY BANK'S DEVICE BINDING, AND IT MOVED HERE FROM
                ; BESIDE the clist init.  Not for what it binds -- tty_devinit reported
                ; five devices at BOTH positions, because it iterates the five
                ; tty SLOTS rather than the device list and the pty chardevs
                ; are core built-ins registered before the loader.  That
                ; hypothesis was measured and wrong.
                ;
                ; It moved because of what it can now CALL.  The bank's seam
                ; reaches uiomove in vfs.mod, and a probe that runs before the
                ; module loader cannot witness a call into a module that is not
                ; there.  Every later increment of T3 needs the same thing.
                ;
                ; WHAT STILL CANNOT BE WITNESSED HERE, so a green probe is not
                ; read as more than it is: anything through the u-area.
                ; Task_AllocUarea below builds INIT's, not one for a process
                ; this code runs as -- boot has no current process -- so
                ; ttread's background-process arm wants a userland test after
                ; linesw[0] repoints.
                ; The lbolt wake, which ttwrite will sleep on.  Here because
                ; every question it asks needs the heartbeat to have been
                ; running for a while, and boot has.  Costs no wait.
                JSR     _LboltProbe

                JSR     _TtyDevInit             ; BIND the devices -- production
                                                ;  init, not a probe, and not
                                                ;  gated; see _TtyDevInit


                ; tty[0]'s SPECIAL CHARACTERS, which could not be set with the
                ; rest of its cooked defaults at :294: they live in the tty bank
                ; since T3 stage 2b, and that bank is not callable until
                ; Tty_Init.  _Tty_CookedDefaults skips its own call while
                ; _kTtyReady is 0, and this is the other end of that pair.
                ;
                ; HERE RATHER THAN BESIDE Tty_Init, and the difference is not
                ; taste: this is the first kernel C the tty bank runs, and
                ; putting it immediately after Tty_Init put it ahead of
                ; _ClistInit -- which wedged the ttyprobe build before a single
                ; character reached the console.  _TtyDevInit is where the
                ; bank's production init already lives.
                ; Its WINDOW SIZE moved to the bank at stage 2c and is here
                ; for the same reason; _Tty_SetWinSz preserves A, so one LDA
                ; serves both.
                ; ...and its MODE WORD and SPEEDS at stage 2d.  The flags
                ; accessor takes a byte OFFSET, which for tty[0] is the same
                ; zero the other two take as an index.
                LDA     #0                      ; tty[0]'s byte offset
                LDX     #SG_ECHO+SG_CRMOD       ; cooked, echoing
                LDY     #L_CRTBS+L_CRTERA+L_CRTKIL
                JSR     _Tty_SetFlagsAt
                LDA     #0                      ; tty[0] -- an INDEX now, not an
                LDX     #CON_VIS_ROWS           ;   offset
                LDY     #CON_VIS_COLS
                JSR     _Tty_SetWinSz
_ktp076         JSL     KTTY_KC_TTYCHARS        ; slot 13, on _KTty_Chars

                ; The interrupt-time kernel-C context (apple/fgx#108 T6).  It
                ; crosses into the tty bank, so it needs Tty_Init (:351) behind
                ; it, and its verdict is a console line.
                ;
                ; ITS POSITION IS LOAD-BEARING AND IT MOVED TWICE FOR THE SAME
                ; KIND OF REASON.  Cases 1 to 5 do not care where they run;
                ; cases 6 to 10 drive the OUTPUT RAIL on tty[0] and therefore
                ; need the line FULLY set up:
                ;   - after `_TtyDevInit', because `kc_ttyinput' resolves the
                ;     line through `tty_byidx', which refuses an UNBOUND one.
                ;     It reported "case 6 got 65535" from one line too early.
                ;   - after `_Tty_Chars', because cases 9 and 10 send `^S' and
                ;     `^Q' and `t_stopc' is ZERO until that call seeds it, so
                ;     `CCEQ' was false and `ttyinput' skipped the stop arm
                ;     entirely.  It reported "case 9 got 0", and the value that
                ;     settled it was `t_stopc' itself, read back through the
                ;     same seam.
                ; BOTH WERE MEASURED, not reasoned, and both look identical
                ; from outside -- a case that fails because the machine is not
                ; ready yet reads exactly like a case that fails because the
                ; code is wrong.  The probe prints the VALUE for that reason.
                JSR     _KcIrqProbe
                ; AFTER _TtyDevInit, which seeds the fields it round-trips,
                ; and before init claims a foreground group.  Under every half
                ; rather than one: the accessors are assembly on both sides, so
                ; no C probe covers them.

                JSR     _Net_LoadOpsPtr         ; resolve net.mod's VT_NET op table
                                                ; (net.mod conf-loaded above); C=0
                                                ; if absent -> ifconfig/socket
                                                ; syscalls return ENOSYS.

                JSR     _Bpf_AllocBlk           ; Kmalloc the /dev/bpf0 capture block +
                                                ; wire _bpfBase/_bpfSnapPtr.  The chardev
                                                ; itself is registered by bpf.mod (loaded
                                                ; via Mod_LoadConf above).  preserves X
                                                ; (TCB below).

                JSR     _ProbeUthernet2         ; networking Phase 0a: detect
                                                ; Uthernet II (W5100); _u2Slot already
                                                ; set by _ScanSlots above.

                ; Re-restore X = TCB offset: Mod_LoadConf / _Net_LoadOpsPtr
                ; CLOBBER X, so the line-418 restore is stale by here.  The
                ; old PHX saved that corpse ($0072), and the whole pid-1
                ; setup below (_ps_childTCB, spawn-parity bookkeeping, the
                ; stack-floor seed, Task_AllocKernStack) ran against a
                ; phantom TCB — the KSTK canary for pid 1 was seeded into
                ; page 0, so the dispatcher's canary check cried DEAD on
                ; every boot since the canary landed.
                LDX     _bootTcbSave
                PHX                                 ; save TCB across Seed +
                                                    ; Bank_Alloc + Load_Binary
                JSR     _Fcb_OpsInit            ; stamp the live bank into the
                                                ;   legacy fileops tables before
                                                ;   any descriptor can be given
                                                ;   one (UFS 1.7d I2c)
                ; NO DESCRIPTORS FOR PID 1: init starts with an empty table,
                ; as 2.11BSD's does (its runcom opens "/" for /etc/rc and a
                ; console user opens /dev/console).
                JSR     Bank_Alloc                  ; A = bank; preserves X
                BCS     @kern_haveBank
                PLX                                 ; drop saved TCB
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_haveBank  ; Load_Binary clobbers X (it wants X = path ptr).  TCB is
                ; still on the stack from the PHX above.
                LDX     #_InitPath
_kfp919         JSL     KFAR_LOAD_BINARY            ; uses A as override
                BCS     @kern_loadOK
                PLX                                 ; drop saved TCB
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_loadOK    PLX                                 ; X = TCB offset
                ; init (pid 1) is launched by boot, not posix_spawn, so it misses
                ; the Task_InheritCwd/Task_SetName that @psp_haveChildFd runs for
                ; normal children.  Do them here: _curTask is still 0, so _fsCwdPtr
                ; points at the kernel's cwd ("/") -> init inherits "/"; name="init".
                PHX
                LDA     #1
                JSR     Task_InheritCwd             ; slot 1 cwd = kernel "/"
                LDX     #_InitPath
                LDA     #1
                JSR     Task_SetName                ; slot 1 name = basename = "init"
                PLX
                STX     _ps_childTCB                ; StageArgs (and our reloads)
                                                    ; read the TCB from here —
                                                    ; same cell spawn uses

                ; --- Spawn-parity post-load bookkeeping (init is a normal
                ; FGX3 C binary since the C rewrite; the boot path lays the
                ; same TCB state the posix_spawn path does, through the same
                ; _Ld_BindText).  DataBank is _Loader_StageArgs's: it persists
                ; the data segment's bank during frame layout. ---
                JSR     _Ld_BindText
                SEP     #$20
                MX      %10
                ; StageArgs reads argv strings via _Sys_CallerBank; the
                ; "caller" of the boot spawn is the kernel itself.
                PHB
                PLA
                STA     _Sys_CallerBank
                STA     _InitArgvBank           ; "init" lives in that bank too
                STA     _InitArgBlkBank         ; and so does the argv vector
                REP     #$20
                MX      %00
_kfp929         LDAL    KFAR_LD_ENTRY                    ; entry offset (low 16)
                STA:     TCB_EntryPoint,X
                LDA     #0
                STA:     TCB_ParentID,X

                ; --- User stack from the header's stack_pages_hint (+ the
                ; argv-frame pages, #45), exactly like posix_spawn — the
                ; hardcoded one-page $3100 stack predates C init. ---
                LDX     #_InitArgBlk
                LDY     _InitArgBlkBank
_kfp930         JSL     KFAR_LOADER_ARGPAGES        ; A = ceil(frame/256)
                PHA
                SEP     #$20
                MX      %10
_kfp931         LDAL    KFAR_LD_HEADER+FGX1_OFF_STACK    ; hint byte
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     @kern_haveHint
                LDA     #1                          ; 0 hint -> 1 default page
@kern_haveHint  CLC
                ADC     1,S                         ; + argv-frame pages
                PLY                                 ; discard pushed word
                LDX     _ps_childTCB
                JSR     Task_AllocStack
                BCS     @kern_stackOK
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_stackOK   ; P3-3: seed init's hardware-stack floor for the fcc prologue
                ; overflow guard (child DP $B9-$BA = StackBase + margin).
                JSR     Uimg_DPPtr                  ; _libcTmp2 -> init's page
                LDA:    TCB_StackBase,X
                CLC
                ADC     #FCC_STK_FLOOR_MARGIN
                LDY     #FCC_STKFLOOR_DP
                STA     [_libcTmp2],Y
                ; INVALIDATE THE ROM'S WARM-START VECTOR.  apple/fgx#120.
                ;
                ; The autostart ROM decides between rebooting and jumping through
                ; SOFTEV ($03F2) by testing SOFTEV+1 EOR #$A5 against the power-up
                ; byte PWREDUP ($03F4) -- GSFirmware/Monitor/autostart.aii.  A
                ; booted Apple II leaves SOFTEV = $E000 with PWREDUP = $45, and
                ; $E0 EOR $A5 = $45, so the pair VALIDATES and Ctrl-Reset jumps to
                ; $E000 instead of rebooting.  On a stock machine $E000 is BASIC
                ; and that is the familiar "Ctrl-Reset drops you into BASIC".
                ; Under FGX it is not BASIC: $E000 is FGX_STK_KTASKS, the per-pid
                ; kernel stacks in the language card, so the ROM jumps into stack
                ; memory.  The screen stays in SHR showing the dead console, which
                ; is why it presents as a hang on a blank blue screen rather than
                ; as a crash.
                ;
                ; Zeroing the check byte makes the test fail, so a reset always
                ; takes the cold path and reboots.  Apple's own diagnostics do
                ; exactly this -- DIAG.ROM.SEQ.aii: `ASL PWREDUP ;Destroy powerup
                ; byte (cold boot if test interrupted)`.
                ;
                ; PLACEMENT IS MEASURED, NOT CHOSEN.  Two earlier sites (kernel
                ; entry, and after _LogBlkCaps) both failed: a watchpoint on $03F4
                ; caught exactly ONE write in a whole run, from ROM $FAB1 at frame
                ; 65 -- the ROM re-establishes the pair during the firmware
                ; bring-up FGX drives, so anything before that is undone.  Here is
                ; after all of it and before init exists.  SOFTEV is left alone: it
                ; is the ROM's cell and the check byte alone decides.
                ; STAL, NOT STZ.  DBR here is the live kernel bank, so a plain
                ; `STZ $03F4` is DBR-relative and lands on KERNELBANK:03F4 --
                ; scribbling kernel memory while leaving the byte it meant to
                ; clear untouched.  Caught by the watchpoint: the log showed the
                ; ROM's write and NOT this one.
                SEP     #$20
                MX      %10
                LDA     #$00
                STAL    $0003F4                 ; PWREDUP, in bank 0
                REP     #$20
                MX      %00

                ; Kernel context: fixed-region kernel stack (can't fail) +
                ; u-area.  spawn allocates these for every child, and pid 1
                ; needs them too -- a NULL SE_UareaPtr is not survivable.
                ; The kernel-image slot tables and the home bank first: init
                ; is the first task to be bound (below), and the bank comes
                ; from the same allocator that just gave init its own.
                JSR     _Slot_Init              ; preserves X
                JSR     Task_AllocKernStack
                JSR     Task_AllocUarea
                BCS     @kern_uareaOK
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_uareaOK
                ; --- argv/envp frame + dispatcher resume frame, laid by the
                ; same _Loader_StageArgs spawn uses (argc=1, argv={"init"},
                ; empty envp).  Returns saved_S; persists the real DataBank. ---
                LDX     _ps_childTCB
                JSR     Task_StkLock            ; B3: the parent is about to write
                                                ; the CHILD's stack (survey case 1)
                LDX     #_InitArgBlk
                LDY     _InitArgBlkBank
_kfp932         JSL     KFAR_LOADER_STAGEARGS
                LDX     _ps_childTCB
                JSR     Task_StkUnlock
                BCS     @kern_argsOK
                JSR     _Kern_LogLoadErr
                JMP     _Kern_Halt
@kern_argsOK    LDX     _ps_childTCB
                STA:     TCB_SavedS,X

                ; The last thing the kernel says before it stops being the thing
                ; on screen.  Everything after this line is init -> getty ->
                ; login -> the shell, all of it reading binaries off the disk,
                ; and on real hardware that is long enough to look like a hang.
                ; Loading the shell takes a while on real hardware, and without
                ; a word it can seem hung.  A boot that is slow
                ; and says so is not the same machine as a boot that is silent.
                PHX                             ; TCB: Kern_LogStr clobbers X
                LDA     #_msg_startshell
                STA     _conStrPtr
                JSR     Kern_LogStr
                PLX

                ; init's kernel image: bind it a slot now, the way swtch does
                ; for every task it picks, because init is launched from here
                ; rather than picked -- its first syscall will find its page
                ; and stack top published in _kCurKDP / _kCurKStkTop.
                JSR     _Slot_Ensure            ; X = init's TCB, preserved
                ; _curTask = pid 1; resume into init via the staged frame:
                ; DP to its MM-allocated page, TCS to saved_S, PLB pulls the
                ; DBR seed (= init's DATA bank), RTL pulls PB:PCH:PCL.
                LDA     #1
                STA     _kCurPid                ; who is running
                ; Page 0's own identity.  It is the template every task's page
                ; is copied from, so it must read back 0.  Nothing runs on it
                ; again until the kernel is taskless, but a stale value here is
                ; read as a pid a long way from this line.
                STZ     _curTask
                STZ    |_kCpState               ; CP_USER: init runs user code
                LDA:    TCB_DirectPage,X
                TCD
                LDA:    TCB_SavedS,X
                TCS
                PLB
                RTL

;------------------------------------------------------------------------------
; Kernel boot-handoff path: the first user process the kernel JMPs into.
;------------------------------------------------------------------------------
@msg_rooton     ASC    'root on sd0',00
_msg_startshell ASC    'spawning init...',00

_InitPath       ASC     '/sbin/init',00
; NULL-terminated argv table of FAR pointers since apple/fgx#303: each entry
; is {offset16, bank, pad}.  The bank cannot be baked -- the Memory Manager
; assigns the kernel bank at boot -- so _InitArgvBank is filled in alongside
; _Sys_CallerBank on the way past.
_InitArgv       DA      _InitArg0                   ; argv[0] offset
_InitArgvBank   DA      0                           ; argv[0] bank + pad
                DA      0,0                         ; NULL terminator

; The boot spawn's arg-block.  Same shape userland passes -- argv then envp, a
; far pointer each -- but it sits in the KERNEL bank rather than on a C stack,
; which is why the seam takes the block's bank in Y instead of assuming 0.
_InitArgBlk     DA      _InitArgv                   ; +0 argv vector offset
_InitArgBlkBank DA      0                           ; +2 argv vector bank + pad
                DA      0,0                         ; +4 envp = NULL
_InitArg0       ASC     'init',00

;------------------------------------------------------------------------------
; Slice-1 halt path: WAI loop.  Used both when loader fails and as the
; final landing pad for SYS_EXIT (T11).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _Sys_Reboot (#116) - reboot(2).  2.11BSD's boot(dev, howto),
; usr/sys/pdp/machdep2.c:377, less the parts that name machinery FGX has not
; got:
;
;       if ((howto&RB_NOSYNC)==0 && waittime < 0 && bfreelist[0].b_forw) {
;               ...  xumount(NODEV);  sync();
;               for (iter = 0; iter < 20; iter++) { count B_BUSY; delay(...); }
;       }
;       (void) _splhigh();
;       if (howto & RB_HALT) { printf("halting\n"); halt(); }
;       else { if (howto & RB_DUMP) ... ; doboot(dev, howto); }
;
; NOT PORTED, each for its own reason.  The BUSY-BUFFER SPIN waits for i/o
; already in flight to a disk that reports completion asynchronously; FGX's
; block layer is synchronous, so sync() returning IS the drain.  RB_DUMP has no
; dump device.  xumount(NODEV) releases inodes held by shared text images, which
; is a PDP-11 overlay concept with no counterpart here.  The root superblock's
; `fs_fmod = 1' is skipped too: upstream sets it so the volume's date is fresh
; after the reboot, and ufs_mountfs already marks a writable mount modified, so
; the next sync writes it anyway.
;
; THE ORDER IS UPSTREAM'S AND IT MATTERS: sync BEFORE masking interrupts.  The
; sync walks the mount list and the block layer, and both can block; doing it
; with interrupts off would hang the machine instead of rebooting it.
;
; SUPER USER ONLY, which is upstream's whole body: `if (suser())
; boot(rootdev, ((struct a *)u.u_ap)->opt);' (usr/sys/sys/kern_xxx.c:23).
; Without it any process can halt the machine.
;
; THE CHECK IS FIRST, BEFORE THE SYNC, because a refused reboot must have no
; effect at all -- syncing and then declining would still have written the
; volume out on an unprivileged caller's say-so.
;
; In:  A = howto (RB_*, include/kernel.s).
; Out: DOES NOT RETURN -- except to a non-root caller, which gets C=0, A=EPERM.
;------------------------------------------------------------------------------
_Sys_Reboot     MX      %00
                PHA                             ; howto; _Suser clobbers A
                JSR     _Suser
                PLA
                BCS     @rb_priv
                LDA     #EPERM
                CLC
                RTS                             ; the one path that DOES return
@rb_priv        STA     _rbHowto
                AND     #RB_NOSYNC
                BNE     @rb_nosync
                ; THE SHUTDOWN SYNC, not the ordinary one.  2.11BSD's boot()
                ; calls sync() and update #456 adds fsclean() beside it, which
                ; leaves every writable mount that was clean at mount MARKED
                ; clean.  That is the difference between a reboot and a crash:
                ; without it every deliberate restart leaves the root looking
                ; exactly like a machine that lost power, and the next boot
                ; pays for a check it does not need.
                JSR     Fs_SyncAll              ; the descriptors, per task
_kfp994         JSL     KFAR_VFS_SYNCCLEAN      ; the mounts, marked clean
@rb_nosync      SEI
                LDA     _rbHowto
                AND     #RB_HALT
                BNE     _Kern_Halt              ; upstream's `halt()'
                ; fall through to doboot

;------------------------------------------------------------------------------
; _Kern_Doboot - the machine-dependent half of reboot(2): a IIgs cold start.
;
; PWRUP IS THE PRIMITIVE, not the Apple II power-up-byte trick.  The Firmware
; Reference's Appendix C, Firmware Entry Points in Bank $00, gives three:
;
;       $FA62  RESET   hardware reset handler, called by the 65C816 reset
;                      vector in $FFFC/$FFFD.  Chooses warm or cold and exits
;                      through the user vectors at $03F2/$03F3 on a warm start.
;       $FAA6  PWRUP   "System cold-start routine.  PWRUP performs a partial
;                      system reset and then attempts to start the system via a
;                      disk drive or AppleTalk.  PWRUP also zeros out memory in
;                      bank 00 from address $0800-$BFFF."
;       $FABA  SLOOP   the disk-controller search loop PWRUP ends in.
;
; So $03F2/$03F3/$03F4 are how RESET DECIDES; entering PWRUP is the decision
; already made, and nothing has to be poked to force it.  What PWRUP then does
; is the whole cold-start sequence (Firmware Reference ch.8): video up, keyboard
; as input, the clock chip read into firmware RAM, the system set to match, the
; power-up byte set so the NEXT reset is a warm start, and the startup-device
; scan.
;
; THE ENTRY CONDITIONS ARE NOT ADVICE.  The same page: "If a program JMPs here,
; it must enter in emulation mode, with the direct-page register set to $0000,
; the data bank register set to $00, and the program bank register set to $00,
; or RESET will not work."  JML supplies the program bank; the other three are
; below.  Interrupts are already masked by the caller and stay masked -- PWRUP
; re-enables them when it has its own handlers back.
;
; AND THE ROM HAS TO BE THERE, which is the condition the manual does not state
; because on a machine running the firmware it is always true.  It is not true
; here: FGX runs with the LANGUAGE CARD SELECTED FOR RAM and keeps live state in
; that RAM -- the IRQ kernel-C direct page at bank 0 $FA00 and its stack at
; $FB00-$FCFF (check_bank0_geometry.py prints both).  So $00FAA6 is FGX's own
; interrupt scratch, not PWRUP, and jumping to it executes whatever the last
; interrupt left behind.
;
; MEASURED, because it fails in the shape that hides it: the machine did not
; fault.  It wedged with PC in bank $7C and E still 0 -- so the XCE HAD run and
; the jump HAD been taken, to an address that simply was not the Monitor.  The
; screen kept FGX's last frame because the firmware never got far enough to
; reinitialise the display, which reads exactly like "the reboot did nothing".
;
; Reading $C082 selects ROM for reads across $D000-$FFFF, which is the state the
; firmware entry points assume.
;
; Does not return.
;------------------------------------------------------------------------------
_Kern_Doboot    MX      %00
                SEI
                ; Kern_LogStr for the same bank reason _Kern_Halt gives: this
                ; string is core-bank, and Con_WriteBuf reads through the far
                ; bank's DBR.
                LDA     #_K_bootMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                REP     #$30
                MX      %00
                LDA     #$0000
                TCD                             ; D = $0000
                SEP     #$30
                MX      %11
                LDAL    $00C082                 ; language card -> READ ROM, and
                                                ;   only now is $00FAA6 PWRUP
                LDA     #$00
                PHA
                PLB                             ; DBR = $00
                SEC
                XCE                             ; emulation mode
                JML     $00FAA6                 ; PWRUP -- K = $00, no return

_K_bootMsg      ASC     $0A,'[ rebooting ]',00
_rbHowto        DA      0

_Kern_Halt      MX      %00
                ; Print "[ system halted ]" once, through Kern_LogStr.
                ; Re-entering _Kern_Halt is harmless — _kern_halt_done
                ; gates the print so we don't spam if WAI is interrupted.
                ;
                ; KERN_LOGSTR, NOT KFAR_CON_WRITEBUF, AND THE BANK IS WHY.
                ; Con_WriteBuf takes "_conStrPtr = ptr (bank $02 via DBR)"
                ; (far/console/console_vt.s) and the seam wrapper _fw_Con_WriteBuf
                ; does PHK/PLB before the JSR, so `LDA (_conStrPtr),Y' reads the
                ; FAR bank.  This message lives in the CORE bank, so that call
                ; printed the far bank's bytes at the same offset -- and a $0D
                ; among them put the cursor back at column 0, so it also ate the
                ; start of whatever line was already there.  Kern_LogStr reads
                ; with the caller's DBR and is the path every other core message
                ; takes; it reaches the console through _kernLogPutByte, which
                ; sets its own DBR and expands the trailing LF to CR+LF.
                LDA     _kern_halt_done
                AND     #$00FF
                BNE     @kh_loop
                LDA     #1
                STA     _kern_halt_done
                LDA     #_K_haltMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
@kh_loop        WAI
                BRA     @kh_loop

_kern_halt_done DA      0
_K_haltMsg      ASC     $0A,'[ system halted ]',00

;------------------------------------------------------------------------------
; Slice-1 stub: log "hello load failed: errno=$NN\n" via the kernel log.
; A holds errno on entry.
;------------------------------------------------------------------------------
; NINE SITES REACHED THIS AND ALL NINE PRINTED THE SAME SENTENCE, so a failed
; boot said an errno and not which step produced it.  _kLoadStage is a letter
; the caller sets first; it costs one byte of message and turns "errno=$07"
; into something that names the step.  Letters are assigned where they are set.
_Kern_LogLoadErr MX     %00
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _shTmp0                 ; preserve errno
                LDA     #_LoadErrMsg
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_kLoadStage            ; a one-character STRING: there
                STA     _conStrPtr              ;   is no Kern_LogChar
                JSR     Kern_LogStrNoEOL
                LDA     #_LoadErrMsg2
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _shTmp0
                JSR     Kern_LogHex8
                JSR     Kern_LogEOL
                PLP
                RTS

_kLoadStage     ASC     '?',00          ; letter naming the step that failed
_LoadErrMsg     ASC     'init load failed at ',00
_LoadErrMsg2    ASC     ': errno=$',00

;=============================================================================
; _KZeroRegion - zero [start, start+count) in the LIVE kernel bank.  Reloc-safe
; backend for the _ZeroBankRegion macro (include/macros.s), whose old inline
; `MVN $02,$02` baked bank $02.  Under relocation the kernel-bank statics live
; at the dynamic kernel bank (e.g. $20), so that MVN zeroed a DEAD $02 bank and
; left the real statics UNINITIALIZED.  MAME hid this (it zero-fills RAM at
; reset); real hardware boots with garbage RAM, so chardev _chardev_count, the
; keyboard ring _kKbdRing, FS + console state, etc. were garbage -> chardev
; registration FAILED, dead keyboard.  Self-modifies the MVN bank bytes from
; KFGX_ANCHOR (the live kernel bank), mirroring block.s _SP_ReadBlock.
;
; In:  MX %00.  X = region start (16-bit bank offset).  A = byte count (>= 2).
; Out: region zeroed.  A/X/Y clobbered; DBR = live kernel bank (MVN dest); the
;      caller's MX is restored.  Matches the old macro's post-state.
;=============================================================================
_KZeroRegion    PHP
                REP     #$30
                MX      %00
                PHX                             ; save start (MVN source)
                PHA                             ; save count
                SEP     #$20
                MX      %10
                LDAL    KFGX_ANCHOR             ; live kernel bank ($20 reloc / $02 legacy)
                STA     @kzr_mvn+1              ; patch MVN dest bank byte
                STA     @kzr_mvn+2              ; patch MVN source bank byte
                PHA
                PLB                             ; DBR = live kernel bank (for the STZ)
                STZ:    $0000,X                 ; zero first byte (force-abs; X = start)
                REP     #$30
                MX      %00
                PLA                             ; A = count
                DEC
                DEC                             ; MVN moves A+1 = count-1 bytes
                PLX                             ; X = start (MVN source)
                TXY
                INY                             ; Y = start+1 (MVN dest) -> propagate the 0
@kzr_mvn        MVN     $00,$00                 ; banks patched above; leaves DBR = live bank
                PLP
                RTS

;=============================================================================
; _KMem_ClearGlobals - zero the KMem_KGlobals region.
; Per memmap.s discipline: main owns the kernel-globals region; zero it
; before any subsystem writes to DetectedROM / RAMSizeKB / etc.
;=============================================================================
_KMem_ClearGlobals
                PHP
                REP     #$30
                MX      %00
                ; Call _KZeroRegion directly (NOT the _ZeroBankRegion macro) so
                ; this region is zeroed in the LIVE kernel bank.  The macro's
                ; baked MVN $02,$02 is a no-op under relocation, which is harmless
                ; for the FS/console regions (they are populated before use) but
                ; FATAL here: _chardev_count, the _kKbdRing keyboard ring, the SIM
                ; tables etc. are zero-init-then-incremented, so on real hardware
                ; (garbage RAM, unlike MAME) they were garbage -> chardev
                ; registration FAILED + dead keyboard.  This runs first at boot,
                ; before anything populates the region, so zeroing it is safe.
                ; START AT THE REGION START, not at DetectedROM.  LastExitStatus
                ; and _taskAllocCur are the first four bytes of the region and
                ; were being SKIPPED -- they were prepended to memmap.s after this
                ; zeroer was written, and the start address did not follow them.
                ; FGX_DATA is a DUM section with no image bytes, so nothing else
                ; writes them either: on a warm boot they hold the last run's
                ; values, and _taskAllocCur is Task_Alloc's round-robin cursor.
                ; Its own declaration says "Zero-init => first alloc = slot 0
                ; (init must be pid 1)".  Non-zero, init gets some other slot and
                ; is not pid 1, while the boot path hardcodes _kCurPid = 1 -- so
                ; pid 1's kernel DP page is never seeded and its identity cell
                ; still reads the boot loader.  That is apple/fgx#120: warm boot
                ; only, device-independent, and tracking DRAM retention exactly as
                ; measured on hardware (it survives a power cut under ~10 s).
                ;
                ; A cold boot escapes because garbage >= NPROC wraps to slot 0
                ; (task.s Task_Alloc) -- only a value in 1..NPROC-1 misallocates,
                ; and that is precisely what a real run leaves behind.
                ;
                ; Use the region start symbol so a future prepended cell cannot
                ; reintroduce this.
                LDX     #LastExitStatus&$FFFF
                LDA     #KMem_KGlobals_end-LastExitStatus
                JSR     _KZeroRegion
                PLP
                RTS

;=============================================================================
; _RelocPatchWaveE - boot self-mod for the 41 Wave-E baked-$02 long-op sites.
; These STAL/LDAL (modload VTDR walk = DBR module-bank; the _Sys_Deliver* group
; read in the syscall dispatcher's USER-bank exit path; jumptable's _cdRegIdx at
; DBR=caller-bank) DELIBERATELY use long addressing because DBR != kernel bank,
; so they can't be converted to DBR-rel.  Instead we overwrite each baked $02
; operand BANK byte with the live kernel bank, ONCE at boot, so the long ops reach
; live kernel data regardless of the runtime DBR.  _WaveEBankPatchTbl (generated:
; wavee_bankpatch.s) lists each operand bank byte's in-kernel-bank offset
; (operand+3).  No-op when the live kernel bank == $02 (the static default).
; Entry: DBR already = kernel bank (FGX_Entry PHK/PLB).  Preserves MX/flags (PHP).
;=============================================================================
_RelocPatchWaveE
                PHP
                _DBRK                           ; DBR = live kernel bank (table reads + abs,X writes)
                REP     #$30
                MX      %00
                LDY     #0
@rpwe_L         LDX     _WaveEBankPatchTbl,Y    ; X = in-bank offset of an operand bank byte
                SEP     #$20
                MX      %10
                _BANKK                          ; A.lo = live kernel bank (PHK/PLA; X preserved)
                STA:    $0000,X                 ; overwrite the baked $02 (DBR=kernel : offset)
                REP     #$30
                MX      %00
                INY
                INY
                CPY     #_WaveEBankPatchBytes
                BCC     @rpwe_L
                PLP
                RTS

;=============================================================================
; _KMem_WriteCanaries - write $A5 to every canary byte defined in memmap.s.
; Called once at boot, before any subsystem Init that might overrun.  A canary
; declared and not stamped here fails the build (tools/check_canaries.py), and
; the smoke test reads every one of them back.
;=============================================================================
_KMem_WriteCanaries
                PHP
                SEP     #$20
                LDA     #$A5
                STA    |KMem_KGlobals_canary
                ; ConVtState / ConExpand / FontHdrBuf / ConAltSave canaries moved
                ; to the far bank with their regions -- Far_BankInit seeds them,
                ; running with DBR = far bank and before Con_Init can overrun any
                ; of them.
                STA    |KMem_kernLog_canary
                STA    |KMem_fsDirBuf_canary
                STA    |KMem_fsStatBuf_canary
                STA    |KMem_fsLastDirInfo_canary
                STA    |KMem_fsCwd_canary
                STA    |KMem_busTable_canary
                STA    |KMem_diskStates_canary
                STA    |KMem_Coremap_canary
                STA    |KMem_CurFontName_canary
                STA    |KMem_Arenas_canary
                STA    |KMem_TypeStats_canary
                STA    |KMem_PfArgs_canary
                STA    |KMem_PfNumBuf_canary
                STA    |KMem_AlarmTicks_canary
                STA    |KMem_AlarmReload_canary
                STA    |KMem_NetOps_canary
                STA    |KMem_fw_canary
                STA    |KMem_fls_canary
                STA    |KMem_frn_canary
                PLP
                RTS


;==============================================================================
; Safety fallback: if _Shell ever RTSes, park here.
;==============================================================================
_Halt
                WAI
                BRA     _Halt

;==============================================================================
; _AllocDevTable - Kmalloc(32 * DEV_SIZE = 512, M_KERN), populate
; dev_table_ptr (DP).  Must run before Blk_Init (which writes _devTable[0]).
;==============================================================================
_AllocDevTable
                MX      %00
                PHP
                REP     #$30
                LDA     #FS_MAX_DEVICES*DEV_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @adt_ok
                LDA     #_panic_msg_devtbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@adt_ok         LDA     _kmallocResult
                STA     dev_table_ptr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     dev_table_ptr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the table so empty slots read DEV_Class = 0.
                ; Inline long-store loop: the heap allocation lives in a dynamic
                ; bank, addressed via the long [dev_table_ptr] pointer.
                LDY     #0
                SEP     #$20
                LDA     #0
@adt_zL         STA     [dev_table_ptr],Y
                INY
                CPY     #FS_MAX_DEVICES*DEV_SIZE
                BCC     @adt_zL
                REP     #$20
                PLP
                RTS

_panic_msg_devtbl ASC   'PANIC: cannot alloc devTable',00

;==============================================================================
; _AllocModReg - Kmalloc(MOD_REG_BLK_SIZE=96, M_KERN), populate _modRegPtr (DP).
; Must run before any Mod_Register* writes the registry (after Kmem_Init).
;==============================================================================
_AllocModReg
                MX      %00
                PHP
                REP     #$30
                LDA     #MOD_REG_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @amr_ok
                LDA     #_panic_msg_modreg
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@amr_ok         LDA     _kmallocResult
                STA     _modRegPtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _modRegPtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the registry so empty slots read MOD_REG_E_VTYPE = 0.
                LDY     #0
                SEP     #$20
                LDA     #0
@amr_zL         STA     [_modRegPtr],Y
                INY
                CPY     #MOD_REG_BLK_SIZE
                BCC     @amr_zL
                REP     #$20
                PLP
                RTS

_panic_msg_modreg ASC   'PANIC: cannot alloc modReg',00

;==============================================================================
; _AllocSigHnd - Kmalloc(SIGHND_BLK_SIZE, M_KERN), populate _sigHndPtr (DP).
; Holds the per-task handler tables + the mask/IGN tables (soft-global;
; signal.s).  Size is symbolic: adding a signal table in memmap.s grows the
; allocation and the zero loop below with no edit here.
; Must run before any SYS_SIGNAL set or _Sys_CheckSignal delivery (i.e. before
; the first userland task) — placed in the boot sequence after Kmem_Init.
;==============================================================================
_AllocSigHnd
                MX      %00
                PHP
                REP     #$30
                LDA     #SIGHND_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @ash_ok
                LDA     #_panic_msg_sighnd
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@ash_ok         LDA     _kmallocResult
                STA     _sigHndPtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _sigHndPtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero both tables so every disposition reads SIG_DFL (= 0).
                LDY     #0
                SEP     #$20
                LDA     #0
@ash_zL         STA     [_sigHndPtr],Y
                INY
                CPY     #SIGHND_BLK_SIZE
                BCC     @ash_zL
                REP     #$20
                PLP
                RTS

_panic_msg_sighnd ASC   'PANIC: cannot alloc sigHnd',00
_panic_msg_blktab ASC   'PANIC: cannot alloc blkTab',00

;------------------------------------------------------------------------------
; _BlkTab_Init - Kmalloc the arena block table (BLKTAB_ROWS rows x 8 B, with
; the block cache behind it in the same block), publish its base in
; _kBlkTabBase (bank-\$02 static), and write row 0 = the boot REST claim
; {base=_restBaseBank, count=_kRestBanks, kind=1, handle=0}.
; Heap-resident by design (train-2 M-1): the \$02FE00 globals ceiling is full,
; and this is the first real consumer of the KHEAP_USE/_kHeapCur DP-relief
; pattern (bank-\$02 base static + shared cursor, no dedicated DP slot).
;------------------------------------------------------------------------------
_BlkTab_Init    MX      %00
                PHP
                REP     #$30
                LDA     #BLKCACHE_OFF+BLKCACHE_TOTAL ; one block, two tenants
                                                ; (KGlobals ceiling): block table
                                                ; BLKTAB_ROWS x 8 B (M-3 kind=3
                                                ; grants spill into it) + F2
                                                ; block cache at +BLKCACHE_OFF
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @bt_ok
                LDA     #_panic_msg_blktab
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@bt_ok          LDA     _kmallocResult
                STA     _kBlkTabBase
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _kBlkTabBase+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                KHEAP_USE _kBlkTabBase          ; cursor -> table (M=16 in/out)
                ; Zero the metadata regions (Kmalloc doesn't zero): block-table
                ; handle fields must read 0 = "no MM handle", the inode table
                ; must read INODE_Count=0 = all free, and the cache headers +
                ; scratch must read BCH_Flags=0 = all invalid.  The 8 KB of
                ; cache BUFFERS stays garbage — invalid headers guard it.
                ; Then write block-table row 0.
                SEP     #$20
                LDY     #0
                LDA     #0
@bt_zL          STA     [_kHeapCur],Y
                INY
                CPY     #BLKCACHE_OFF+BLKCACHE_BUFOFF
                BCC     @bt_zL
                LDY     #0
                LDA     _restBaseBank
                STA     [_kHeapCur],Y           ; row0.base
                INY
                LDAL    KFGX_REST_COUNT         ; row0.count = loader's CLAIMED
                BNE     @bt_cntOK               ; count (small-RAM clamp aware);
                LDA     #RESTOFOS_BANKS         ; 0 = legacy loader → constant
@bt_cntOK       STA     [_kHeapCur],Y
                INY
                LDA     #1
                STA     [_kHeapCur],Y           ; row0.kind = boot claim
                STA     _kBlkCount              ; 1 live row
                REP     #$20
                ; Row-0 MM HANDLE (M-4 accounting): the loader's REST-claim
                ; NewHandle result, handed off at KFGX_REST_HANDLE.  Gated on
                ; a valid count anchor — a legacy loader wrote neither, and
                ; bank-0 $0306 would be garbage.
                LDAL    KFGX_REST_COUNT
                AND     #$00FF
                BEQ     @bt_noHnd
                LDY     #4
                LDAL    KFGX_REST_HANDLE
                STA     [_kHeapCur],Y           ; row0.handle lo16
                LDY     #6
                LDAL    KFGX_REST_HANDLE+2
                STA     [_kHeapCur],Y           ; row0.handle hi16
@bt_noHnd       PLP
                RTS

;==============================================================================
; _AllocIfTable - Kmalloc(IFNET_BLK_SIZE=128, M_KERN), populate _ifTablePtr (DP).
; Holds the network interface table (soft-global; ifconfig_sys.s).  Must run
; before _ProbeUthernet2 registers any interface (after Kmem_Init at boot).
;==============================================================================
_AllocIfTable
                MX      %00
                PHP
                REP     #$30
                LDA     #IFNET_BLK_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @ait_ok
                LDA     #_panic_msg_iftbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@ait_ok         LDA     _kmallocResult
                STA     _ifTablePtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _ifTablePtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the table so empty records read IF_Name[0] = 0.
                LDY     #0
                SEP     #$20
                LDA     #0
@ait_zL         STA     [_ifTablePtr],Y
                INY
                CPY     #IFNET_BLK_SIZE
                BCC     @ait_zL
                REP     #$20
                PLP
                RTS

_panic_msg_iftbl ASC    'PANIC: cannot alloc ifTable',00

;==============================================================================
; _AllocLogBuf - Kmalloc(KMEM_LOGBUF_SIZE, M_KERN), populate _kLogBufPtr
; (DP).  Holds the kernel-log ring buffer, moved out of static FGX_DATA in the
; bank-reclaim push so FGX_DATA can shrink and the code ceiling can rise.  Runs
; right after Kmem_Init; until it does, _kernLogPutByte skips the ring (mirror
; only).  Zeroed so a fresh ring reads clean.
;==============================================================================
_AllocLogBuf
                MX      %00
                PHP
                REP     #$30
                LDA     #KMEM_LOGBUF_SIZE
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @alb_ok
                LDA     #_panic_msg_logbuf
                STA     _conStrPtr
                JSR     Kern_LogStr             ; mirror-only here (ring still null)
                JMP     _Halt
@alb_ok         LDA     _kmallocResult
                STA     _kLogBufPtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _kLogBufPtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the ring buffer.
                LDY     #0
                SEP     #$20
                LDA     #0
@alb_zL         STA     [_kLogBufPtr],Y
                INY
                CPY     #KMEM_LOGBUF_SIZE
                BCC     @alb_zL
                REP     #$20
                PLP
                RTS

_panic_msg_logbuf ASC   'PANIC: cannot alloc logBuf',00

;==============================================================================
; _LogBlkCaps - report the boot bus's block-read architecture.
;
; Multi-block reads are used only when the storage device supports them, so
; both pathways exist and the correct one is selected per device.  This is the
; visible half of that: the choice is made in
; Blk_DetectCaps from $CnFB bit 7 AND the device's DIB subtype bit 7, and
; printed here so a boot log always says which path is live rather than leaving
; it to be inferred from timing.
;
; The subtype byte goes out with it because apple/fgx#119 was diagnosed from a
; FloppyEmu's OLED and nothing else.  On a machine that will not boot, the boot
; log is the only instrument there is, and which of the two gates refused is the
; whole question.  $FF means no device was consulted -- either none answered a
; DIB status, or the interface gate refused before the device was asked.
;==============================================================================
_LogBlkCaps
                MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                JSR     Blk_CapsFlags           ; A.lo = BS_Flags
                AND     #BS_FLAG_EXT
                REP     #$30
                MX      %00
                BEQ     @lbc_std
                LDA     #_msg_blkcaps_ext
                BRA     @lbc_emit
@lbc_std        LDA     #_msg_blkcaps_std
@lbc_emit       STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     #_msg_blkcaps_sub
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                SEP     #$20
                MX      %10
                JSR     Blk_DibSubtype          ; A.lo = DIB subtype
                JSR     Kern_LogHex8
                REP     #$20
                MX      %00
                LDA     #_msg_blkcaps_end
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL        ; the ')' -- opened at
                JSR     Kern_LogEOL             ; _msg_blkcaps_sub and never closed
                PLP
                RTS

_msg_blkcaps_ext ASC    'blk: extended SmartPort - multi-block read path',00
_msg_blkcaps_std ASC    'blk: standard SmartPort - single-block read path',00
_msg_blkcaps_sub ASC    ' (dev subtype $',00
_msg_blkcaps_end ASC    ')',00


;==============================================================================
; _AllocSchedTbl - Kmalloc(TASK_MAX_SLOTS * ST_SIZE, M_KERN), populate
; _schedTblPtr (DP).  Holds per-task scheduler state (kernel SP, kernel-stack
; handle, u-area ptr, wait channel, pgroup, flags) — see include/kernel.s
; ST_* layout.  Must run before any swtch / sleep / wakeup (i.e. before the
; scheduler is wired in); placed after Kmem_Init at boot.  Zeroed so every
; slot reads ST_Flags=0 / ST_WaitChan=0 / ST_KernStkHandle=0.
;==============================================================================
_AllocSchedTbl
                MX      %00
                PHP
                REP     #$30
                LDA     #{TASK_MAX_SLOTS*SE_SIZE}
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @asc_ok
                LDA     #_panic_msg_schedtbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@asc_ok         LDA     _kmallocResult
                STA     _schedTblPtr
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _schedTblPtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr   ; always-on: panic if not in heap
                ; Zero the whole table.
                LDY     #0
                SEP     #$20
                LDA     #0
@asc_zL         STA     [_schedTblPtr],Y
                INY
                CPY     #{TASK_MAX_SLOTS*SE_SIZE}
                BCC     @asc_zL
                REP     #$20
                STZ     _nTimerSleepers         ; no nanosleep timers pending yet
                PLP
                RTS

_panic_msg_schedtbl ASC 'PANIC: cannot alloc schedTbl',00

;==============================================================================
; _AllocProcNameTbl - Kmalloc((NPROC+1)*PROC_NAME_MAX, M_KERN) -> _procNameTblPtr
; (bank-$02 static).  Zeroes the table, seeds slot 0 = "[kernel]".  Uses _kCopyPtr
; (DP) as the [dp],Y cursor (points at slot 0 = base).
;==============================================================================
_AllocProcNameTbl
                MX      %00
                PHP
                REP     #$30
                LDA     #NAME_TBL_BYTES
                LDX     #M_KERN
                JSR     Kmalloc
                BCS     @apn_ok
                LDA     #_panic_msg_nametbl
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@apn_ok         LDA     _kmallocResult
                STA     _procNameTblPtr
                STA     _kCopyPtr               ; DP cursor = base (slot 0)
                SEP     #$20
                LDA     _kmallocResult+2
                STA     _procNameTblPtr+2
                STA     _kCopyPtr+2
                REP     #$20
                JSR     _SoftGlob_ValidatePtr
                ; Zero the whole table via [_kCopyPtr],Y.
                LDY     #0
                SEP     #$20
                LDA     #0
@apn_zL         STA     [_kCopyPtr],Y
                INY
                CPY     #NAME_TBL_BYTES
                BCC     @apn_zL
                ; Seed slot 0 = "[kernel]" (M=8; _kCopyPtr still points at slot 0).
                LDY     #0
@apn_seedL      LDA     _kernel_name_str,Y      ; kernel-bank string (DBR=kernel-bank at boot; $02 = assembly ORG)
                STA     [_kCopyPtr],Y
                BEQ     @apn_seedDone           ; copied the NUL (Z from the LDA)
                INY
                CPY     #PROC_NAME_MAX-1
                BCC     @apn_seedL
                LDA     #0
                STA     [_kCopyPtr],Y           ; force NUL at the cap
@apn_seedDone   REP     #$20
                PLP
                RTS

_panic_msg_nametbl ASC 'PANIC: cannot alloc nameTbl',00
_kernel_name_str   ASC '[kernel]',00

;==============================================================================
; HARDWARE CONFIGURATION
;==============================================================================

;=============================================================================
; _ConfigureHardware - Set up IIgs for native FGX operation
;-----------------------------------------------------------------------------
; Configures:
;   - Fast mode (2.8+ MHz)
;   - Disable IIe shadowing
;   - Enable SHR graphics
;=============================================================================
_ConfigureHardware
                ;-----------------------------------------
                ; Set fast mode
                ; Note: I/O registers use bank $E0 for reliable native-mode access
                ;-----------------------------------------
                SEP     #$20            ; 8-bit accumulator

                ; Configure STATEREG: clear RAMWRT/RAMRD for proper memory mapping
                LDAL    HW_STATEREG
                AND     #$CF            ; Clear bits 4,5 (RAMWRT, RAMRD)
                STAL    HW_STATEREG

                ; Set CYAREG: fast mode, no shadow-all
                LDAL    HW_CYAREG
                ORA     #CYA_FAST
                AND     #$EF
                STAL    HW_CYAREG

                ; Enable SHR shadowing (clear bit 3 of SHADOW register)
                LDAL    HW_SHADOW
                AND     #$F7
                STAL    HW_SHADOW

                ; Enable Super HiRes
                LDA     #$81
                STAL    HW_NEWVIDEO

                ; Disable IIe display modes (read to toggle soft switches)
                LDAL    HW_TEXT_OFF
                LDAL    HW_MIXED_OFF
                LDAL    HW_HIRES
                LDAL    HW_PAGE1

                REP     #$20
                MX      %00
                LDA     #@cfg_cpuMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                LDA     #@cfg_shadowMsg
                STA     _conStrPtr
                JSR     Kern_LogStr
                RTS
@cfg_cpuMsg     ASC  'cpu: fast',00
@cfg_shadowMsg  ASC  'shadow: $77',00

;==============================================================================
; HARDWARE DETECTION
;==============================================================================

;=============================================================================
; _DetectHardware - Detect system hardware configuration
;-----------------------------------------------------------------------------
; Detects:
;   - ROM version
;   - RAM size
;   - CPU speed
; Results stored in kernel variables.
;=============================================================================
_DetectHardware
                ;-----------------------------------------
                ; Detect IIgs ROM version via IDROUTINE ($FE1F)
                ;-----------------------------------------
                ; Per Apple IIgs Firmware Reference (p.245, 272):
                ;   Call with carry SET.
                ;   Returns carry clear if IIgs, carry set if older Apple II.
                ;   X[7:0] = ROM version number (0, 1, 3)
                ;   Y[15:8] = Machine ID ($00 = IIgs)
                ;   A[6:0] = feature flags
                ; Must be called from PBR=$00 (JSR is bank-local), so we install
                ; a 4-byte trampoline in bank $00 and JSL to it.

                ; Verify IIgs before calling IDROUTINE (belt-and-suspenders:
                ; on non-IIgs machines, $FE1F may not exist or behave differently)
                SEP     #$20
                LDAL    $FFFBB3         ; Machine marker
                CMP     #$06
                BNE     @notIIgs
                LDAL    $FFFBC0         ; IIgs confirmation byte
                CMP     #$E0
                BNE     @notIIgs

                ; Install trampoline at IDROUTINE_TRAMP ($000320): JSR $FE1F; RTL
                LDA     #$20            ; JSR opcode
                STAL    IDROUTINE_TRAMP
                LDA     #$1F
                STAL    IDROUTINE_TRAMP+1
                LDA     #$FE
                STAL    IDROUTINE_TRAMP+2
                LDA     #$6B            ; RTL opcode
                STAL    IDROUTINE_TRAMP+3

                ; Ensure LC maps ROM so $00FE1F hits the firmware routine
                LDAL    $E0C082         ; ROMIN: LC reads ROM
                LDAL    $E0C082

                REP     #$30            ; 16-bit A/X/Y for native call
                PHB                     ; Save DBR
                SEP     #$20
                LDA     #$00
                PHA
                PLB                     ; DBR = $00 (IDROUTINE reads from bank 0)
                REP     #$20            ; 16-bit A

                ; (Same DP-clobber class as the SmartPort fix / block.s
                ; _blkFwCall: this ROM call runs at the kernel DP, not D=$0.
                ; Harmless here -- it's a one-shot at _DetectHardware before any
                ; DP pointer is live -- so it's left unwrapped.)
                SEC                     ; Carry SET on entry (required!)
                JSL     IDROUTINE_TRAMP ; JSR $FE1F; RTL

                PLB                     ; Restore DBR ($02)

                BCS     @notIIgs        ; Carry set = not IIgs
                ; Y register contains version info from $FB59:
                ;   Y[15:8] = Machine ID ($00 = Apple IIgs)
                ;   Y[7:0]  = ROM version number (0, 1, or 3)
                ; (Firmware reference p.245 says X, but empirically on IIgs
                ;  ROMs the version byte is stored at $FB59 and loaded to Y)
                TYA
                AND     #$00FF
                STA     DetectedROM
                STA     ROMVersion
                BRA     @romDone
@notIIgs
                REP     #$20
                STZ     DetectedROM
                STZ     ROMVersion
@romDone

                ;-----------------------------------------
                ; Detect RAM size
                ;-----------------------------------------
                ; Use Miscellaneous Tools to get RAM size
                ; Or probe memory banks directly
                JSR     _DetectRAMSize

                ;-----------------------------------------
                ; Detect CPU speed by cycle-counting between VBL edges
                ;-----------------------------------------
                ; Read CYAREG for reference (slow/fast bit)
                SEP     #$20
                LDAL    HW_CYAREG
                REP     #$20
                AND     #$00FF
                STA     DetectedSpeed

                ; Measure actual speed via VBL timing
                JSR     _MeasureCPUSpeed
                RTS



;==============================================================================
; Far_Init - verify the far kernel bank and make it callable.
;
; The far bank is a SECOND statically linked kernel image (bin/fgxfar.bin), a
; segment of /fgxunix that stage 2 loads into the bank after the core.  See
; docs/kernel-banks.md.
;
; The bank NUMBER is derived, never stored: LoaderAllocKernelBank claims
; KERNEL_BANKS contiguous bank-aligned banks for core, far and tty, so the far
; bank is always the live kernel bank + 1.
;
; Order:
;   1. Verify KFAR_MAGIC and the ABI version in that bank.  A stale far segment
;      from an older build is worse than none, so this is checked, not assumed.
;   2. Patch every core-side JSL operand bank byte from the assembler's baked
;      FGX_KFAR_BANK ($08) to the live far bank, walking _FarPatchTbl.
;   3. Call the far bank's own init (slot 0) with A = the core bank, so it
;      patches its side.  That JSL is itself a patched site, which is why step 2
;      must run first.
;   4. Set _kFarReady.
;
; A missing or wrong-version far bank is FATAL: boot halts with a message on the
; firmware console and a red border (@fi_absent, below).
;
; Entry: MX %00, kernel DBR.  Exit: C=1 + _kFarReady=1 on success; C=0 otherwise.
;==============================================================================
Far_Init        MX      %00
                _DBRK                           ; DBR = kernel bank (tables/statics)
                STZ     _kFarReady

                ; ---- build a long pointer to <farbank>:KFAR_HDR_MAGIC ----
                LDA     #KFAR_HDR_MAGIC
                STA     _shTmp0                 ; ptr lo16
                SEP     #$20
                MX      %10
                _BANKK                          ; A.lo = live kernel bank
                INC                             ; far bank = kernel bank + 1
                STA     _shTmp0+2               ; ptr bank
                STA     _shTmp2                 ; keep for the patch loop
                REP     #$30
                MX      %00

                ; ---- verify the image really is there ----
                LDA     [_shTmp0]
                CMP     #KFAR_MAGIC
                BNE     @fi_absent
                LDY     #KFAR_HDR_ABIVER-KFAR_HDR_MAGIC
                LDA     [_shTmp0],Y
                CMP     #KFAR_ABI_VERSION
                BNE     @fi_absent

                ; ---- patch core-side JSL operand bank bytes ----
                ; DBR is the kernel bank and the sites are IN the kernel bank, so
                ; absolute-indexed reaches them without a second pointer.
                LDX     #0
@fi_patchL      CPX     #_FarPatchBytes
                BCS     @fi_patchDone
                LDY     _FarPatchTbl,X          ; Y = in-kernel-bank offset
                SEP     #$20
                MX      %10
                LDA     _shTmp2                 ; the live far bank
                STA     |$0000,Y
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @fi_patchL
@fi_patchDone

                ; ---- hand off: far bank patches its own side ----
                SEP     #$20
                MX      %10
                _BANKK                          ; A.lo = core bank
                REP     #$30
                MX      %00
_kfp001         JSL     KFAR_INIT               ; bank byte patched just above
                BCC     @fi_absent

                LDA     #1
                STA     _kFarReady
                SEC
                RTS

;--- Far bank missing or wrong ABI: FATAL.  The far bank holds the sound driver
;--- and the BRAM RTC, and boot JSLs into it two instructions below this
;--- routine -- with the bank absent those operands keep the assembler's
;--- FGX_KFAR_BANK ($08) and jump into an unrelated bank.  There is nothing to
;--- degrade to, so say so on the only output device that exists this early
;--- (firmware COUT via the bank-0 CoutTramp) and stop.
@fi_absent      LDX     #0
@fi_msgL        LDA     |@fi_msg,X
                AND     #$00FF
                BEQ     @fi_msgDone
                PHX
                JSR     _BootCon_PutChar        ; JSR, not JSL: it ends in RTS
                PLX                             ;   (boot_console.s:64)
                INX
                BRA     @fi_msgL
@fi_msgDone     SEP     #$20
                MX      %10
                LDA     #$01
                STAL    $E0C034                 ; border = red, as _Far_StubHalt
@fi_spin        BRA     @fi_spin

@fi_msg         ASC     'FGX: far segment missing or wrong version - halted',0D,0A,00

;==============================================================================
; Tty_Init - verify the tty kernel bank and make it callable.
;
; Far_Init one bank further on, and deliberately a near-copy rather than a
; shared routine: the two differ in the derived bank, the magic, the patch
; table and the failure policy, which is four of the six things the routine
; does.  A parameterised version would take a descriptor and cost more core
; bytes than the duplication saves.  See docs/history/plans/tty-kernel-bank.md.
;
; The bank NUMBER is derived, never stored: LoaderAllocKernelBank claims
; KERNEL_BANKS ($03) contiguous bank-aligned banks and the kernel image uses
; only the first, so the tty bank is always the live kernel bank + 2.
;
; A MISSING TTY BANK IS FATAL SINCE T3'S CUTOVER.  It was not, while nothing
; depended on the bank -- T1 put the clists there and no boot path called them.
; T3 puts `t_pgrp' and `t_flags' there, so with the image missing there is no
; foreground process group to read and nothing left to degrade to.  This is the
; halt Far_Init already was, and the policy change was written down in
; docs/history/plans/tty-kernel-bank.md section 2 BEFORE it was due, so that a non-fatal path
; could not quietly stop being survivable.
;
; Entry: MX %00, kernel DBR.  Exit: C=1 + _kTtyReady=1; does not return
; otherwise.
;==============================================================================
Tty_Init        MX      %00
                _DBRK                           ; DBR = kernel bank (tables/statics)
                STZ     _kTtyReady

                ; ---- build a long pointer to <ttybank>:KTTY_HDR_MAGIC ----
                LDA     #KTTY_HDR_MAGIC
                STA     _shTmp0                 ; ptr lo16
                SEP     #$20
                MX      %10
                _BANKK                          ; A.lo = live kernel bank
                INC
                INC                             ; tty bank = kernel bank + 2
                STA     _shTmp0+2               ; ptr bank
                STA     _shTmp2                 ; keep for the patch loop
                REP     #$30
                MX      %00

                ; ---- verify the image really is there ----
                LDA     [_shTmp0]
                CMP     #KTTY_MAGIC
                BNE     @ti_absent
                LDY     #KTTY_HDR_ABIVER-KTTY_HDR_MAGIC
                LDA     [_shTmp0],Y
                CMP     #KTTY_ABI_VERSION
                BNE     @ti_absent

                ; ---- patch core-side JSL operand bank bytes ----
                ; DBR is the kernel bank and the sites are IN the kernel bank, so
                ; absolute-indexed reaches them without a second pointer.
                LDX     #0
@ti_patchL      CPX     #_TtyPatchBytes
                BCS     @ti_patchDone
                LDY     _TtyPatchTbl,X          ; Y = in-kernel-bank offset
                SEP     #$20
                MX      %10
                LDA     _shTmp2                 ; the live tty bank
                STA     |$0000,Y
                REP     #$30
                MX      %00
                INX
                INX
                BRA     @ti_patchL
@ti_patchDone

                ; ---- hand off: tty bank patches its own side ----
                SEP     #$20
                MX      %10
                _BANKK                          ; A.lo = core bank
                REP     #$30
                MX      %00
_ktp001         JSL     KTTY_INIT               ; bank byte patched just above
                BCC     @ti_absent

                LDA     #1
                STA     _kTtyReady
                SEC
                RTS

;--- ABSENCE IS FATAL SINCE T3'S CUTOVER, and this was written down before it
;--- was true: docs/history/plans/tty-kernel-bank.md section 2 said "the day the line
;--- discipline moves in (T3) that has to become the same loud halt", precisely
;--- so a non-fatal path could not quietly stop being survivable.  It has
;--- stopped.  `t_pgrp' and `t_flags' live in this bank now, so with it missing
;--- there is no foreground process group to read and nothing to degrade TO --
;--- the same position Far_Init is in, and this is its halt, one bank along.
;--- Firmware COUT through the bank-0 CoutTramp is the only output device that
;--- exists this early.
@ti_absent      LDX     #0
@ti_msgL        LDA     |@ti_msg,X
                AND     #$00FF
                BEQ     @ti_msgDone
                PHX
                JSR     _BootCon_PutChar        ; JSR, not JSL: it ends in RTS
                PLX                             ;   (boot_console.s:64)
                INX
                BRA     @ti_msgL
@ti_msgDone     SEP     #$20
                MX      %10
                LDA     #$01
                STAL    $E0C034                 ; border = red, as _Ktty_StubHalt
@ti_spin        BRA     @ti_spin

@ti_msg         ASC     'FGX: tty segment missing or wrong version - halted',0D,0A,00

;==============================================================================
; _LogTtyBank - report the tty bank's state on the boot console.
;
; Split from Tty_Init for the reason _LogFarBank is split from Far_Init: the
; init has to run before anything can call into the bank, which is before
; _BootScreen flips the kernel-log-mirror flag, so a line emitted there reaches
; the ring and never the screen.
;
; The success line is emitted BY the tty bank, through a core call.  That round
; trip is the proof the tty->core path works, and it is the only thing in T1
; that exercises it.
;==============================================================================
_LogTtyBank     MX      %00
                REP     #$30
                MX      %00
                LDA     _kTtyReady
                BEQ     @ltb_absent
_ktp002         JSL     KTTY_LOG_STATE  ; bank byte patched by Tty_Init
                RTS
@ltb_absent     LDA     #@ltb_msgAbsent
                STA     _conStrPtr
                JSR     Kern_LogStr
                RTS

@ltb_msgAbsent  ASC     'tty: bank ABSENT (tty segment missing, or bad version)',00

;==============================================================================
; _LboltProbe - prove the lbolt wake is armed, ticking, and drainable.
;
; apple/fgx#108 T3.  `lbolt' is BSD's "wait a bit and retry" channel and
; ttwrite sleeps on it three times; FGX drives it as the heartbeat MARKING
; (_kLboltDue) and _Lbolt_Wake PERFORMING on kernel DP -- 2.11BSD's own
; needsoft/softclock split, argued at both ends.
;
; UNCONDITIONAL, AND IT WAITS FOR AT MOST ONE VBL.  Case 2 watches a tick go by
; rather than inferring one from a value; the other three ask questions already
; answered by the time boot reaches here.
;
; THE THREE CASES, and why each can fail on its own:
;
;   1  _kLboltTick IS IN RANGE.  It is `DA LBOLT_TICKS', not `DS 2', and the
;      difference is not cosmetic: a DS-zero cell first-DECs to $FFFF, which at
;      60 Hz is an EIGHTEEN-MINUTE first second.  _kQuantum's own comment
;      records that trap being hit once already.  A zero or an out-of-range
;      value is exactly what that mistake looks like.
;   2  IT IS BEING DECREMENTED -- watched across one real VBL, not inferred.
;      This is the case where the whole mechanism is inert and every other
;      check still passes.  See the comment at the code for why inferring it
;      from the value was flaky one boot in sixty.
;   3  _Lbolt_Wake DRAINS WHEN DUE -- flag set, C=1 back, flag cleared.
;   4  AND ONLY WHEN DUE -- called again with nothing pending, C=0.  This is
;      what the carry is for.  Asserting the FLAG a second time proves nothing:
;      a routine with its `BEQ' deleted wakes every call and still leaves the
;      flag clear, because it STZs unconditionally too.  That mutation turns a
;      once-a-second channel into a 60 Hz one and hides a dead heartbeat, and
;      only the carry can see it.
;
; WHAT IT CANNOT WITNESS, so a green line is not read as more than it is: that
; a SLEEPER actually wakes.  Nothing sleeps on WCHAN_LBOLT until ttwrite does,
; and a probe that slept here would block boot on the mechanism it is testing.
;==============================================================================
_LboltProbe     MX      %00
                REP     #$30
                MX      %00
                ; ---- 1: armed, and not the DS-zero $FFFF ----
                LDA     _kLboltTick
                BEQ     @lbp_bad1
                CMP     #LBOLT_TICKS+1
                BCS     @lbp_bad1
                ; ---- 2: the heartbeat is DECREMENTING it, observed across a
                ; real VBL rather than inferred from the value.
                ;
                ; IT MUST BE WATCHED AND NOT INFERRED.  `_kLboltTick !=
                ; LBOLT_TICKS' looks like evidence of a live heartbeat and is
                ; not: the counter CYCLES 60->1->60 once a second, so reading
                ; exactly LBOLT_TICKS is a legitimate value once per second and
                ; the assertion would fail about one boot in sixty for a reason
                ; unrelated to what it tests.
                ;
                ; _kSystemTicks advances every VBL, and
                ; _kLboltTick is decremented by the same handler, so across one
                ; observed change of the former the latter MUST change too.
                ; The spin is bounded by X wrapping (65,536 tries, ~10 VBLs at
                ; this clock) so a genuinely dead heartbeat fails the case
                ; instead of hanging the boot -- which is the failure mode
                ; apple/fgx#218 made expensive.
                STA     _shTmp1                 ; the tick we start on
                LDA     _kSystemTicks
                STA     _shTmp0
                LDX     #0
@lbp_spin       LDA     _kSystemTicks
                CMP     _shTmp0
                BNE     @lbp_vbl
                INX
                BNE     @lbp_spin
                BRA     @lbp_bad2               ; no VBL at all: heartbeat dead
@lbp_vbl        LDA     _kLboltTick
                CMP     _shTmp1
                BEQ     @lbp_bad2               ; a VBL passed, lbolt did not move
                ; ---- 3: drains when due ----
                LDA     #1
                STA     _kLboltDue
                JSR     _Lbolt_Wake
                BCC     @lbp_bad3               ; it did not wake
                LDA     _kLboltDue
                BNE     @lbp_bad3               ; ...or did not clear the flag
                ; ---- 4: and ONLY when due ----
                JSR     _Lbolt_Wake
                BCS     @lbp_bad4               ; woke with nothing pending
                RTS                             ; a PASS says nothing; the
                                                ;   FAIL arm above still speaks
@lbp_bad1        LDA     #1
                BRA     @lbp_bad
@lbp_bad2        LDA     #2
                BRA     @lbp_bad
@lbp_bad3        LDA     #3
                BRA     @lbp_bad
@lbp_bad4        LDA     #4
@lbp_bad         PHA
                LDA     #@lbp_msgBad
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                PLA
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                RTS

@lbp_msgBad      ASC     'LBOLT PROBE FAILED case ',00


;==============================================================================
; _KcIrqProbe - prove the interrupt-time kernel-C context is a SECOND one.
;
; apple/fgx#108 T6, increment 1.  The context is FGX_DP_KERNELC_IRQ plus
; FGX_STK_KIRQ (include/kernel.s), entered through KTTY_KC_ENTER_IRQ
; (include/kernelc.s).  Nothing uses it yet -- the heartbeat does not call
; ttyinput until increment 4 -- so this is the only thing that exercises it,
; and a mechanism nothing exercises is a contract nothing has tested.
;
; THE RETURN VALUE IS NOT THE ASSERTION, and src/kernel/far/kc_probe.c is where
; that was learned: "Pointing KC_ENTER at FGX_DP_KKERN instead and rebuilding
; still returns 42 and still boots ... this function writes every DP slot it
; later reads, so it is self consistent on any page."  A C routine cannot tell
; you which page it ran on.  Only a WITNESS OUTSIDE IT can, and that file asked
; for one: "The page choice rests on the overlap between include/dpmap.s and
; src/kernel/far/fcc_dp.s, which deserves a build-time check of its own."  This
; is that check, at boot rather than at build, and aimed at the page pair T6
; adds rather than the one that already shipped.
;
; THREE CASES, IN EXECUTION ORDER, each able to fail on its own:
;
;   1  THE ANSWER CAME BACK AND SO DID S.  `kc_irqprobe(9)' returns 42, and
;      the bracket switches the hardware STACK, so a stack that does not come
;      back is the failure that would present as a wild RTS from somewhere else
;      entirely -- a halt with no verdict, which names nothing.  Asked here,
;      where it can still be reported.
;   2  THE OUTER REGISTER FILE IS UNDISTURBED.  This is the whole property.
;      FGX_DP_KERNELC is filled with an offset-derived pattern first, so a
;      wrong page shows up as a MISMATCH rather than as a plausible value; a
;      constant pattern would pass wherever the callee happened not to write.
;   3  THE INNER ONE WAS WRITTEN.  Without this, case 2 passes vacuously the
;      day the call stops happening at all -- a stubbed slot, a dropped patch
;      site, a bank byte that never got fixed.  The band is zero on the way in
;      (_KcDpIrq_Zero), so a non-zero word is proof the C ran there.
;
;      IT READS THE REGISTERS ONLY, `_fcc_fpr0'..`_fcc_fpr7', and the range
;      matters: `_KcDpIrq_Zero' seeds `_fcc_stkfloor' ($B9) with a 16-bit store
;      spanning $B9-$BA, so a check over the whole band finds that high byte
;      non-zero and answers its own question -- a mutation erasing every trace
;      of the call would still report OK.  Naming the register band is what
;      makes this say what it means.
;
;   4  THE spl BRACKET IS REAL, and it is asked here rather than in a fixture
;      because a behavioural suite cannot ask it: nothing observable changes if
;      `spltty()' is `#define spltty() 0'.  `kc_splprobe' answers 44 through a
;      real bracket and 0 through the empty macros; read its header in
;      tty_dev.c for what the three digits are.
;      IT RUNS AFTER THE CLEANUP BELOW, not with the others, because it crosses
;      on the NORMAL bracket -- and while the pattern is still on
;      FGX_DP_KERNELC, a guarded prologue there would compare the stack against
;      fiction and spin in `_fcc_stkoflow' with no console to say why.
;
; THE MUTATION IT IS BUILT FOR is one constant: point KTTY_KC_ENTER_IRQ at
; FGX_DP_KERNELC and case 2 must go red.  If it does not, this probe is
; measuring nothing.
;
; CLEANUP RUNS ON EVERY PATH, and that is not tidiness.  The pattern above sits
; where _fcc_stkfloor ($B9) lives, so leaving it there hands the next guarded
; prologue a fictional floor -- which is apple/fgx#225 exactly, and its symptom
; is _fcc_stkoflow spinning at `BRA *' with nothing able to say why.
;
; The bank is checked first: with the tty bank absent the JSL would land in
; unmapped space, and _LogTtyBank has already reported the absence.
;==============================================================================
; The REGISTER half of the band, as offsets into it: eight four-byte promoted-
; local slots, `_fcc_fpr0' through `_fcc_fpr7'.  Derived from the GENERATED slot
; map (src/kernel/far/fcc_dp.s) rather than written as 0 and $20, so it follows
; the compiler if fcc's file ever moves.  The control cells above it --
; stkfloor, fb, sfp -- are deliberately NOT in this range; see case 3.
KC_DP_FPR_LO    EQU     _fcc_fpr0-KC_DP_LO
KC_DP_FPR_HI    EQU     _fcc_fpr7+4-KC_DP_LO

_KcIrqProbe     MX      %00
                REP     #$30
                MX      %00
                LDA     _kTtyReady
                BNE     @kip_go
                RTS
@kip_go         LDX     #0
@kip_fill       TXA
                ORA     #$C000
                STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kip_fill

                ; Cross into tty-bank C through the INTERRUPT bracket.
                TSC
                PHA                             ; the S to come back to
                KTTY_KC_ENTER_IRQ               ; D = the IRQ file, S = its stack
                LDA     #9                      ; the one argument
                PHA
_ktp048         JSL     KTTY_KC_IRQPROBE
                TAX                             ; stash before the PLA eats A
                PLA                             ; caller pops its own argument
                KTTY_KC_LEAVE_IRQ

                LDY     #1                      ; ---- 1: the answer, and S ----
                ; @kip_pullbad SITS BETWEEN THE TWO TESTS, not at the end of the
                ; routine: case 4 grew the distance and merlin32 answered "Bad
                ; Jump ... Too long".  A local landing point is cheaper than a
                ; BRL and keeps the balanced pull next to what unbalances it.
                CPX     #42
                BNE     @kip_pullbad
                TSC
                CLC
                ADC     #2                      ; what S becomes when we pull
                CMP     1,S
                BEQ     @kip_c1ok
@kip_pullbad    PLA                             ; the recorded S, kept balanced
                BRA     @kip_done
@kip_c1ok       PLA                             ; drop the recorded S

                LDY     #2                      ; ---- 2: outer file undisturbed
                LDX     #0
@kip_ck2        TXA
                ORA     #$C000
                CMPL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                BNE     @kip_done
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kip_ck2

                LDY     #3                      ; ---- 3: inner file WAS written
                LDX     #KC_DP_FPR_LO
@kip_ck3        LDAL    $000000+FGX_DP_KERNELC_IRQ+KC_DP_LO,X
                BNE     @kip_ok
                INX
                INX
                CPX     #KC_DP_FPR_HI
                BCC     @kip_ck3
                BRA     @kip_done               ; nothing written: it never ran
@kip_ok         LDY     #0

                ; ---- undo the test's own damage, whatever the verdict ----
                ; Y is the verdict and must survive: _KcDpIrq_Zero touches only
                ; A and X, and so does the loop below.
@kip_done       LDX     #0
                LDA     #0
@kip_zero       STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kip_zero
                JSR     _KcDpIrq_Zero

                CPY     #0
                BEQ     @kip_c4
                BRL     @kip_bad                ; an earlier case already failed.
                                                ; BRL: cases 5 and 6 pushed
                                                ; `@kip_bad' past branch range,
                                                ; which is the third time this
                                                ; routine has grown into that --
                                                ; see `@kip_pullbad' above for
                                                ; the first.
@kip_c4
                ; ---- 4: the spl bracket is real.  Safe here and not above:
                ; the cleanup has just put FGX_DP_KERNELC back to zeros, so the
                ; NORMAL bracket's C has a sane _fcc_stkfloor to run on. ----
                KTTY_KC_ENTER                   ; the ordinary page, not the IRQ one
_ktp049         JSL     KTTY_KC_SPLPROBE
                TAX                             ; the bracket touches neither X nor Y
                KTTY_KC_LEAVE
                ; THE CASE NUMBER IS SET AFTER THE CALL, NOT BEFORE IT.  The
                ; callee is fcc output and returns with Y holding whatever it
                ; last used, so an `LDY #4' ahead of the JSL is gone by the time
                ; anything can report it.
                LDY     #4
                CPX     #44
                BNE     @kip_far
                LDY     #0

                BRA     @kip_c5
                ; A LOCAL LANDING POINT, and the third time this routine has
                ; needed one: cases 5 and 6 put `@kip_bad' out of branch range
                ; from case 4, exactly as case 4 did to `@kip_pullbad' above.
                ; Cheaper than a BRL at each site and it keeps growing the
                ; probe from becoming a rewrite.
@kip_far        BRL     @kip_bad
@kip_c5
                ; ---- 5: SLOT 38 DISPATCHES, through the INTERRUPT bracket.
                ; T6 increment 4b lands `kc_ttyinput' -- the receive
                ; interrupt's door into the discipline -- inert, and an
                ; unassigned slot is the failure that names nothing: it reaches
                ; `_Ktty_StubHalt', the machine stops printing, and from
                ; outside a halt looks like NO VERDICT AND NO FAILURE.
                ; Increment 5 spent a run on exactly that.
                ;
                ; WHAT THIS PROVES AND WHAT IT DOES NOT.  It proves the slot is
                ; assigned, that the IRQ bracket survives a call into real
                ; discipline code, and that the index guard answers.  It does
                ; NOT exercise `l_rint' -- a valid index would inject a
                ; character into a live line and ECHO it across the boot log,
                ; and `ttyinput' itself is already driven exhaustively by
                ; tty_probe2 in task context.  The interrupt-time path is the
                ; FLIP's to witness, with the pty and VC fixtures.
                ;
                ; NTTY, not a bound-line index: `tty_byidx' rejects both an
                ; out-of-range index and an unbound one, and only the first is
                ; independent of how far boot has got.
                TSC
                PHA                             ; the S to come back to
                KTTY_KC_ENTER_IRQ
                LDA     #0                      ; arg2: c  (fcc reads its
                PHA                             ;   arguments RIGHT-TO-LEFT,
                LDA     #NTTY                   ;   so idx is pushed last)
                PHA                             ; arg1: idx -- no such line
_ktp053         JSL     KTTY_KC_TTYINPUT        ; slot 38; A = 0 / -1
                TAX
                PLA                             ; the caller pops its own two
                PLA
                KTTY_KC_LEAVE_IRQ
                LDY     #5                      ; AFTER the call: fcc clobbers Y
                CPX     #$FFFF                  ; -1: no such line
                BNE     @kip_pull5
                TSC                             ; and the stack came back level
                CLC
                ADC     #2
                CMP     1,S
                BNE     @kip_pull5
                LDY     #0
@kip_pull5      PLA                             ; the recorded S, kept balanced
                CPY     #0
                BNE     @kip_far

                ; ---- 6: THE OUTPUT RAIL MARKS AND THE SOFT SITE PERFORMS.
                ; T6 increment 4b's second half, end to end and with nothing
                ; reaching the screen:
                ;
                ;   a. `kc_ttyinput(0, 'x')' -- slot 38 sets `tty_irq' for the
                ;      length of the call, so the ECHO reaches `t_outq' and
                ;      `tty_oproc' MARKS TS_TIMEOUT instead of painting.  The
                ;      answer is 1, "something was deferred".  THAT IS WHY THIS
                ;      CAN RUN AT BOOT AT ALL: without the rail the same call
                ;      would paint an `x' across the boot log.
                ;   b. `_Tty_Flush(0, FREAD|FWRITE)' empties both queues.
                ;      `ttyflush' does NOT touch TS_TIMEOUT (tty.c), so the mark
                ;      survives and the drain below has a line to restart with
                ;      nothing left to send.
                ;   c. `_Tty_DrainOutPend' answers 1 -- one line restarted --
                ;      and clears the summary word.  `ttrstrt' -> `ttstart' ->
                ;      `tty_oproc' finds `t_outq' empty and writes nothing.
                ;
                ; THE CHARACTER IS THE CONSOLE'S OWN LINE ON PURPOSE.  A pty
                ; slave would do, but only if a pair happened to be open, and
                ; `tty_byidx' rejects an unbound line -- which would make this
                ; case pass by not running.
                TSC
                PHA                             ; the S to come back to
                KTTY_KC_ENTER_IRQ
                LDA     #'x'                    ; arg2: c
                PHA
                LDA     #0                      ; arg1: idx -- the console
                PHA
_ktp055         JSL     KTTY_KC_TTYINPUT        ; slot 38; A = 1 deferred
                TAX
                PLA
                PLA
                KTTY_KC_LEAVE_IRQ
                ; THREE SUB-CHECKS, THREE CASE NUMBERS.  A single number over
                ; three assertions names the group and not the failure, and
                ; this routine's own history says why that matters: case 4's
                ; first red run reported "case 0" and the number was the whole
                ; signal.
                STX     _kipTmp                 ; the answer, past the pulls
                LDY     #6                      ; 6: the call answered "deferred"
                CPX     #1
                BEQ     @kip_c6go
                BRL     @kip_pull6              ; BRL: cases 9 and 10 pushed the
                                                ;   balanced pull out of range,
                                                ;   which is the fourth time
                                                ;   this routine has grown into
                                                ;   a branch limit
@kip_c6go
                PLA                             ; drop the recorded S
                LDA     #0                      ; empty both queues; ttyflush
                LDX     #TTYIO_FREAD+TTYIO_FWRITE ;   leaves TS_TIMEOUT alone
_ktp082         JSL     KTTY_KC_TTFLUSH
                LDA     #1
                STA     _kTtyOutAny             ; what the heartbeat will set
                JSR     _Tty_DrainOutPend       ; A = lines restarted
                STA     _kipTmp
                LDY     #7                      ; 7: exactly one line restarted
                LDA     _kipTmp
                CMP     #1
                BNE     @kip_far2
                LDY     #8                      ; 8: and the summary is clear
                LDA     _kTtyOutAny
                BNE     @kip_far2
                LDY     #0

                ; ---- 9 and 10: THE `d_stop' HALF OF THE RAIL, driven by the
                ; two characters that own it.  `^S' takes `ttyinput's stop arm
                ; (tty.c:1081), which sets TS_TTSTOP and calls `kc_cdstop' --
                ; deferred here, because a chardev dispatch cannot run in an
                ; ISR -- and RETURNS before any echo, so the 1 the drain
                ; answers is the STOP and nothing else.  `^Q' then takes the
                ; restart arm (:1092) and puts the console back, which is not
                ; tidiness: leaving TS_TTSTOP set on tty[0] would stop the
                ; boot log for good, and the failure would look like a hang
                ; somewhere else entirely.
                ; FOUR NUMBERS FOR FOUR ASSERTIONS.  A number shared across
                ; more than one assertion names the group and not the failure,
                ; which sends the next reader to the wrong routine.
                JSR     @kip_rint               ; A = ^S -> deferred?
                LDY     #9
                CMP     #1
                BNE     @kip_far2
                LDA     #1                      ; what the heartbeat will set
                STA     _kTtyOutAny             ;   from that same answer
                JSR     _Tty_DrainOutPend
                STA     _kipTmp
                LDY     #10                     ; the STOP performed, alone --
                CMP     #1                      ;   the stop arm returns before
                BNE     @kip_far2               ;   any echo, so nothing else
                                                ;   is marked
                LDY     #$0011                  ; ^Q -- restart output
                JSR     @kip_rintA
                LDY     #11
                CMP     #1
                BNE     @kip_far2
                LDA     #1
                STA     _kTtyOutAny
                JSR     _Tty_DrainOutPend
                STA     _kipTmp
                LDY     #12
                CMP     #1
                BNE     @kip_far2
                LDY     #0
                BRA     @kip_c6ok
                ; The second local landing point, for the same reason the first
                ; exists: this routine has outgrown branch range four times and
                ; a BRL at each site is bigger than one here.
@kip_far2       BRL     @kip_bad

                ; ONE CALLER'S WORTH OF BRACKET, SHARED.  Cases 9 and 10 differ
                ; only in the byte, and a second copy of the ENTER/PHA/PHA/JSL/
                ; PLA/PLA/LEAVE dance is the shape that drifts.
@kip_rint       LDY     #$0013                  ; ^S -- stop
                ; THE BYTE RIDES IN Y AND NOT ON THE STACK, and that is not a
                ; preference: KTTY_KC_ENTER_IRQ MOVES S to the interrupt stack,
                ; so anything the caller pushed first is on a stack this code
                ; can no longer address -- a read at `8,S' after the bracket
                ; gets whatever the IRQ stack holds.  The macro destroys A and X
                ; and leaves Y alone, which is what makes Y the place.
@kip_rintA      TSC
                PHA                             ; the S to come back to
                KTTY_KC_ENTER_IRQ
                TYA                             ; arg2: c, carried in Y
                PHA
                LDA     #0                      ; arg1: idx -- the console
                PHA
_ktp056         JSL     KTTY_KC_TTYINPUT
                TAX
                PLA
                PLA
                KTTY_KC_LEAVE_IRQ
                PLA                             ; the recorded S
                STX     _kipTmp
                TXA
                RTS
@kip_pull6      PLA                             ; the recorded S, kept balanced
                BRA     @kip_bad
@kip_c6ok
                ;-------------------------------------------------------------
                ; ---- 13-16: the same bracket, FROM AN ACTUAL INTERRUPT ----
                ;
                ; apple/fgx#242.  Everything above this line runs in TASK
                ; context, where the bank-0 language card is banked in -- and
                ; that is precisely the distinction KTTY_KC_ENTER_IRQ is named
                ; for.  All twelve cases passed through increments 1, 2, 3 and
                ; 4b steps 1-3 while the bracket could not reach its own stack
                ; or its own register file from the one interrupt it exists to
                ; serve.  A PROBE THAT CANNOT RUN IN THE CONTEXT UNDER TEST IS
                ; NOT COVERAGE FOR THAT CONTEXT.
                ;
                ; The heartbeat (toolbox.s) runs the bracket for its first
                ; LC_PROBE_TICKS ticks and leaves the counters here.  ONE CASE
                ; NUMBER PER ASSERTION, for the reason case 9 recorded: a
                ; shared number names the group and not the failure.
                ;-------------------------------------------------------------
                LDY     #13                     ; ---- 13: it came back ----
                LDA     _hbLcRuns               ; DENOMINATOR FIRST.  _hbLcFail
                STA     _kipTmp                 ;   reads 0 both when nothing
                BEQ     @kip_bad                ;   failed and when the
                                                ;   heartbeat died before
                                                ;   writing it -- measured, and
                                                ;   it read as a PASS under a
                                                ;   mutation that kills the boot
                INY                             ; ---- 14: the control ----
                LDA     _hbLcCtl                ; the same store/read-back
                STA     _kipTmp                 ;   against LOW bank 0, which
                BNE     @kip_bad                ;   must never fail
                INY                             ; ---- 15: the card was ours ----
                LDA     _hbLcFail               ; store/read-back at
                STA     _kipTmp                 ;   FGX_STK_KIRQ and at
                BNE     @kip_bad                ;   FGX_DP_KERNELC_IRQ+$98,
                                                ;   INSIDE the bracket
                INY                             ; ---- 16: and handed back ----
                LDA     _hbLcAfter              ; LEAVE must restore the mapping
                STA     _kipTmp                 ;   ENTER found: the firmware
                CMP     _hbLcState              ;   keeps running ROM code after
                BNE     @kip_bad                ;   we return to it

                RTS                             ; a PASS says nothing; the
                                                ;   FAIL arm above still speaks
@kip_bad        PHY
                LDA     #@kip_msgBad
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                PLA
                JSR     Kern_LogDec16
                ; AND THE VALUE THAT WAS WRONG.  A case number says which
                ; assertion; it does not say what the machine answered, and on
                ; a boot probe there is no second run to find out in.
                LDA     #@kip_msgGot
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA     _kipTmp
                JSR     Kern_LogDec16
                JSR     Kern_LogEOL
                RTS

@kip_msgBad     ASC     'KC IRQ PROBE FAILED case ',00
@kip_msgGot     ASC     ' got ',00
_kipTmp         DS      2

;==============================================================================
; _TtyDevInit - bind every tty device to its struct tty.  ALWAYS, not a probe.
; _ClistInit  - build the tty bank's cblock free chain.  ALWAYS, not a probe.
;
; TWO ROUTINES, ONE LESSON, and it cost two debugging rounds to learn it
; twice in a row.
;
; SPLIT OUT OF THE CLIST PROBE 2026-08-24, AND THE SPLIT WAS A BUG FIX -- the
; reason this note outlived the probe itself (removed 2026-09-07).  cinit() is
; production initialisation, it is what makes getc/putc work at all, and it was
; sitting inside the probe routine because the probe was the only thing that
; had ever needed it.  Gating the probe therefore took cinit with it, and the
; default kernel came up with NO CLIST POOL: the failure surfaced as `devnode'
; failing to open /dev/null, four layers away from anything that mentions a
; tty.  ANY probe removal has to ask what production code is hiding inside.
;
; That is the shape to remember rather than the incident: A PROBE THAT ALSO
; INITIALISES IS NOT A PROBE, and nothing says so until the day it is gated
; out.  If another probe here calls a `*_init' before its cases, it has the
; same defect waiting.
;==============================================================================
_TtyDevInit     MX      %00
                REP     #$30
                MX      %00
                LDA     _kTtyReady
                BNE     @td_go
                RTS
@td_go          KTTY_KC_ENTER                   ; DBR = tty bank, D = kernel-C
_ktp007         JSL     KTTY_KC_TTYDEVINIT      ; slot 6: bind the devices
                KTTY_KC_LEAVE
                RTS                             ; the COUNT is the probe's
                                                ;  business, not this routine's

;==============================================================================
; _TtyDevBind - bind the lines that are not bound yet.  _TtyDevInit's sibling,
; and it exists because a tty driver can arrive AFTER boot.
;
; _TtyDevInit runs once, from the boot path, and every tty line except the
; serial one is registered by the kernel before it.  /dev/tty01's driver is
; serial.mod, and modules are loaded by /etc/rc -- userland, long afterwards --
; so its tty_bound entry stayed 0, tty_byidx(5) answered NULL and the receive
; interrupt had no line to hand a character to.  KSVC_CDSETTTYIDX calls this
; the moment a module says which line it is (jumptable.s).
;
; THE BRACKET IS THE WHOLE POINT AND ITS ABSENCE WAS THE FIRST BUG.  Calling
; slot 42 straight from the KSVC handler did nothing: that handler runs on the
; CORE's direct page, and the tty bank's C wants FGX_DP_KERNELC -- kc_cdttyidx
; goes back through _FarSh_KernDP to recover it (kc_sys.s), so a wrong D makes
; the registry lookup answer about nothing.  KTTY_KC_ENTER sets DBR and D
; together and KTTY_KC_LEAVE puts both back.
;
; Only the BINDING half is exposed: tty_devinit's first loop zeroes tty_bound
; and resets t_line/t_dev/t_oproc on every line, which would take a live
; console's discipline out from under it.  The bind loop skips lines already
; bound, so this is idempotent and costs a registry scan.
;==============================================================================
_TtyDevBind     MX      %00
                REP     #$30
                MX      %00
                LDA     _kTtyReady
                BNE     @tb_go
                RTS
@tb_go          KTTY_KC_ENTER                   ; DBR = tty bank, D = kernel-C
_ktp084         JSL     KTTY_KC_TTYDEVBIND      ; slot 42: bind what is unbound
                KTTY_KC_LEAVE
                RTS

;==============================================================================
_ClistInit      MX      %00
                REP     #$30
                MX      %00
                LDA     _kTtyReady
                BNE     @ci_go
                RTS
@ci_go          KTTY_KC_ENTER                   ; DBR = tty bank, D = kernel-C
_ktp003         JSL     KTTY_KC_CINIT           ; slot 2: build the free chain
                KTTY_KC_LEAVE
                RTS

;==============================================================================
; _LogFarBank - report the far bank's state on the boot console.
;
; SEPARATE from Far_Init for the same reason _LogDetectedHardware is separate
; from _DetectHardware: Far_Init has to run early (before anything can call into
; the far bank), which is before _BootScreen flips the kernel-log-mirror flag, so
; a log line emitted there reaches the ring but never the screen.
;==============================================================================
_LogFarBank     MX      %00
                ; REP is not redundant with the MX directive: MX only tells the
                ; ASSEMBLER what width to emit, it does not set the CPU flags, and
                ; _LogDetectedHardware does not guarantee its exit width.
                REP     #$30
                MX      %00
                LDA     _kFarReady
                BEQ     @lfb_absent
                ; Success line is emitted BY the far bank, through a core call.
                ; That round trip is the proof the far->core path works.
_kfp030         JSL     KFAR_LOG_STATE  ; bank byte patched by Far_Init
                ; THE SAVE TABLE IS NOT GATED, apple/fgx#204: vfs.mod's C and
                ; the tty bank's both sleep whatever KCPROBE says, so the
                ; per-task register file has to exist whatever KCPROBE says.
                ; The PROBE below is still gated -- it is the self-test, which
                ; is the question the knob actually answers.
                JSR     _AllocKcDpSave  ; the register-file save table, on the heap
                DO      KCPROBE=1
                JSR     _KcProbe        ; first C in the kernel; reports itself
                FIN
                ; NO VFS BRING-UP HERE.  vfs.mod allocates its own arenas at
                ; Mod_LoadConf time, through KSVC_KMALLOC; there is no kernel
                ; call site for it.
                RTS
                ; The absent-path string stays in CORE: it is what prints when
                ; the far bank is not there to print anything.
@lfb_absent     LDA     #_msg_far_none
                ; Kern_LogStr reads the pointer from _conStrPtr (DP), NOT from A
                ; -- see log.s:17.  Passing it in A alone printed whatever the
                ; PREVIOUS caller had left in _conStrPtr, which put the tail of
                ; the cpu line (" MHz)") on the boot console instead of this line.
@lfb_emit       STA     _conStrPtr
                JSR     Kern_LogStr
                RTS

_msg_far_none   ASC     'far: absent',00

;==============================================================================
; _AllocKcDpSave - Kmalloc(NPROC * KC_DP_STRIDE) for the kernel-C register-file
; save table, and zero it.
;
; ON THE HEAP RATHER THAN IN THE CODE REGION.  As a DS this was 1408 bytes of a
; bank that had 1607 to spare, and the debug kernel overflowed its ceiling by
; 249 the moment main grew.  Every other table this size -- the block table, the
; device table, the cwd table -- is Kmalloc'd for exactly that reason, and this
; one had no business being different.
;
; A FAILED ALLOCATION IS NOT FATAL, deliberately.  The pointer keeps its zero
; bank, _KcDp_Slot then reports "no slot" for every task, and the context switch
; simply does not save the register file -- which is precisely the behaviour
; that existed before any of this landed.  Halting instead would turn a debug
; kernel that cannot get 1408 bytes into a machine that will not boot, and the
; boot self-test below catches the condition anyway: with no slot, its patterns
; cannot round-trip and it prints DP SAVE BROKEN -- when it is built, which
; since apple/fgx#204 is the only thing KCPROBE decides here.
_AllocKcDpSave  MX      %00
                PHP
                REP     #$30
                LDA     #CFG_KERNEL_NPROC*KC_DP_STRIDE
                LDX     #M_KERN
                JSR     Kmalloc
                BCC     @akd_out                ; leave the zero bank; see above
                LDA     _kmallocResult
                STA    |_kcDpSaveBase
                SEP     #$20
                LDA     _kmallocResult+2
                STA    |_kcDpSaveBase+2
                REP     #$20
                ; Zero it.  DS gave the old table zero-fill for free and the
                ; save/restore contract depends on it: a task resumed before it
                ; has ever entered C must restore zeros, not heap litter.
                KHEAP_USE _kcDpSaveBase
                LDY     #0
                SEP     #$20
                LDA     #0
@akd_zL         STA     [_kHeapCur],Y
                INY
                CPY     #CFG_KERNEL_NPROC*KC_DP_STRIDE
                BCC     @akd_zL
                REP     #$20
@akd_out        PLP
                RTS

; _KcProbe - run the first fcc-compiled code in the kernel, and say whether it
; came back right.
;
; This is the acceptance test for the kernel-C seam, and it is here rather than
; in a test harness because the thing being proved is a boot-time property of
; the machine: that the core can switch to FGX_DP_KERNELC, cross into the far
; bank through an export slot, and get a correct answer out of compiled C.
;
; kc_probe() builds a four-element local array, walks it through a pointer and
; sums it, so it exercises the frame base and the indirect-long slot rather
; than staying in the accumulator.  Called with 9 it must return 9*4+6 = 42.  On
; the wrong direct page those slots are the console's live state, and the sum
; comes back wrong -- which is why the value is CHECKED here instead of being
; logged for someone to read.
;==============================================================================

;==============================================================================
; _KcDp_Zero - zero FGX_DP_KERNELC, the kernel-C direct page.
;
; TWO OF fcc'S SLOTS ARE READ BEFORE THEY ARE WRITTEN: `_fcc_stkfloor' ($B9),
; which every guarded prologue COMPARES THE STACK AGAINST, and `_fcc_fb' ($BB),
; which a prologue saves before overwriting.  So the page cannot be left
; holding whatever the loader last staged through it.
;
; IT RUNS BEFORE ANY KERNEL C AND IS UNGATED, both of which are load-bearing
; (apple/fgx#225).  The far bank's first kernel C is `Con_Init' -> the font load
; -> `Fs_Open' -> ... -> `closef', which is guarded; with `_fcc_stkfloor'
; holding loader residue the prologue compares a healthy stack against fiction,
; the guard fires, and `_fcc_stkoflow' spins forever at `BRA *' with no console
; yet to say so.  The residue is whatever the loader last moved through that
; byte, so it changes with ANY change to ANY image -- which makes the symptom
; look like a layout lottery: inert padding in one bank breaks the boot, a
; three-byte edit in another fixes it, and the failing sizes are
; non-monotonic.  Behind a probe gate, a kernel built with kernel.kcprobe = 0
; would not zero the page at all.
;
; Long stores: the page is in bank 0 and DBR is the kernel bank.  MX %00.
;==============================================================================
_KcDp_Zero      MX      %00
                REP     #$30
                MX      %00
                LDA     #0
                LDX     #$00FE
@kdz_L          STAL    $000000+FGX_DP_KERNELC,X
                DEX
                DEX
                BPL     @kdz_L
                RTS

;==============================================================================
; _KcDpIrq_Zero - zero FGX_DP_KERNELC_IRQ and SEED ITS STACK FLOOR.
;
; The interrupt-time kernel-C page (apple/fgx#108 T6, include/kernelc.s
; KTTY_KC_ENTER_IRQ).  The zero is the same rule _KcDp_Zero states at length:
; `_fcc_stkfloor' ($B9) and `_fcc_fb' ($BB) are READ BEFORE THEY ARE WRITTEN, so
; the page cannot hold whatever the loader last staged through it.
;
; THE SEED IS NOT THE SAME, AND THAT IS THE POINT.  _KcDp_Zero leaves the floor
; at ZERO, and a floor of zero passes every guarded prologue -- so fcc's stack
; guard is inert everywhere kernel C runs today, which is the second finding
; docs/history/plans/tty-kernel-bank.md records under "Stage 4a".  This context has a stack
; of its own, so it can have a real floor: FGX_STK_KIRQ + FCC_STK_FLOOR_MARGIN,
; the same margin posix_spawn seeds a task's with.  An interrupt-time overflow
; therefore REPORTS through _fcc_stkoflow instead of walking down into the
; per-pid kernel stacks underneath it.
;
; The seed goes in LAST so the zero loop cannot undo it.
;
; Long stores: the page is in bank 0 and DBR is the kernel bank.  MX %00.
;==============================================================================
_KcDpIrq_Zero   MX      %00
                REP     #$30
                MX      %00
                LDA     #0
                LDX     #$00FE
@kdi_L          STAL    $000000+FGX_DP_KERNELC_IRQ,X
                DEX
                DEX
                BPL     @kdi_L
                LDA     #FGX_STK_KIRQ+FCC_STK_FLOOR_MARGIN
                STAL    $000000+FGX_DP_KERNELC_IRQ+FCC_STKFLOOR_DP
                RTS

; THE PROBE BODY IS NOT GATED, ONLY ITS CALL -- apple/fgx#204, and the tty
; bank's probes paid 108 core bytes for the same rule.  Two things went wrong when
; this block was gated, and neither was visible at the committed
; `kernel.kcprobe = 1':
;
;   `_KcDp_Zero' sits in this region and is called UNGATED from boot (~line 316,
;   where apple/fgx#225 moved it), so a `kcprobe = 0' kernel did not assemble at
;   all -- "Impossible to decode address mode for instruction `JSR _KcDp_Zero'".
;   The configuration include/kernel.s calls the SHIPPING one had been
;   unbuildable since #225's fix landed.
;
;   `_kfp340' below is a far-call patch site, and src/kernel/far_patchsites.s is
;   TRACKED.  A gated body makes that generated table differ per config, so a
;   kcprobe = 0 build then failed on `DA _kfp340+3' against a table generated
;   from a kcprobe = 1 listing.
;
; So the body always assembles and `JSR _KcProbe' is what the knob decides.
; Nothing changes at kcprobe = 1, where all of it was already being built.
_KcProbe        MX      %00
                REP     #$30
                MX      %00

                ; ---- Prove the kernel-C context save/restore round-trips. ----
                ;
                ; swtch saves this register file on every switch, but nothing in
                ; the tree yet switches BETWEEN two tasks that have both entered
                ; kernel C -- so a wrong stride or bound would stay green through
                ; every existing test and surface much later as corrupted C state
                ; in a task that did nothing wrong.  This drives the routines
                ; directly instead.
                ;
                ; TWO slots, each filled with an OFFSET-DERIVED pattern.  Both
                ; choices are load-bearing: a constant pattern passes under a
                ; wrong BOUND (the untouched tail matches anyway), and a single
                ; slot passes under any STRIDE at all.  With two, a stride that
                ; does not clear the band lets slot 1's save overwrite slot 0's
                ; tail, and the slot-0 check fails.
                ;
                ; The slots are selected by setting _curTask, NOT by passing an
                ; offset, so this drives the same slot arithmetic swtch uses
                ; rather than bypassing it.  An earlier version passed literal
                ; offsets and therefore proved only that the copy loops worked;
                ; a call site computing the wrong slot would have gone unnoticed.
                ; _kCurPid is 0 here (no task has run yet) and is put back below.
                ; It drives _KcDp_Slot, which asks who is RUNNING rather
                ; than which page it is on -- so the impersonation moved
                ; here with the selector.
                LDA     _kCurPid
                PHA
                LDA     #1
                STA     _kCurPid
                LDX     #0
@kcp_fillA      TXA
                ORA     #$A000
                STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_fillA
                JSR     _KcDp_Save              ; -> pid 1's slot

                LDA     #2
                STA     _kCurPid
                LDX     #0
@kcp_fillB      TXA
                ORA     #$B000
                STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_fillB
                JSR     _KcDp_Save              ; -> pid 2's slot

                LDX     #0                      ; scribble the live band
@kcp_scrib      LDA     #$FFFF
                STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_scrib

                LDA     #1
                STA     _kCurPid
                JSR     _KcDp_Rest              ; pid 1's slot back
                LDX     #0
@kcp_ckA        TXA
                ORA     #$A000
                CMPL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                BNE     @kcp_dpbad
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_ckA

                LDA     #2
                STA     _kCurPid
                JSR     _KcDp_Rest              ; pid 2's slot back
                LDX     #0
@kcp_ckB        TXA
                ORA     #$B000
                CMPL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                BNE     @kcp_dpbad
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_ckB
                BRA     @kcp_clean

@kcp_dpbad      LDA     #_msg_kcdp_bad
                STA     _conStrPtr
                JSR     Kern_LogStr
@kcp_clean      ; ---- Undo the test's own damage. ----
                ;
                ; The two saves above left pid 1's and pid 2's slots holding the
                ; A and B patterns.  Those slots are not scratch: the FIRST time
                ; swtch selects init, _KcDp_Rest copies that slot into the live
                ; band, patterns and all -- including _fcc_stkfloor ($B9) and
                ; _fcc_fb ($BB), the two read-before-written cells the page zero
                ; below exists to protect.  The zero loop only clears the LIVE
                ; page and never touches the table, so without this the claim in
                ; sched.s that an untouched task restores zeros is false for
                ; exactly the two pids this test used, on every boot.
                ;
                ; Nothing would notice today, because no task-context kernel C
                ; exists yet -- which is precisely the shape of failure this
                ; whole seam was built to stop: stale state restored into a
                ; shared band, surfacing in the victim rather than the culprit.
                ; Left alone it would have detonated on init's first C prologue
                ; the day 1.3 ships.
                ;
                ; Zeroing the band and re-saving through the same _curTask path
                ; puts both slots back to what DS gave every other slot.
                LDX     #0
                LDA     #0
@kcp_zsl        STAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_zsl
                LDA     #1
                STA     _kCurPid
                JSR     _KcDp_Save
                LDA     #2
                STA     _kCurPid
                JSR     _KcDp_Save

                ; ...and prove the cleanup took.  Without this the repair is
                ; exactly as unverified as the damage was: nothing else in the
                ; tree reads these slots until real kernel C exists, so a
                ; cleanup that silently did nothing would look identical to one
                ; that worked, right up until init's first C prologue.
                LDA     #1
                STA     _kCurPid
                JSR     _KcDp_Rest
                LDX     #0
@kcp_ckZ        LDAL    $000000+FGX_DP_KERNELC+KC_DP_LO,X
                BNE     @kcp_zbad
                INX
                INX
                CPX     #KC_DP_BYTES
                BCC     @kcp_ckZ
                BRA     @kcp_dpok
@kcp_zbad       LDA     #_msg_kcdp_bad
                STA     _conStrPtr
                JSR     Kern_LogStr

@kcp_dpok       PLA
                STA     _kCurPid                ; back to the boot context

                ; The kernel-C direct page is zeroed by `_KcDp_Zero', which
                ; boot runs BEFORE the first kernel C -- see that routine for
                ; why anything later is too late (apple/fgx#225).

                KC_ENTER                        ; DBR = far bank, D = kernel-C
                LDA     #9
                PHA                             ; the one argument
_kfp340         JSL     KFAR_KC_PROBE           ; slot 27; C returns via RTL
                TAY                             ; stash before the PLA eats A
                PLA                             ; caller pops its own argument
                KC_LEAVE                        ; D and DBR back

                CPY     #42
                BNE     @kcp_bad
                RTS                             ; a PASS says nothing
@kcp_bad        LDA     #_msg_kc_bad
                STA     _conStrPtr
                JSR     Kern_LogStr             ; a FAILURE is always console
                RTS

;==============================================================================
; _BufInit, _VfsInit and _VfsProbe MOVED OUT, 2026-08-12, and the seam went
; with them rather than following them.
;
; All three lived here to allocate an arena the far bank's C could not allocate
; for itself, and to hand it down through KFAR_KC_BUFINIT / KFAR_KC_VFSINIT /
; KFAR_KC_VFSPROBE.  The VFS is now vfs.mod (src/modules/vfs/), which brings
; itself up at module load: KSVC_KMALLOC gives it the heap, and the device
; table the probe scans turned out to be reachable through DIRECT PAGE cells
; (dev_table_ptr, _devPtr) rather than core-bank statics -- so nothing it does
; needs an address the kernel would have to publish.
;
; So the kernel calls nothing.  That is not a smaller version of the old seam,
; it is the absence of one, and it is why those three export slots are stubs
; again instead of forwarding.  An inward seam returns when 1.6b's namei gives
; the VFS a syscall-path customer, shaped by that customer.
;
; _KcProbe above stays: it is the FAR BANK's own kernel-C liveness check, not
; the VFS's, and slot 27 still reaches it.
;==============================================================================


_msg_kc_bad     ASC     'kernel C: WRONG ANSWER',00
_msg_kcdp_bad   ASC     'kernel C: DP SAVE BROKEN',00

;==============================================================================
; _LogDetectedHardware - emit rom/ram/cpu lines via Kern_Log*.  Split from
; _DetectHardware so it can be called after _BootScreen flips the
; kernel-log-mirror flag — that way these lines stream live to the SHR
; console as the kernel boots, matching the "dmesg-as-boot-output" idiom.
;==============================================================================
_LogDetectedHardware    MX %00
                REP     #$30
                MX      %00
                ; ONE LINE, IN THE SHAPE A BOOT LOG USES.  This was four --
                ; a banner, then `rom: $03 (ROM-03)', `ram kb: $2080 (8320 KB)'
                ; and `cpu mhz*10: $0046 (7.0 MHz)'.  Each printed the RAW
                ; value beside the decoded one, which is a developer checking a
                ; decoder rather than a machine reporting what it is; and four
                ; rows of a 24-row console is a sixth of the screen spent
                ; before the first driver speaks.
                LDA     #@dh_pfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL

                ; ---- RAM, in KB ----
                LDA    |RAMSizeKB
                JSR     Kern_LogDec16
                LDA     #@dh_ramSfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL

                ; ---- ROM revision ----
                SEP     #$20
                MX      %10
                LDA    |DetectedROM
                CMP     #$03
                BEQ     @dh_rom3
                CMP     #$01
                BEQ     @dh_rom1
                CMP     #$00
                BEQ     @dh_rom0
                REP     #$30
                MX      %00
                LDA     #@dh_romUnk
                BRA     @dh_romEmit
@dh_rom3        REP     #$30
                MX      %00
                LDA     #@dh_rom3s
                BRA     @dh_romEmit
@dh_rom1        REP     #$30
                MX      %00
                LDA     #@dh_rom1s
                BRA     @dh_romEmit
@dh_rom0        REP     #$30
                MX      %00
                LDA     #@dh_rom0s
@dh_romEmit     STA     _conStrPtr
                JSR     Kern_LogStrNoEOL

                ; ---- CPU.  CPUSpeedMHz is MHz*10, measured against the video
                ; clock by the loop in _DetectHardware: it counts iterations
                ; between VBL edges on $E0C019, so it is a RATIO of CPU cycles
                ; to field time and both come from the same clock domain.
                LDA     #@dh_cpuPfx
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |CPUSpeedMHz
                LDX     #0
@dh_cpuDiv      CMP     #10
                BCC     @dh_cpuDivDone
                SEC
                SBC     #10
                INX
                BRA     @dh_cpuDiv
@dh_cpuDivDone  PHA                             ; save frac digit
                TXA                             ; A = integer MHz
                JSR     Kern_LogDec16
                SEP     #$20
                MX      %10
                LDA     #'.'
                JSR     _kernLogPutByte
                REP     #$30
                MX      %00
                PLA                             ; A = frac (0..9)
                SEP     #$20
                MX      %10
                CLC
                ADC     #'0'
                JSR     _kernLogPutByte
                REP     #$30
                MX      %00
                LDA     #@dh_cpuSfx
                STA     _conStrPtr
                JSR     Kern_LogStr
                RTS
@dh_pfx         ASC  'fgx on Apple IIgs: ',00
@dh_ramSfx      ASC  'KB RAM, ',00
@dh_rom0s       ASC  'ROM-0',00
@dh_rom1s       ASC  'ROM-01',00
@dh_rom3s       ASC  'ROM-03',00
@dh_romUnk      ASC  'ROM-??',00
@dh_cpuPfx      ASC  ', 65816 @ ',00
@dh_cpuSfx      ASC  'MHz',00

;=============================================================================
; _MeasureCPUSpeed - Measure CPU clock speed via VBL cycle counting
;-----------------------------------------------------------------------------
; Counts 10-cycle loop iterations over one full VBL cycle (~1/60 sec).
; Stores result in CPUSpeedMHz as MHz*10 (e.g., 28 = 2.8 MHz, 160 = 16.0 MHz).
;=============================================================================
_MeasureCPUSpeed
                SEP     #$20            ; 8-bit A
                REP     #$10            ; 16-bit X/Y

                ; Sync: wait for rising edge then falling edge of VBL signal
@sync_high
                LDAL    $E0C019
                BPL     @sync_high      ; wait while bit 7 = 0
@sync_low
                LDAL    $E0C019
                BMI     @sync_low       ; wait while bit 7 = 1
                ; At falling edge (1->0)

                ; Outer loop measures full VBL cycle with amortized inner loop.
                ; Inner loop runs 198 DEY/BNE iterations in fast RAM (~989 cycles).
                ; Outer tail: LDY #198(3) + INX(2) + LDAL(5) + branch(3) = 13 cycles.
                ; Total per outer iter: ~1002 cycles, only 5 in slow memory.
                ; This amortizes the I/O access cost.

                LDX     #0

                ; Phase 1: count until rising edge (bit 7 = 1)
@outer_rise
                LDY     #198            ; 3 cycles
@inner_rise
                DEY                     ; 2
                BNE     @inner_rise     ; 3 taken / 2 fall-through (~989 cycles)
                INX                     ; 2
                LDAL    $E0C019         ; 5 (slow memory)
                BPL     @outer_rise     ; 3 taken = 13 outer tail cycles

                ; Save phase 1 count
                REP     #$20
                TXA
                STA     IterRise
                SEP     #$20
                LDX     #0

                ; Phase 2: count until next falling edge (bit 7 = 0)
@outer_fall
                LDY     #198
@inner_fall
                DEY
                BNE     @inner_fall
                INX
                LDAL    $E0C019
                BMI     @outer_fall

                REP     #$20
                TXA
                STA     IterFall

                ; X = phase 2 count; also store combined
                LDA     IterRise
                CLC
                ADC     IterFall
                STA     RawIters

                REP     #$20            ; 16-bit A

                ; Compute MHz*10 = iters * 1002 / 1667 ≈ iters * 3/5
                ; (1002/1667 = 0.6011, 3/5 = 0.6000, ~0.2% error)
                ; 16-bit safe: max iters ~39000 (too big) → use 32-bit
                LDA     RawIters
                STA     _CalcResult
                STZ     _CalcResult+2

                ; * 2
                ASL     _CalcResult
                ROL     _CalcResult+2

                ; + iters = * 3
                CLC
                LDA     _CalcResult
                ADC     RawIters
                STA     _CalcResult
                LDA     _CalcResult+2
                ADC     #0
                STA     _CalcResult+2

                ; Divide by 5
                LDX     #0
@div_loop
                LDA     _CalcResult+2
                BNE     @still_dividing
                LDA     _CalcResult
                CMP     #5
                BCC     @div_done
@still_dividing
                SEC
                LDA     _CalcResult
                SBC     #5
                STA     _CalcResult
                LDA     _CalcResult+2
                SBC     #0
                STA     _CalcResult+2
                INX
                BRA     @div_loop
@div_done
                STX     CPUSpeedMHz
                RTS

_CalcResult     DS      4

;=============================================================================
; _RAM_FloorCheck - say so and stop, rather than fail in a way nobody can read.
;-----------------------------------------------------------------------------
; MEASURED IN MAME, cold boot, no cached state (the numbers are what FGX itself
; reports, which is machine RAM plus the built-in 128 KB):
;
;   1 MB   boot never reaches a console at all -- a black hang
;   2 MB   boots, reaches a shell, and then cannot exec: bsh reports the
;          famously unhelpful "too big" for anything you type
;   3 MB   works (2176 -> 3200 KB is the step that flips it)
;   4 MB   works        8 MB   works
;
; So the floor is 3 MB, and below it the failure is silent or misleading --
; "df: too big" tells a user nothing about memory.  This is the whole point of
; the check: a machine that cannot run FGX should be told so, once, in words.
;
; It runs immediately after detection and before _LC_MapRam / Kmem_Init, i.e.
; before anything sizes itself off RAMBanks.  _BootCon_Init has already run
; (main.s above), so Kern_LogStr can be trusted here.
;
; CAVEAT, stated rather than implied: at 1 MB the hang happens before this
; point, so this cannot rescue that case -- it catches 2 MB, which is the one
; that boots far enough to look like it works.  Finding what hangs at 1 MB is
; separate work.
;=============================================================================
FGX_MIN_RAM_KB  EQU     3072                    ; 3 MB, measured (see above)

_RAM_FloorCheck MX      %00
                REP     #$30
                MX      %00
                LDA    |RAMSizeKB
                CMP     #FGX_MIN_RAM_KB
                BCS     @rfc_ok
                LDA     #@rfc_msg1
                STA     _conStrPtr
                JSR     Kern_LogStrNoEOL
                LDA    |RAMSizeKB
                JSR     Kern_LogDec16
                LDA     #@rfc_msg2
                STA     _conStrPtr
                JSR     Kern_LogStr
                JMP     _Halt
@rfc_ok         RTS

@rfc_msg1       ASC     'FATAL: FGX needs at least 3 MB of RAM.  This machine has ',00
@rfc_msg2       ASC     ' KB.  Halted.',00

;=============================================================================
; _DetectRAMSize - how much RAM is installed.  ASK THE MEMORY MANAGER.
;-----------------------------------------------------------------------------
; A WRITE/READ PROBE CANNOT ANSWER THIS, which is why the Memory Manager is
; asked instead.  Unpopulated banks ALIAS populated ones, so every bank answers
; a write/read test and a 1 MB machine sizes as 8 MB -- the ceiling of the
; technique rather than a bug in it.  (A probe also has to get the bank into
; DBR: X is SIXTEEN BITS and cannot carry one, so `(bank<<8)|$8000' indexed
; from $008000 lands in bank 1, the SHR frame buffer, which always answers.)
;
; _TotalMem is ROM-resident, documented "Errors: None", and returns the size of
; all memory including the main 256K.  Tool number $1D02: the manual's "$1002"
; is an OCR D->0 misread ($1002 is DisposeHandle) -- the same correction
; _MI_MMStats in syscall.s already carries.
;
; Out: RAMBanks, RAMSizeKB, RAMSizeMB.  Clobbers A/X; preserves P.
;=============================================================================
_DetectRAMSize
                PHP
                REP     #$30
                MX      %00
                PEA     $0000                   ; result space, high word
                PEA     $0000                   ;               low word
                LDX     #$1D02                  ; _TotalMem
                JSL     $E10000
                PLA                             ; bytes, LOW word
                STA     _drsLo
                PLA                             ; bytes, HIGH word
                STA     _drsHi

                STA     RAMBanks                ; bytes >> 16 == 64 KB banks

                ; KB = bytes >> 10 = (hi << 6) | (lo >> 10)
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _drsKB
                LDA     _drsLo
                XBA                             ; >> 8 ...
                AND     #$00FF
                LSR                             ; ... >> 2 more = >> 10
                LSR
                ORA     _drsKB
                STA     RAMSizeKB

                XBA                             ; MB = KB >> 10
                AND     #$00FF
                LSR
                LSR
                STA     RAMSizeMB
                PLP
                RTS

_drsLo          DS      2                       ; _TotalMem result, low word
_drsHi          DS      2                       ; _TotalMem result, high word
_drsKB          DS      2                       ; KB accumulator

;==============================================================================
; BOOT SCREEN (via console driver)
;
; Layout (62-col total width):
;
;    ┌──────────────────────────────────────────────────────────┐
;    │             FGX -- Flux's GS uniX -- [cCc]               │
;    └──────────────────────────────────────────────────────────┘
;
;     ROM: 03    RAM: 8192 KB    CPU: 2.8 MHz (Accelerated)
;     Build: <branch>-<sha>[+]
;
;     Volumes:
;       /              FGX               800 KB
;       /mnt/phasor    PHASOR            800 KB
;
; Box-drawing uses DEC Special Graphics via ESC ( 0 / ESC ( B.  Inside the
; box, the 30-char title is centred in the 58-char inner width (14 spaces
; pad each side).
;==============================================================================
_BootScreen
                ; Minimal boot screen: bring up the SHR console, flip the
                ; kernel-log mirror so subsequent Kern_Log* output streams,
                ; emit the boot banner.  The decorative box / ROM-RAM-CPU
                ; row / Volumes table are intentionally retired — the user
                ; now sees boot output as the kernel log streams in.
                ; (Splash with a graphic + chime will land later.)
_kfp101         JSL     KFAR_CON_INIT
                ; Replay what the ring already holds BEFORE arming the mirror.
                ; Fs_Init and Dev_Init ran ~130 lines above this, so the boot
                ; volume's own mount line and the whole SmartPort bus/unit
                ; inventory are in the ring and were never going to reach a
                ; screen.  dmesg(1) can fetch them later, but only from a
                ; shell -- and a boot that dies before init has none.
                ; Mirror is still 0 here, so the replay cannot re-enter the ring
                ; through _kernLogPutByte.  apple/fgx#111.
                JSR     Kern_LogReplay
                SEP     #$20
                MX      %10
                LDA     #$01
                STA     |_kernLogMirror         ; Wave-A: mirror flag in live bank (log.s reads it DBR-rel)
                REP     #$20
                MX      %00
                ; Banner — first line on the live console.  The build version
                ; is NOT embedded here: a git-state-variable string in the
                ; kernel binary would shift the layout that the listing-scraped
                ; W5100 offset tables (w5100_patchsites.s) depend on.  The
                ; version lives on disk in /etc/version instead ('uname -r').
                ; NO BANNER.  `fgx kernel booting' said only that something
                ; was running, which the next line says better by naming the
                ; machine it is running on -- _LogDetectedHardware's summary is
                ; the first line of the log now.
                RTS

_PutStr
                LDY     #0
@ps_L           SEP     #$20
                LDA     (_conStrPtr),Y
                REP     #$20
                AND     #$00FF
                BEQ     @ps_done
                PHY
_kfp102         JSL     KFAR_CON_WRITE          ; via VT parser — honours ESC seqs
                PLY
                INY
                BRA     @ps_L
@ps_done        RTS

;==============================================================================
; DATA SECTION
;==============================================================================

                PUT     log.s
                PUT     boot_console.s
                PUT     jumptable.s
                PUT     modload.s
                PUT     net_dispatch.s
                PUT     chardev.s
                ; The block driver's CHARACTER face, /dev/rsd0..rsd7.  In
                ; THIS segment rather than beside block.s in segment #2
                ; because it calls _Chardev_RegisterInternal and
                ; _FarSh_Uiomove, both of which live here, while Blk_Read
                ; and Blk_Write are already EXT above.  Same bank either
                ; way; the split is Merlin's, not the design's.
                PUT     ../drivers/block/rawdisk.s
                PUT     sim.s
                PUT     uthernet.s
                PUT     bpf.s
                PUT     ifconfig_sys.s
                PUT     socket.s
                PUT     pipe.s
                PUT     net_loop.s
                PUT     unp.s

                PUT     ../drivers/dev/dev.s

                PUT     ../drivers/ramdisk/ramdisk.s

                PUT     ../drivers/fs/fcb.s
                PUT     ../drivers/fs/fs.s

                PUT     ../kernel/bank.s
                PUT     ../kernel/toolbox.s
                PUT     ../kernel/syscall.s
                PUT     ../kernel/task.s
                PUT     ../kernel/sched.s
                PUT     ../kernel/process.s
                PUT     ../kernel/signal.s
                PUT     ../kernel/pty.s
                PUT     ../kernel/ttyv.s        ; slice D: virtual console lines
                PUT     ../kernel/tty_tty.s     ; /dev/tty: the indirect driver

                PUT     ../kernel/wavee_bankpatch.s             ; GENERATED: $02->live-kernel-bank self-mod table
                PUT     ../kernel/w5100_patchsites.s            ; GENERATED: W5100 U2_* slot-bind self-mod table
                PUT     ../kernel/far_shims.s                   ; RTL entry points for far-bank callers
                PUT     ../kernel/far_patchsites.s              ; GENERATED: core->far JSL bank-byte sites
                PUT     ../kernel/tty_patchsites.s              ; GENERATED: core->tty JSL bank-byte sites
                PUT     ../kernel/libc/str.s
                PUT     ../kernel/libc/alloc_state.s
                PUT     ../kernel/libc/alloc.s
                ; GENERATED: _kernBuildId, the two-byte core build identity
                ; _JT_Init publishes at MOD_JT_CORE_BUILD.  LAST, deliberately:
                ; it sums kernel labels, and here every one of them is already
                ; defined, so the expression is all backward references.
                PUT     ../kernel/kernel_build_id.s

; Static kernel state (DetectedROM, ROMVersion, shell buffers, VT state, ...)
; is declared in include/memmap.s via a DUM/DEND block — this segment emits
; no data bytes for them.  Each owning subsystem's Init routine zero-fills
; its own region at boot (see FGX_Entry's call to _KMem_ClearGlobals).

; Assembly-time size guards:
;   Tight guard: kernel binary must end before FGX_DATA ($028000).  The DUM
;   block in memmap.s assigns static-data labels starting at FGX_DATA; any
;   kernel bytes at or past $028000 get clobbered at boot when each subsystem's
;   Init zero-fills its region (Con_Init's _ZeroBankRegion CON_VT_STATE etc.).
;   Overrunning this limit crashes at boot, not build, unless caught here.
                ERR     *-1/FGX_DATA
;   Loose guard: loader's MVN copies up to FGX_DATA - FGX_CODE bytes (today
;   44 KB; loader.s caps at 176 iter × 256 = $B000).  The tight guard above
;   already enforces this same boundary, so no second check is needed.

;==============================================================================
; END OF FILE
;==============================================================================


;==============================================================================
; _Shadow_InhibitUnused - stop paying the shadowed-write penalty on display
; regions FGX never displays.
;
; A write to a shadowed bank-0 range is mirrored into the Mega II bank and the
; STORE is stretched to 1.024 MHz (reads stay at 2.8).  $C035's bits are
; active-high INHIBITS and are CLEARED ON RESET, so the machine boots
; shadowing everything and FGX has never said otherwise -- measured $C035=$20.
;
; FGX renders to a scanline framebuffer via bank $01 and never shows text page
; 1 or either hi-res page, so shadowing them buys nothing and costs a stretched
; cycle on every store that lands there.  Two regions pay it today:
;   - $0400-$07FF, text page 1: the low bank-0 space the assessment wants back;
;   - $2000-$5FFF, hi-res 1 and 2: INSIDE the user-stack arena (FGX_STK_ARENA,
;     include/kernel.s), so 64 of its pages would stretch every push.
;
; BIT 3 (super hi-res) IS DELIBERATELY LEFT CLEAR.  The framebuffer lives in
; bank $01 and reaches the screen precisely BY being shadowed to $E1; inhibiting
; it would blank the display.  Bit 6 (I/O + language card) likewise stays clear:
; setting it would take the slot ROM the block driver calls on every disk I/O.
;
; READ-MODIFY-WRITE, never a blind store -- a blind store clears bit 6 and the
; machine dies.  The address form is $E0C035, where I/O is live regardless of
; shadowing, matching _DetectHardware's existing $E0C082 usage.
;==============================================================================
SHADOW_INHIBIT  EQU     $07             ; bits 0,1,2 = text pg1, hi-res 1, 2

_Shadow_InhibitUnused MX %00
                PHP
                SEP     #$30
                MX      %11
                LDAL    $E0C035
                ORA     #SHADOW_INHIBIT
                STAL    $E0C035
                PLP
                RTS


;==============================================================================
; _LC_MapRam - map bank-0 language-card RAM, read AND write, and leave it.
;
; $00:D000-$FFFF is 16 KB of bank-0 RAM behind the $C08x switches: two
; bank-switched 4 KB blocks at $D000 and a flat 8 KB above them.  Measured on
; real hardware, and the full suite runs with it mapped
; (docs/history/audits/bank0-lc-spike-results.md).  The per-pid kernel stacks live in the flat
; 8 KB, so this has to be in effect before the first task exists -- the
; dispatcher switches to FGX_STK_KTASKS+(pid<<8) on the first syscall a task
; makes, and before that it uses the static FGX_STK_KERNEL at $0100.
;
; ORDERING.  This must run AFTER _DetectHardware, which deliberately forces ROM
; in ($E0C082, twice) so $00FE1F reaches the firmware identification routine.
; Mapping RAM earlier would be undone by it, and calling the ROM later would
; need the state saved and restored around the call -- there is no such call
; after this point.
;
; WRITE-ENABLE NEEDS TWO CONSECUTIVE READS of the same switch.  That is a
; hardware requirement, not a superstition: one read selects RAM for reading,
; and the second sets the write-enable flip-flop.  $C08B is "read RAM,
; write-enable, $D000 bank 1".  A userland version of this was attempted and
; abandoned -- fcc stages every far access through a pointer slot, so the two
; reads come out a dozen instructions apart and only the read-select takes.
;
; INTERRUPTS ARE NOT A HAZARD HERE.  With I/O shadowing on, the processor pulls
; its vectors from the bank-$FF ROM image and the ROM interrupt entry stub sits
; at $C071 in the soft-switch space, which the $C08x switches do not touch.  So
; an interrupt taken with language-card RAM mapped dispatches ROM -> $Cxxx ->
; bank $E1 -> the kernel's own hook without ever executing $00:D000-$FFFF.
;==============================================================================
_LC_MapRam      MX      %00
                PHP
                SEP     #$30
                MX      %11
                LDAL    $E0C08B                 ; read RAM, write-enable, bank 1
                LDAL    $E0C08B                 ; ...twice: the write-enable
                PLP
                RTS
