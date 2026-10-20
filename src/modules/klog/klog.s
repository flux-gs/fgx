;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
;
; FGX-Provenance: 2.11BSD klog(4)
;   Ported from usr/sys/sys/subr_log.c, 2.11BSD.  Original work:
;   Copyright (c) 1982, 1986 Regents of the University of California.
;   All rights reserved.
;
; klog.s - FGXM module: /dev/klog, a cursored read-only view of the kernel log
; ring, so syslogd can merge kernel messages with the user messages it reads
; from /dev/log.
;
; Port of vendor/2.11BSD/usr/sys/sys/subr_log.c (2.1, 1999/4/29): logopen,
; logclose, logread, logselect, logioctl.  Upstream's msgbuf carries its own
; read pointer; FGX's ring does not (only a write index and a wrapped flag, both
; in include/memmap.s), so the cursor lives beside them and this module owns it.
;
; SYS_DMESG AND dmesg(1) ARE UNTOUCHED.  They copy the whole ring out and do not
; consume it; this is a second, independent reader with its own position.
;
; A MODULE AND NOT CORE-BANK CODE, and that is a budget fact rather than a
; preference: the core kernel bank has five bytes free, and the chardev registry
; already exists, so a module costs no new dispatch code.  What the module needs
; from the core bank is only ADDRESSES, imported through the generated
; kernel_exports.s.
;
; Each op is entered by JSL from _Chardev_Dispatch with DBR = the KERNEL's bank
; and the RUNNING TASK'S kernel slot page in D -- ENTERK establishes it from
; KFGX_CUR_KDP in the shim that reaches _Chardev_Bulk -- and returns by RTL with
; MX %00.  That is why the ring state and this module's cursor are plain
; absolutes here and why [_kLogBufPtr],Y and [_libcTmp2],Y work unchanged: the
; first is DBR-relative, the second two are DP-indirect-long and so
; bank-independent.  Nothing in this file touches a static in its OWN bank
; outside mod_init, which is the only routine that runs with DBR = our bank.
;==============================================================================

                MX      %11
                ; Modules stack into one shared bank; MODP_ORG is this module's
                ; offset in it, derived at build time from the measured sizes of
                ; the modules placed before it.  Module code is ORG-dependent.
                PUT     modplace.s
                ORG     MODP_ORG

;------------------------------------------------------------------------------
; MOD_JT_BASE, MOD_REGISTERCHARDEV, SYS_KCALL and SYS_MODLOG all come from
; include/modules.s below, which is also where the KSVC_* service numbers are.
; Declaring them here as well is what most modules do, and it is four constants
; that would then have two definitions to drift apart -- Merlin32 refuses the
; duplicate outright, which is the better outcome.
;------------------------------------------------------------------------------
                PUT     ../../../include/config.s       ; CFG_DP_KERNELC, which
                                                        ;   FGX_DP_KERNELC is
                PUT     ../../../include/devnodes.s     ; DEVNODE_KLOG
                PUT     ../../../include/errno.s
                PUT     ../../../include/chardev.s      ; CDF_*, COPS_*, POLL*
                PUT     ../../../include/modules.s      ; KSVC_SLEEP
                PUT     ../../../include/kernel.s       ; WCHAN_LBOLT,
                                                        ;   KMEM_LOGBUF_SIZE
                PUT     ../../../include/socket.s       ; FIONBIO
                PUT     ../../../include/fs.s           ; FCB_CdFlags, FCB_CDF_NONBLK
                PUT     ../../../include/vfs_equ.s      ; VFS_IO_NDELAY
                PUT     ../../../include/dpmap.s        ; _kLogBufPtr, _libcTmp2
                ; The ring's write index and wrapped flag, this module's
                ; cursor, and vfs.mod's resolved uiomove -- every one an ADDRESS
                ; scraped out of the kernel listing, so none of them is a
                ; constant copied into this file.  The ring's SIZE is a value
                ; rather than an address and comes from logring.s above.
                PUT     kernel_exports.s

                MX      %00

;------------------------------------------------------------------------------
; FGXM header v2 (40 bytes).  First bytes in the image, at MODP_ORG.
;------------------------------------------------------------------------------
; BSS bytes the loader zero-fills after the text.  ONE symbol, named by the
; header field AND by the placement ceiling guard at the tail, so a module that
; grows real bss cannot outgrow the bank past a guard that measured only text.
; This module has none: its state is the kernel-bank cursor cells.
klog_bss        EQU     0

klog_hdr        ASC     'FGXM'                          ; +0  magic
                DFB     <MODP_ORG                       ; +4  load lo
                DFB     >MODP_ORG                       ; +5  load mid
                DFB     ^MODP_ORG                       ; +6  load hi
                DFB     $02                             ; +7  header format version
                DA      mod_init-$050000                ; +8  entry offset
                DA      klog_end-klog_text              ; +10 text bytes
                DA      klog_bss                        ; +12 bss bytes
                DA      klog_vtdir-klog_text            ; +14 vtdir offset
klog_modname    ASC     'klog'                          ; +16 module name
                DS      16-*+klog_modname               ;     NUL-pad to 16 bytes
                DA      $0000                           ; +32 module version (reserved)
                ; +34 kernel build identity, from the generated kernel_exports.s.
                ; Mod_Load refuses this module if the running kernel published a
                ; different one -- every kernel address baked in below would
                ; point at the wrong byte.
                DA      KERN_BUILD_ID
                DS      4                               ; +36 reserved (deps/flags)

klog_text       EQU     *

;------------------------------------------------------------------------------
; VTDR sentinel + VT_END terminator.  The chardev is registered imperatively in
; mod_init through MOD_REGISTERCHARDEV, not through a VT_CHARDEV directory entry.
;------------------------------------------------------------------------------
klog_vtdir      ASC     'VTDR'
                DA      $0000                           ; VT_END

;==============================================================================
; mod_init - MX %00 entry, DBR = kernel bank.  Set the cursor state FIRST while
; the kernel bank is still addressable, then take DBR for the ops-table
; self-patch, then register /dev/klog.
;
; THE STATE IS SET HERE RATHER THAN LEFT TO _KMem_ClearGlobals, so that this
; module does not depend on where its cells happen to fall relative to
; KMem_KGlobals.
;
; THE CURSOR IS SEEDED ONCE, HERE, AND NEVER BY AN OPEN.  2.11BSD's logopen
; (sys/subr_log.c) never touches msg_bufr, which starts at 0 and only logread
; moves: the first reader after boot gets everything since boot, and a reader
; that closes and reopens -- a restarted syslogd -- resumes where the last one
; stopped instead of replaying the boot log onto root's console
; (apple/fgx#484).  The seed is the oldest byte that exists: 0 before the ring
; has wrapped, the write index once it has, where a cursor reads as caught up
; and the history stays visible through dmesg(1).
;==============================================================================
mod_init        MX      %00
                SEP     #$20
                MX      %10
                LDA     #$00
                STA     |_klogOpen
                LDA     |_kernLogWrap
                REP     #$30
                MX      %00
                AND     #$00FF
                BEQ     @mi_rdZero              ; never wrapped: 0 is the oldest
                LDA     _kernLogHead            ; wrapped: the oldest byte is at
                STA     _klogRd                 ;   the write index
                BRA     @mi_rdSet
@mi_rdZero      STZ     _klogRd
@mi_rdSet
                ; FIND uiomove WHILE DBR IS STILL THE KERNEL'S, which is where
                ; the three statics it touches live.  A failed resolve is NOT
                ; fatal: it leaves _klogVfsBank zero and the bulk read answers
                ; ENXIO, so a machine with no vfs.mod still boots and still
                ; registers the node.
                JSR     _Klog_ResolveVfs

                PHK
                PLB                             ; DBR = our bank

                ; Self-patch the ops-table bank bytes (serial.mod's @mi_spL).
                ; SEP #$30 and not #$20: the LDX below assembles per MX %11, so
                ; X must be 8-bit at runtime too.
                SEP     #$30
                MX      %11
                PHK
                PLA                             ; A = our bank
                LDX     #2
@mi_spL         STA:    klog_ops,X
                INX
                INX
                INX
                CPX     #21                     ; 7 filled slots x 3 B
                BCC     @mi_spL
                REP     #$30
                MX      %00

                ; --- Register /dev/klog ---
                ;   A = name offset, X = ops offset, Y.lo = minor,
                ;   Y.hi = CD_Flags with the device NUMBER in bits 2-7.
                ;
                ; CDF_RECORD: one read(2) is one transfer of up to the caller's
                ; whole buffer, not a per-byte loop through the dispatcher.  A
                ; 4 KB ring drained a byte at a time would be 4096 round trips.
                ; CDF_FIXED: the number is the build's, never the load order --
                ; a machine whose control panel gives a slot to a card shifts
                ; every registration after it.
                LDA     #klog_name
                LDX     #klog_ops
                LDY     #{{CDF_RECORD+CDF_FIXED+{DEVNODE_KLOG*4}}*256}+0
                JSL     MOD_REGISTERCHARDEV
                BCS     @mi_regOK
                LDX     #regfail_msg
                JSL     SYS_MODLOG
                BRA     @mi_regDone
@mi_regOK       LDX     #regok_msg
                JSL     SYS_MODLOG
@mi_regDone
                SEC                             ; success
                RTL

;==============================================================================
; _Klog_ResolveVfs - vfs.mod's bank and the address of its uiomove.
;
; Entered from mod_init with DBR = the KERNEL bank, which is where both statics
; live and where every op in this module runs.
;
; ONE ENTRY, NOT THE WHOLE VTABLE: this module calls exactly one of them.  The
; read is the cross-bank shape ufs.mod's loop uses -- DBR to vfs.mod, read, DBR
; back, store -- because the source is in vfs.mod's bank, the destination is not,
; and a module has no direct page to put a long pointer in.
;
; DBR COMES BACK VIA PHB/PLB, NOT PHK/PLB.  The bank this wants back is the
; KERNEL's; PHK would leave DBR on klog.mod, where both statics below would read
; as whatever this module happens to hold at that offset.
;
; THE BANK IS STORED LAST, because it is the resolved FLAG.  Storing it first
; would advertise a resolve the slot read had not yet completed.
;==============================================================================
_Klog_ResolveVfs MX     %00
                LDA     #VT_VFSCORE
                LDX     #KSVC_FINDVTABLE
                JSL     SYS_KCALL
                BCS     @rv_have
                RTS                             ; no vfs.mod; the flag stays 0
@rv_have        ; A = the table's bank-relative address, X.lo = its bank.
                CLC
                ADC     #VFSCORE_Uiomove        ; the one slot we import
                TAY                             ; Y = its offset in that bank
                PHB                             ; the kernel bank, to come back
                SEP     #$20
                MX      %10
                TXA                             ; X.lo = vfs.mod's bank
                PHA
                PLB                             ; DBR = vfs.mod
                REP     #$30
                MX      %00
                LDA     |$0000,Y                ; uiomove's offset, from there.
                                                ;   `|' IS LOAD-BEARING: without
                                                ;   it Merlin shortens a $0000
                                                ;   operand to the DIRECT PAGE
                                                ;   form and reads fcc's register
                                                ;   file instead, with no warning
                                                ;   and a plausible 16-bit result.
                PLB                             ; DBR = the kernel bank again
                STA     |_klogVfsUiomove
                TXA
                AND     #$00FF
                STA     |_klogVfsBank           ; LAST: this is the flag
                RTS

;==============================================================================
; _Klog_Avail - how many bytes this reader has not taken yet.
;
; Out: A = count, 0 meaning caught up.  Clobbers A and flags only.
;
;   avail = (head - rd) mod KMEM_LOGBUF_SIZE
;
; `rd == head' IS EMPTY, which is upstream's own rule: "If the reader and writer
; are equal then we have caught up and there is nothing more to transfer."
;
; A LAPPED READER CANNOT BE DETECTED HERE, and saying so is better than a check
; that cannot fire.  The writer never consults a reader -- it cannot afford to,
; which is the same five-bytes-free fact that put this driver in a module -- and
; the ring carries no generation count, only a write index and a one-shot
; wrapped flag.  So when the writer laps this cursor the distance above stays a
; legal value and the reader silently gets the NEWEST avail bytes, in order,
; having lost the ones in between.  Upstream counts that in sc_overrun because
; upstream's writer is the one that discards.  A lap takes 4 KB of kernel log
; inside one WCHAN_LBOLT tick.  klog(4)'s BUGS says this; apple/fgx#461 carries
; the writer-side question.
;==============================================================================
_Klog_Avail     MX      %00
                LDA     _kernLogHead
                SEC
                SBC     _klogRd
                BCS     @ka_done                ; head >= rd: the plain distance
                CLC
                ADC     #KMEM_LOGBUF_SIZE       ; head behind rd: round the ring
@ka_done        RTS

;==============================================================================
; CharDev_Ops.  DBR = kernel bank + kernel DP on entry; each RTLs.
;==============================================================================

;------------------------------------------------------------------------------
; klog_open - open("/dev/klog").
;   In:  Y = minor, X = flag.
;   Out: C=1 ok; C=0 + A = ENXIO with no ring yet, EBUSY if already open.
;
; ENXIO BEFORE _AllocLogBuf HAS RUN.  _kLogBufPtr's bank byte is the guard the
; ring writer itself uses (Kern_LogInit leaves it zero until the allocator is
; up), and it is upstream's ENOMEM case -- "no buffer allocated" -- under the
; errno a chardev with no device behind it answers here.
;
; ONE READER, which is upstream's EBUSY in logopen.  Two readers would share one
; cursor, so each would see an arbitrary half of the log and neither would see
; it all.
;
; THE CURSOR IS NOT TOUCHED HERE.  mod_init seeded it once; an open resumes
; wherever the last reader stopped, as upstream's logopen leaves msg_bufr alone.
; A reader that was away while the writer lapped it cannot be told apart from
; one that is caught up (see _Klog_Avail), so it gets the newest bytes in order.
;------------------------------------------------------------------------------
klog_open       MX      %00
                SEP     #$20
                MX      %10
                LDA     _kLogBufPtr+2           ; ring allocated? (bank byte)
                BNE     @ko_haveRing
                REP     #$30
                MX      %00
                LDA     #ENXIO
                CLC
                RTL
                ; MX %10 AT THE LABEL, and it is not decoration.  The arm above
                ; ends with an `MX %00' directive, so the assembler's idea of the
                ; widths here would be 16-bit while the CPU still has A narrow
                ; from the SEP at entry -- and `LDA #$01' below would assemble a
                ; TWO-byte immediate whose second byte the CPU then executes as
                ; BRK.  That is a black screen, not a wrong answer.
@ko_haveRing    MX      %10
                LDA     |_klogOpen
                BEQ     @ko_free
                REP     #$30
                MX      %00
                LDA     #EBUSY
                CLC
                RTL
@ko_free        MX      %10
                LDA     #$01
                STA     |_klogOpen
                REP     #$30
                MX      %00
                SEC
                RTL

;------------------------------------------------------------------------------
; klog_close - the LAST close of /dev/klog (the registry ref-counts opens and
; only calls this on the final one, matching BSD closei).  Upstream's logclose
; clears the whole softc, and msg_bufr is not in the softc: the cursor stays
; where this reader left it, for the next open to resume from.
;------------------------------------------------------------------------------
klog_close      MX      %00
                SEP     #$20
                MX      %10
                LDA     #$00
                STA     |_klogOpen
                REP     #$30
                MX      %00
                SEC
                RTL

;------------------------------------------------------------------------------
; klog_getc - the PER-BYTE read slot, which this device does not serve.
;
; EIO IS THE RIGHT REFUSAL AND IT IS THE KERNEL'S OWN.  chardev.s answers EIO for
; "a driver that cannot serve this road" and cites `_PtyS_Read' doing the same.
; A zero slot would be worse than a refusal: _Chardev_Dispatch is documented as
; not bounds-checked and would JSL through it into offset 0 of this bank.
;
; Nothing should reach it.  CDF_RECORD is what tells the kernel not to fall back
; to a per-byte loop, and the bulk op below is what a record device must have.
;------------------------------------------------------------------------------
klog_getc       MX      %00
                LDA     #EIO
                CLC
                RTL

;------------------------------------------------------------------------------
; _Klog_Uio - one uiomove(cp, n, uio) from this module's assembly, moving bytes
; straight out of the ring.
;
; In:  A = n; the uio far pointer already staged in _libcTmp2 by the caller;
;      _klogRd the ring offset to start at.
; Out: A = uiomove's errno, 0 on success.  X, Y clobbered.
;
; cp NAMES THE HEAP, NOT THE KERNEL BANK.  _Pty_Uio1 pushes `PHB' for its cp bank
; because a pty's ring is a kernel static; this ring is Kmalloc'd at boot and
; reached through the _kLogBufPtr long pointer, so the bank comes from there.
;
; NO STAGING BUFFER, which is upstream's shape once its reason is removed:
; logread bcopies through a `char buf[ctob(2)]' because a PDP-11 has to map the
; buffer's segment in to touch it.  Nothing here has to -- the ring is a
; contiguous array this bank can address -- so the bytes go to uiomove where they
; lie, and the two runs upstream needs for a wrap are the caller's loop.
;
; THE SAVED DBR AND D GO ON *BELOW* THE ARGUMENTS.  uiomove reads them at 4,S
; above its own return address, so one stray byte between the frame and the call
; shifts every argument.
;------------------------------------------------------------------------------
_Klog_Uio       MX      %00
                TAY                             ; n, which survives the pushes
                PHB                             ; the kernel bank, for the exit
                PHD                             ; the kernel page, likewise

                ; --- the ten argument bytes, LAST argument first, so they land
                ;     arg1-lowest the way fcc pushes them --------------------
                LDA     _libcTmp2+2
                AND     #$00FF
                PHA                             ; uio bank
                LDA     _libcTmp2
                PHA                             ; uio offset
                TYA
                PHA                             ; n
                LDA     _kLogBufPtr+2
                AND     #$00FF
                PHA                             ; cp bank -- the heap's
                LDA     _kLogBufPtr
                CLC
                ADC     |_klogRd
                PHA                             ; cp offset -- the cursor's byte

                LDA     |_klogVfsUiomove        ; the target, read while DBR is
                TAX                             ;   still ours
                LDA     #FGX_DP_KERNELC
                TCD                             ; fcc's register file, for C
                SEP     #$20
                MX      %10
                LDA     |_klogVfsBank
                PHA
                PLB                             ; DBR = vfs.mod.  NET ZERO.
                REP     #$30
                MX      %00
                PHK                             ; klogret_uio is in OUR bank
                PEA     klogret_uio-1
                PHB                             ; target bank: DBR is vfs.mod's
                TXA
                DEC     A
                PHA                             ; target - 1
                RTL                             ; PILECALL
klogret_uio     TAY                             ; park the errno
                TSC
                CLC
                ADC     #10                     ; drop the argument frame
                TCS
                PLD                             ; the kernel page back...
                PLB                             ; ...and the kernel bank
                TYA
                RTS

;------------------------------------------------------------------------------
; klog_dread - cdevsw's d_read, and the port of 2.11BSD's `logread'
; (vendor/2.11BSD/usr/sys/sys/subr_log.c).
;
; In:  Y = minor, from the dispatcher.  A frame this routine reads directly:
;        9,S uio offset   11,S uio bank   13,S flag
;      Eight bytes of return address sit above it -- _Chardev_Bulk's JSR into
;      _Chardev_Dispatch (2), the dispatch's JSL through the bank-0 gateway cell
;      (3), and that cell's own JSL (3).
; Out: C=1 + A = 0 on success, C=0 + A = errno.
;
; THIS AND NOT THE RECORD SLOT, because a /dev node's read reaches spec_chread,
; which tries the bulk op FIRST and refuses a record device that has none:
; `bpf_read' fills from _Sys_RdBufOff / _Sys_RdMax / _Sys_CallerBank, syscall
; singletons no vnode caller sets, and on that route they name whatever the last
; read(2) named -- apple/fgx#198's silent half.  Reno's VCHR arm is one
; unconditional `(*cdevsw[].d_read)(dev, uio, ioflag)' (kern/spec_vnops.c:178),
; so the uio is where a driver on this road takes its buffer from.
;
; THE FRAME IS RE-READ FROM THE STACK RATHER THAN CACHED, and that is the whole
; reason it travels on a stack at all: this op SLEEPS, and the stack it sleeps on
; is the task's own kernel stack, restored with S when it resumes.  A static
; would be one task's answer handed to another (apple/fgx#89).  It is also why
; there is no saved-flag cell here: Reno takes it from the argument too --
; `if (flag & IO_NDELAY) return (EWOULDBLOCK)'.
;
; THE LOOP IS UPSTREAM'S.  logread waits once while the reader and writer are
; equal, then runs `while (uio->uio_resid)' transferring what it can and
; wrapping the cursor when it reaches the end -- `if (l == 0) { msg_bufr = 0;
; continue; }'.  uio_resid is re-read from the uio each pass because uiomove is
; what decrements it, exactly as upstream's condition re-reads it.
;
; THE BUDGET IS uio_resid AND IT BOUNDS EVERY RUN.  uiomove clamps to resid and
; DISCARDS the excess, so a driver that offers more than the caller can take
; loses those bytes off the ring -- and here that would be log nobody can ever
; read again.  Reno bounds the same way (`cc = MIN(uio->uio_resid, sizeof buf)').
;------------------------------------------------------------------------------
klog_dread      MX      %00
                LDA     |_klogVfsBank           ; did mod_init find uiomove?
                AND     #$00FF
                BNE     @dr_wait
                LDA     #ENXIO                  ; no vfs.mod: cannot move bytes
                CLC
                RTL

                ; `while (mp->msg_bufr == mp->msg_bufx)' -- wait for anything at
                ; all before transferring, which is the only place this blocks.
@dr_wait        ; UNDER SEI, AND THAT IS `_sleep''s CALLER CONTRACT rather than
                ; caution: "the caller must re-test its wait condition under SEI
                ; (spl) and only then call _sleep, to avoid a lost wakeup (an ISR
                ; delivering the event between the test and the BLOCKED mark)"
                ; -- src/kernel/sched.s, at _sleep.  The ISR in that sentence is
                ; real here: the ring is filled by kernel log calls, the
                ; heartbeat's included.  Today a lost wakeup costs a second and
                ; not a hang, because lbolt fires whether or not anyone signalled
                ; it; apple/fgx#461's writer-side wakeup is what would make it a
                ; lost wakeup proper.  `_PtyM_DRead' masks at the same point.
                ;
                ; What the mask has to cover is only "nothing arrived between my
                ; test and my sleep", and the writer's index answers that: it is
                ; read before the test and compared again under SEI, and a
                ; writer that moved meanwhile sends the wait round again
                ; instead of to sleep.
                LDA     _kernLogHead
                PHA                             ; the index the test will see
                JSR     _Klog_Avail
                CMP     #$0000
                BEQ     @dr_none
                PLA
                BRA     @dr_have                ; data: no sleep, no mask
@dr_none        SEI
                PLA
                CMP     _kernLogHead
                BEQ     @dr_still
                CLI                             ; the writer moved: look again
                BRA     @dr_wait
@dr_still       LDA     13,S                    ; the op's own `flag'
                AND     #VFS_IO_NDELAY
                BNE     @dr_again
                ; WCHAN_LBOLT AND NOT A CHANNEL OF OUR OWN.  include/kernel.s
                ; names it "the channel a caller sleeps on to mean WAIT A BIT AND
                ; TRY AGAIN", after 2.11BSD's ttwrite and ufs_alloc.c, and the
                ; clock fires it once a second whether or not anything is
                ; runnable.  Upstream is woken by the writer instead; that is a
                ; flag test and a _wakeup in core-bank code with five bytes free,
                ; so apple/fgx#461 carries the question.  The cost is up to a
                ; second of latency, never a lost message.
                LDA     #WCHAN_LBOLT
                LDX     #KSVC_SLEEP
                JSL     SYS_KCALL               ; carry always set; verdict in A
                REP     #$30                    ; _sleep may return 8-bit
                MX      %00
                LSR     A                       ; A=1 -> C=1 interrupted
                BCS     @dr_intr
                BRA     @dr_wait
                ; Interrupted.  NOT re-entering the wait is apple/fgx#28: the
                ; sleep returns C=1 WITHOUT blocking while the signal stays
                ; pending, so a loop here spins at full speed and the syscall
                ; that must return to let the handler run never does.
@dr_intr        LDA     #EINTR                  ; IRQs are already open: the
                CLC                             ;   sleep CLIs on the way out
                RTL
@dr_again       CLI                             ; refused under the mask
                LDA     #EAGAIN                 ; Reno's EWOULDBLOCK
                CLC
                RTL
@dr_have        ; --- stage the uio, once, for every uiomove below -----------
                LDA     9,S
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     11,S
                STA     _libcTmp2+2
                REP     #$30
                MX      %00

                ; THE FRAME ASSERTION.  A d_read is by definition handed a READ
                ; uio, so uio_rw names the frame: get these offsets wrong and
                ; _libcTmp2 is a wild pointer, which almost certainly does not
                ; read as 0 here.
                LDY     #UIO_RW
                LDA     [_libcTmp2],Y
                BEQ     @dr_loop
                LDA     #EINVAL
                CLC
                RTL

@dr_loop        LDY     #UIO_RESID
                LDA     [_libcTmp2],Y
                BEQ     @dr_done                ; the caller's budget is spent
                PHA                             ; 1,S = resid
                JSR     _Klog_Avail             ; the unread run
                CMP     #$0000
                BEQ     @dr_dropDone            ; caught up: stop here
                PHA                             ; 1,S = avail, 3,S = resid
                LDA     #KMEM_LOGBUF_SIZE
                SEC
                SBC     |_klogRd                ; bytes to the ring's end
                CMP     1,S
                BCC     @dr_cap1                ; the end is nearer than avail
                LDA     1,S
@dr_cap1        CMP     3,S
                BCC     @dr_cap2                ; ...and does the budget bind?
                LDA     3,S
@dr_cap2        PLX                             ; drop avail
                PLX                             ; drop resid
                PHA                             ; 1,S = the run, wanted after
                JSR     _Klog_Uio               ; A = n in, A = errno out
                CMP     #$0000
                BNE     @dr_errDrop
                PLA                             ; the run
                CLC
                ADC     |_klogRd
                CMP     #KMEM_LOGBUF_SIZE
                BCC     @dr_noWrap              ; `if (l == 0) msg_bufr = 0'
                LDA     #$0000
@dr_noWrap      STA     |_klogRd
                BRA     @dr_loop

@dr_errDrop     PLX                             ; drop the run
                CLC                             ; uiomove's errno is in A
                RTL
@dr_dropDone    PLX                             ; drop resid
@dr_done        LDA     #0                      ; what was moved is in the uio;
                SEC                             ;   0 is success, as Reno returns
                RTL

;------------------------------------------------------------------------------
; klog_write - /dev/klog is read-only.  Upstream has no log write entry point at
; all; the kernel reaches its ring through logwrt, which is not a driver op.
;------------------------------------------------------------------------------
klog_write      MX      %00
                LDA     #ENOTSUP
                CLC
                RTL

;------------------------------------------------------------------------------
; klog_ioctl - FIONBIO only.
;   In:  Y = minor, X = flag; the command and its argument are in the
;        _Sys_Ioctl* statics.
;
; FIONBIO IS HERE SO THAT THE NDELAY BRANCH IN klog_read CAN BE REACHED.  There
; is no generic kernel-side FIONBIO for a chardev -- only a module's own ioctl
; can set FCB_CDF_NONBLK -- so without this the read would always block and its
; EAGAIN arm would be code no test could ever execute.  [_fcbPtr] is trustworthy
; here: an ioctl has not slept, so it still names the descriptor the caller
; passed (the window apple/fgx#198 is about opens only after a sleep).
;
; Upstream also has FIOASYNC, TIOCSPGRP/TIOCGPGRP and FIONREAD.  They are left
; out because the only consumer does not use them: syslogd opens /dev/klog
; O_RDONLY, puts it in a select(2) mask and read(2)s it.  klog(4) says so.
;------------------------------------------------------------------------------
klog_ioctl      MX      %00
                LDA     _Sys_IoctlCmd
                CMP     #FIONBIO
                BEQ     @ki_nbio
                LDA     #ENOTTY
                CLC
                RTL
                ; The argument is a POINTER into the caller's bank, not a value,
                ; so it is staged through _libcTmp2 and dereferenced -- upstream's
                ; `*(int *)data'.  _Pty_ArgWord does the same three stores.
@ki_nbio        LDA     _Sys_IoctlArgLo
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA     _Sys_IoctlArgBank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     [_libcTmp2]             ; A = *arg
                BEQ     @ki_clear
                SEP     #$20
                MX      %10
                LDY     #FCB_CdFlags
                LDA     [_fcbPtr],Y
                ORA     #FCB_CDF_NONBLK
                STA     [_fcbPtr],Y
                REP     #$20
                MX      %00
                SEC
                RTL
@ki_clear       SEP     #$20
                MX      %10
                LDY     #FCB_CdFlags
                LDA     [_fcbPtr],Y
                AND     #$FF-FCB_CDF_NONBLK
                STA     [_fcbPtr],Y
                REP     #$20
                MX      %00
                SEC
                RTL

;------------------------------------------------------------------------------
; klog_poll - upstream's logselect: readable exactly when the reader has not
; caught up with the writer.  select(2) is the call that must not block, so this
; only tests.
;   Out: A = POLL* mask.
;------------------------------------------------------------------------------
klog_poll       MX      %00
                JSR     _Klog_Avail
                CMP     #$0000
                BEQ     @kp_none
                LDA     #POLLIN
                SEC
                RTL
@kp_none        LDA     #$0000
                SEC
                RTL

;==============================================================================
; The vtable.  Nine 3-byte slots in a locked order (include/chardev.s); the bank
; bytes are self-patched by mod_init because the loader chooses the bank.
;==============================================================================
klog_ops        DFB     <klog_open,>klog_open,^klog_open
                DFB     <klog_close,>klog_close,^klog_close
                DFB     <klog_getc,>klog_getc,^klog_getc
                DFB     <klog_write,>klog_write,^klog_write
                DFB     <klog_ioctl,>klog_ioctl,^klog_ioctl
                DFB     <klog_poll,>klog_poll,^klog_poll
                DFB     <klog_dread,>klog_dread,^klog_dread     ; d_read: logread
                DFB     0,0,0                   ; d_write: none -- read-only
                DFB     0,0,0                   ; d_stop:  nothing in flight
klog_name       ASC     'klog',00

regok_msg       ASC     '/dev/klog ready',00
regfail_msg     ASC     'chardev registration failed',00

klog_end        EQU     *

; Placement guards (tools/gen_modplace.py writes MODP_* into modplace.s).
; Merlin's ERR fires on a NON-ZERO expression.  The first pins the header at the
; offset the loader will place it at -- if these disagree, every absolute
; reference in this module is wrong by the difference.  The second is the
; bank-end ceiling, in the integer-division idiom the kernel uses for its own.
; Merlin has no parentheses and no operator precedence -- strictly left to right
; -- so the subtraction lands before the divide without them.
                ERR     klog_hdr-MODP_ORG
                ERR     klog_end-MODP_ORG+klog_bss/MODP_LIMIT
