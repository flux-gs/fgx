;==============================================================================
; kc_sys.s - the C-TO-KERNEL direction of the kernel-C seam.
;
; include/kernelc.s documents the way IN: KC_ENTER/KC_LEAVE, asm calling C.
; This file is the way BACK OUT -- the primitives fcc-compiled kernel code
; calls when it has to talk to the kernel proper.  vfs_bio.c declares them
; extern and the unit fixture stubs them; these are the real ones.
;
; WHY THEY EXIST AT ALL.  The buffer cache is the first kernel C that must
; BLOCK.  getblk finds a buffer already B_BUSY, marks B_WANTED and waits for
; whoever holds it; brelse hands it on.  That is a sleep and a wakeup issued
; from inside a C frame, which is precisely what seam blocker 2 made
; survivable and what nothing had yet needed.
;
;------------------------------------------------------------------------------
; HOW THEY ARE REACHED, and why they end in RTL.
;
; Kernel C is compiled with --pile, so a call to a function fcc has not already
; seen is the PHK/PEA/PHK/PEA/RTL idiom: a far return frame built by hand,
; targeting the CURRENT bank.  The callee therefore sees exactly what a JSL
; leaves -- a 3-byte return frame -- and must return with RTL.  That matches
; the far bank's own export contract, so tools/check_far_rtl_calls.py already
; polices it.
;
; Arguments sit above that frame: the first is at 4,S.  Every routine here
; takes one fcc pointer, which is FOUR bytes (multi-bank), so 4,S is its
; OFFSET and 6,S its bank.
;
;------------------------------------------------------------------------------
; THE TWO SWITCHES, AND WHICH ONE EACH ROUTINE NEEDS.
;
; Kernel C runs with D = FGX_DP_KERNELC and DBR = the far bank.  The kernel
; proper runs with DBR = the core bank and D = whatever FGX_Entry chose --
; FGX_DP_KKERN under the relocating build, FGX_DP_KERNEL ($0000) only on the
; legacy $02 one.  THERE IS NO CONSTANT FOR IT, which is why the kernel caches
; it in _kFgxDPKernel and _FarSh_KernDP hands it back.  Assuming $0000 here put
; the block layer's parameters on page zero, so dev_table_ptr came back as
; rubbish, the device-state pointer as null, and the SmartPort read went to
; unit 255.  Crossing back needs both restored, but not in the same place:
;
;   D   is switched HERE, because only this side knows the C page is live.
;   DBR is switched by the core-side shim (src/kernel/far_shims.s), because
;       PHK there yields the core bank and PHK here would yield the far one.
;
; kc_panic is the exception and deliberately so: it leaves DBR on the FAR bank
; because its argument is a string literal that lives there, and _FarSh_LogStr
; is the one shim that does not touch DBR for exactly this reason.
;
;------------------------------------------------------------------------------
; THE CHANNEL IS 16 BITS AND THE POINTER IS 32.
;
; _sleep/_wakeup match channels as 16-bit values, so these pass the pointer's
; OFFSET and drop its bank.  Two channels in different banks at the same offset
; would alias.  That is safe here, and the reason is worth writing down rather
; than rediscovering: every waiter in vfs_bio re-tests its condition after
; waking (`kc_sleep(bp); goto loop;`), so an aliased channel costs a spurious
; wakeup and a re-test, never a missed one.  It stops being safe the day a wait
; channel appears in a second bank AND some waiter trusts the wakeup instead of
; re-testing.
;==============================================================================

;------------------------------------------------------------------------------
; kc_sleep(chan) - block until kc_wakeup names the same channel.
;
; UNINTERRUPTIBLE (_sleepUn, BSD's PRIBIO).  A buffer wait has no error path to
; take: the caller re-tests and loops, so an interruptible sleep's "a signal is
; pending, I did not sleep" answer would spin at full speed.  See sched.s.
;------------------------------------------------------------------------------
; kc_curpid() -> the RUNNING process's pid.
;
; The module-side copy of this (src/modules/common/kc_sys.s) goes through
; SYS_KCALL's KSVC_CURPID; the far bank does not have SYS_KCALL, it has the
; _FarSh_* shims, so this is the same read by the other route.  _curTask is a
; DIRECT PAGE cell on the KERNEL's page -- which is the whole reason it is a
; service and not an absolute read -- so the page has to be switched first,
; exactly as kc_sleep does below.
;
; CALL IT EVERY TIME; DO NOT CACHE IT IN A C STATIC.  A pid read before a sleep
; names a different process after one (apple/fgx#41), and here that would index
; another process's descriptors.
kc_curpid       MX      %00
                PHD                             ; save the kernel-C page
_cfp130         JSL     _FarSh_KernDP           ; A = the kernel's REAL page
                TCD
_cfp131         JSL     _FarSh_CurPid           ; A = pid; shim owns the DBR
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
kc_sleep        MX      %00
                LDA     4,S                     ; chan = pointer OFFSET
                PHD                             ; save the kernel-C page
                PHA                             ; TCD needs A, so park chan
_cfp121         JSL     _FarSh_KernDP           ; A = the kernel's REAL direct page
                TCD
                PLA                             ; chan back
_cfp115         JSL     _FarSh_SleepUn          ; shim sets DBR = core bank
                PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_wakeup(chan) - make every task waiting on chan runnable.  Does not switch.
;------------------------------------------------------------------------------
kc_wakeup       MX      %00
                LDA     4,S
                PHD
                PHA
_cfp122         JSL     _FarSh_KernDP           ; kernel's REAL direct page
                TCD
                PLA
_cfp116         JSL     _FarSh_Wakeup
                PLD
                RTL

;------------------------------------------------------------------------------
; kc_cdlookup(name) -> chardev index 0..15, or -1 if there is no such device.
;
; The same service KSVC_CDLOOKUP gives a module, by the far bank's route.  A
; REGISTRY INDEX IS ASSIGNED BY REGISTRATION ORDER, so it is not a constant a
; caller may bake -- this is how a caller finds one, and it is what lets the
; /dev volume's numbers be CHECKED against the live registry rather than
; trusted.
;
; `name' is a 4-byte fcc pointer: offset at 4,S and the bank byte at 6,S.  The
; kernel's direct page has to be established first because _cdKcNamePtr, which
; the core side stages through, is a DP cell -- the same dance kc_sleep and
; kc_blkio do, and for the same reason.
;------------------------------------------------------------------------------
; THE BANK RIDES IN Y AND NOT ON THE STACK, which is not a tidiness choice:
; the first cut parked it with PHA and dropped it with PLA on the way out, and
; PLA LOADS A.  It pulled the parked byte over the answer and every lookup
; came back as the far bank's own number -- $7E, which reads like a plausible
; index until you notice it is where this code lives.  Y survives both JSLs
; (_FarSh_KernDP touches only A and DBR), so there is nothing to park.
kc_cdlookup     MX      %00
                LDA     6,S                     ; the name's bank (+ pad)
                AND     #$00FF
                TAY                             ; Y = bank, all the way through
                LDA     4,S                     ; name offset
                PHD                             ; save the kernel-C page
                PHA                             ; park the offset; TCD needs A
_cfp132         JSL     _FarSh_KernDP           ; A = the kernel's REAL page
                TCD
                PLA                             ; offset back
_cfp133         JSL     _FarSh_CdLookup         ; shim owns the DBR
                BCS     @cdl_hit
                PLD                             ; kernel-C page back
                LDA     #$FFFF                  ; -1: no such device
                RTL
@cdl_hit        PLD                             ; sets N/Z only; A survives
                AND     #$00FF
                RTL

;------------------------------------------------------------------------------
; kc_blkio(dev, blkhi, blklo, addr, isread) -> 0 on success, else errno.
;
; One 512-byte device transfer.  bio_strategy issues two of these per
; filesystem block; see the note there about why the block number's high word
; is an argument rather than something set once.
;
; IT MUST NOT SLEEP, and that is not a style preference: it is the property
; that makes biowait's sleep unreachable and therefore keeps every remaining
; sleep in the filesystem above the block driver.  SmartPort PIO spins and the
; RAM disk copies, so there is nothing here that could block.
; tools/check_fs_sleep_invariant.py holds this file to it.
;
; WHY THE WORK IS SPLIT ACROSS TWO BANKS.  The block layer's parameters are
; DIRECT PAGE cells (_blkNum, _blkNumHi, _blkBuf, _fsCurDevIdx), so they are
; written here, once D is on the kernel page.  _blkBufBank is NOT a direct page
; cell -- $10-$1F was full -- so it lives in the core kernel bank and can only
; be written with DBR there, which is the core-side shim's job.  Hence the
; buffer bank rides in A across the JSL and the shim stores it.
;
; Stack, with the caller's args above our own PHD:
;   6,S dev   8,S blkhi   10,S blklo   12,S addr offset   14,S addr bank
;   16,S isread
;------------------------------------------------------------------------------
kc_blkio        MX      %00
                PHD                             ; save the kernel-C page
_cfp123         JSL     _FarSh_KernDP           ; kernel's REAL direct page
                TCD                             ; the block layer's args are
                                                ;   DP cells, so D must be right
                                                ;   BEFORE they are written
                LDA     10,S                    ; block number, low word
                STA     _blkNum
                LDA     8,S                     ; block number, high word --
                STA     _blkNumHi               ;   consumed and zeroed by the
                                                ;   Blk_* entry latch, so it is
                                                ;   set per transfer, not once
                LDA     12,S                    ; buffer offset
                STA     _blkBuf
                SEP     #$20
                MX      %10
                LDA     6,S                     ; device index (low byte)
                STA     _fsCurDevIdx
                REP     #$30
                MX      %00
                LDA     16,S                    ; isread.  There is no
                TAX                             ;   stack-relative LDX on this
                                                ;   CPU, so it goes via A
                LDA     14,S                    ; buffer BANK -> A, for the shim
                AND     #$00FF
_cfp119         JSL     _FarSh_BlkIo            ; shim sets DBR, stores the
                                                ;   buffer bank, dispatches
                BCS     @kbi_ok
                AND     #$00FF                  ; C=0: A = errno from the driver
                BRA     @kbi_out
@kbi_ok         LDA     #0
@kbi_out        PLD                             ; kernel-C page back
                RTL

;------------------------------------------------------------------------------
; kc_blkreads() -> the kernel's device-read count, low word.
;
; No direct page switch, because nothing here touches a DP cell -- the counter
; is a core-bank static and the shim's DBR is all that is needed.  The other
; routines in this file switch D only because the block layer's parameters
; happen to live there.
;------------------------------------------------------------------------------
kc_blkreads     MX      %00
_cfp120         JSL     _FarSh_BlkReads
                RTL

;------------------------------------------------------------------------------
; kc_panic(msg) - name the failure, then halt.
;
; It HALTS rather than returning, because every caller is a broken-invariant
; check (biodone on a buffer already done; bgetvp on a buffer that is not
; free).  Continuing past one of those corrupts a cache other tasks are
; reading.
;
; The name is printed FIRST.  A halt with no name has cost this project whole
; sessions before -- the same reasoning as _Slp_StkLockPanic in sched.s.
;
; DBR STAYS ON THE FAR BANK across the log call.  msg points at an fcc string
; literal in the far bank's data segment, Kern_LogStr reads it with the
; caller's DBR, and _FarSh_LogStr is the one shim that leaves DBR alone.
; Forcing the core bank here would print whatever sits at the same offset in
; the core kernel.
;------------------------------------------------------------------------------
kc_panic        MX      %00
                LDA     4,S                     ; msg offset, in the FAR bank
                PHD
                PHA
_cfp124         JSL     _FarSh_KernDP           ; kernel's REAL direct page
                TCD                             ; _conStrPtr is a kernel DP cell
                PLA
                STA     _conStrPtr
_cfp117         JSL     _FarSh_LogStr           ; leaves DBR = far, on purpose
_cfp118         JSL     _FarSh_Halt             ; never returns
                PLD                             ; unreachable; present so the
                RTL                             ;   frame reads as balanced


;------------------------------------------------------------------------------
; kc_setfstime(t) -- leave the root superblock's fs_time in the core's
; `_kRootFsTime' for inittodr (tty/kern_time.c), which the core calls once the
; root is mounted: 2.11BSD init_main.c:197's `time.tv_sec = fs->fs_time'.  The
; far bank cannot call the tty bank, so the value waits in the core.
; 4 argument bytes: a long, low word first.
;------------------------------------------------------------------------------
kc_setfstime    MX      %00
                LDA     4,S                     ; t, low word
_cfp997         STAL    _kRootFsTime
                LDA     6,S                     ; t, high word
_cfp998         STAL    _kRootFsTime+2
                RTL
