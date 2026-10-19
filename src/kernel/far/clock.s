;==============================================================================
;
; FGX - Flux GS uniX
;
; File:     clock.s
; Purpose:  Battery-RAM real-time clock -- FAR KERNEL BANK
; Created:  2026-08-01
;
; This is the BRAM RTC, NOT the 60 Hz tick counter.  The tick counter stays in
; the core bank's toolbox.s: it runs in the VBL ISR and _kSystemTicks is read
; directly by sched.s, blkcache.s and write.s, so moving it would put a
; cross-bank JSL on a 60 Hz path to save ~150 bytes.  See docs/history/plans/far-kernel-bank.md
; section 7.
;
; Toolbox calls here use the stateless $E10000 dispatch with NO TLStartUp, the
; idiom sim.s:935 documents and ramdisk.s:649 reuses for ReadBParam.
;
;------------------------------------------------------------------------------
; THE CALLER BANK ARRIVES IN X, it is not read from _Sys_CallerBank.
;
; _Sys_CallerBank is an absolute static in the CORE bank, so far-bank code cannot
; reach it without a patched LDAL.  Rather than build that machinery for one
; symbol, the core-side thunks in syscall.s load it and pass it in X; each
; routine here reads it back with an 8-bit TXA.  X was unused by all three
; routines (verified: zero X-register references before the move), and the high
; byte of X is deliberately ignored -- the thunk loads it 16-bit over a 1-byte
; static, so that byte is whatever follows it in memory.
;
; The syscall handlers are reached through those thunks because the dispatch
; table (syscall.s) holds 2-byte DA offsets with the core bank implied; a far
; handler cannot be named there directly.
;------------------------------------------------------------------------------
; DP IS UNAFFECTED BY THE MOVE.  _shTmp0 and _libcTmp2 are direct page, reached
; through the D register rather than DBR, and the kernel's D is live across the
; cross-bank call -- the same property FGXM modules rely on.  Only DBR-relative
; (absolute) statics had to travel, and all three did.
;==============================================================================

;------------------------------------------------------------------------------
; _Sys_Uptime (#51) - copy 6 bytes of boot wall-clock to caller-bank buf.
;
; A = dst offset (caller bank).  Layout written matches Misc Toolset
; ReadTimeHex pull frame:
;   +0 sec  +1 min  +2 hour  +3 year  +4 day  +5 month
;
; Userland pairs this with its own ReadTimeHex call to compute time-since-
; boot.  No error path; returns C=1 + A = input offset.
;------------------------------------------------------------------------------
_Sys_Uptime     ENT
                MX      %00
                PHB                             ; far bank: caller's DBR is the
                PHK                             ;   CORE bank; _rtcFrame/_kBootTime
                PLB                             ;   /_rtcSavedS are HERE
                STA     _shTmp0                 ; remember dst for return
                STA     _libcTmp2               ; lo word of long ptr
                SEP     #$20
                MX      %10
                TXA                             ; caller bank, passed in X by the
                                                ;   core thunk (see file header)
                STA     _libcTmp2+2
                LDY     #0
@up_L           LDA     _kBootTime,Y
                STA     [_libcTmp2]
                REP     #$20
                MX      %00
                INC     _libcTmp2
                SEP     #$20
                MX      %10
                INY
                CPY     #6
                BCC     @up_L
                REP     #$20
                MX      %00
                LDA     _shTmp0
                SEC
                PLB                             ; restore caller's DBR
                RTL

;------------------------------------------------------------------------------
; _Sys_RtcRead (#31) - read the battery RTC into a caller-bank 6-byte buffer.
;
; WHY THIS EXISTS (2026-07-26).  libc's time() used to reach the clock itself,
; with a raw `LDX #$0D03 / JSL $E10000` from USER context.  That call NEVER
; RETURNS for tcsh: PC sampling over the same window puts tcsh 89.9% in ROM
; banks $FF/$FE with the $E1 dispatcher live and the kernel idle loop at 0.1%,
; against 0.4% ROM / 97.7% kernel for a healthy control -- and stubbing the
; toolbox call out is what let tcsh reach its prompt.  A small binary
; (src/userland/timetest) makes the same call and returns, so it is
; context-dependent, not universally broken; the durable fix is to stop every
; task from touching the Toolbox on its own DP and stack under preemption and
; let the KERNEL own the ROM interaction, the way it already owns ProDOS date
; stamping.
;
; The frame is the RAW ReadTimeHex shape, byte-identical to _Sys_Uptime (#51)
; so the two share one unpack, and month/day stay 0-BASED exactly as the ROM
; hands them over -- libc's existing +1 is unchanged, and its epoch arithmetic
; (measured correct: 1785082864 = 2026-07-26) stays where it is rather than
; being re-implemented in 65816 against ~339 B of kernel headroom:
;   +0 sec  +1 min  +2 hour  +3 year(-1900)  +4 day  +5 month
;
; Input:  A = dst offset in the caller's bank.  MX %00.
; Output: C=1, A = the input offset.  No error path (ReadTimeHex never fails).
;------------------------------------------------------------------------------
_Sys_RtcRead    ENT
                MX      %00
                PHB                             ; far bank: caller's DBR is the
                PHK                             ;   CORE bank; _rtcFrame/_kBootTime
                PLB                             ;   /_rtcSavedS are HERE
                STA     _shTmp0                 ; preserve dst for the return
                STA     _libcTmp2               ; lo word of the long pointer
                SEP     #$20
                MX      %10
                TXA                             ; caller bank, passed in X by the
                                                ;   core thunk (see file header)
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                JSR     _RtcFwRead              ; frame -> _rtcFrame (abs scratch)
                ; Copy the 6-byte frame out to the caller.  Absolute,X reads are
                ; DBR-relative and the kernel DP is back, so [_libcTmp2],Y is
                ; valid again here.
                LDX     #0
                LDY     #0
                SEP     #$20
                MX      %10
@rr_copy        LDA     _rtcFrame,X
                STA     [_libcTmp2],Y
                INX
                INY
                CPY     #6
                BCC     @rr_copy
                REP     #$20
                MX      %00
                LDA     _shTmp0
                SEC
                PLB                             ; restore caller's DBR
                RTL

;------------------------------------------------------------------------------
; _RtcFwRead - ReadTimeHex ($0D03) into _rtcFrame, at D=$0000, page-$01 stack.
;
; WHY THE PAGE-$01 BOUNCE (2026-07-26).  The kernel's own rule (dispatcher,
; syscall.s) was that only the SmartPort firmware path needs a page-$01 stack
; because "native toolbox calls are page-agnostic".  ReadTimeHex falsifies that:
; the hot PC $FF/FCDC is as the innermost SBC #$01 of WAITNEW1,
; the delay body WAIT ($FF/FCA8) falls into -- emulation-era MONITOR code.  An
; SEC/XCE down there truncates S to its LOW BYTE, so a handler running on a
; per-task kernel stack ($E1xx, $E2xx, ... in the language card) has its frame
; stranded at $01xx and
; returns into the weeds.  Whether that is survivable depends on the S low byte
; at the moment of the call, which is why a shallow caller (timetest) returns
; fine and a deep one (tcsh, calling from enthist) wedges -- 87.7% of PC samples
; in ROM, with the last syscall recorded as #31.  Same shape as
; _blkSmartJump's bounce, including keeping an already-page-$01 stack as-is so
; the excursion frame is not pushed over the caller's own live page-1 frames.

;------------------------------------------------------------------------------
;
; THE D=$0000 IS THE WHOLE POINT, and it is the same rule _blkFwCall documents
; for the SmartPort firmware: the ROM does 6502/ZP-style direct-page scratch at
; whatever D it inherits and "HANGS FOREVER with a non-zero inherited D".  Left
; at the caller's DP this wedges tcsh (task DP $B300) with 87.7% of PC samples
; in ROM $FF -- inside WAIT's inner delay body ($FF/FCDC) and a
; speaker loop, i.e. WILD EXECUTION rather than a tool call in progress.  Boot's
; _KCaptureBootTime happens to run at D=$0000 already, which is exactly why the
; same tool has always worked there and nowhere else.
;
; NOTHING DP-relative may appear between TCD and PLD -- _rtcFrame is absolute
; (DBR = kernel bank), and the saved D sits BELOW the tool's four result words,
; so the pulls must come first.
;
; Entry/exit MX %00.  Clobbers A/X/Y.  Caller DP restored on exit.
;------------------------------------------------------------------------------
_RtcFwRead      MX      %00
                PHP                             ; --- IRQs OFF for the excursion.
                SEI                             ; Boot's _KCaptureBootTime (main.s
                                                ; :243) does this same tool call
                                                ; SUCCESSFULLY only because it runs
                                                ; BEFORE Toolbox_InstallHB (:316)
                                                ; enables VBL and CLIs -- so the
                                                ; "boot works" control was never a
                                                ; control at all: no working case
                                                ; had ever survived an interrupt
                                                ; INSIDE the tool.  The dispatcher
                                                ; CLIs at entry (:390), so a syscall
                                                ; excursion runs interrupt-hot, and
                                                ; the ROM's interrupted-context save
                                                ; area is a GLOBAL singleton while
                                                ; the tool's WAIT path drops to
                                                ; emulation mode (SEC/XCE) -- a tick
                                                ; landing in there cannot be resumed
                                                ; reliably.  A short caller wins that
                                                ; lottery; tcsh, calling repeatedly
                                                ; from enthist, does not.
                PHD                             ; saved on the CALLER's stack
                TSC                             ; --- page-$01 bounce (inline: a
                STA    |_rtcSavedS              ;     JSR helper would RTS off the
                XBA                             ;     stack it just switched to)
                AND     #$00FF                  ; A = caller stack HIGH byte
                CMP     #$0001
                BEQ     *+6                     ; already page $01: keep it --
                                                ;   past the TCS, which would
                                                ;   otherwise load S from A = 1
                LDA     #FGX_STK_KERNEL+$FF     ; $01FF, firmware-safe
                TCS
                LDA     #$0000
                TCD
                PEA     $0000                   ; weekday|pad  (pulled last)
                PEA     $0000                   ; month|day
                PEA     $0000                   ; year|hour
                PEA     $0000                   ; minute|second (pulled first)
                LDX     #$0D03                  ; ReadTimeHex
                JSL     $E10000
                PLA                             ; minute|second
                STA     _rtcFrame+0             ; +0 sec, +1 min
                PLA                             ; year|hour
                STA     _rtcFrame+2             ; +2 hour, +3 year-1900
                PLA                             ; month|day
                STA     _rtcFrame+4             ; +4 day, +5 month (both 0-based)
                PLA                             ; weekday|pad - discard
                LDA    |_rtcSavedS              ; back to the caller's stack
                TCS
                PLD                             ; caller DP back (PHD was there)
                PLP                             ; IRQ state back
                RTS

;------------------------------------------------------------------------------
; Far-bank statics.  Moved out of syscall.s with the routines: nothing else in
; the tree referenced them (verified before the move).  They stay DBR-relative
; here because every entry does PHK/PLB, so no patching is needed.
;
; PLACED AFTER ALL CODE: a `DS` in a code segment reserves bytes exactly where it
; sits, and one placed mid-routine in the sound move planted zero bytes in an
; entry point that executed as BRK.
;------------------------------------------------------------------------------
_rtcSavedS      DS 2                   ; caller S across the ROM excursion
_rtcFrame       DS 6                   ; SYS_RTCREAD staging, ABSOLUTE
                                        ; (DBR-relative) on purpose: the ROM
                                        ; excursion runs at D=$0000, so nothing
                                        ; DP-relative may be touched inside it.
                                        ; +0 sec +1 min +2 hour +3 year-1900
                                        ; +4 day +5 month (day/month 0-based)
_kBootTime      DS      6               ; boot ReadTimeHex snapshot; written by
                                        ; _KCaptureBootTime, read by _Sys_Uptime.
                                        ; Both live HERE, which is why it never
                                        ; crosses a bank.

;=============================================================================
; _KCaptureBootTime - read wall clock once at boot via Misc Toolset
; ReadTimeHex ($0D03) and stash 6 bytes at _kBootTime.  The Toolbox dispatcher
; at $E10000 is ROM-resident and works without TLStartUp for stateless tools
; like ReadTimeHex (the same call the old in-kernel `uptime`/`date` used).
;
; Pull order from the toolbox push frame (low byte first):
;   pull #1: minute|second   → byte 0 = sec, byte 1 = min
;   pull #2: year|hour       → byte 2 = hour, byte 3 = year
;   pull #3: month|day       → byte 4 = day, byte 5 = month
;   pull #4: weekday|pad     → discarded
;
; Entry: MX %00 (called from FGX_Entry).  Returns MX %00, A clobbered.
;=============================================================================
_KCaptureBootTime MX  %00
                PHB                             ; far bank: our _kBootTime is HERE
                PHK
                PLB
                PEA     $0000                   ; weekday|pad
                PEA     $0000                   ; month|day
                PEA     $0000                   ; year|hour
                PEA     $0000                   ; minute|sec
                LDX     #$0D03                  ; ReadTimeHex
                JSL     $E10000
                PLA                             ; minute|second
                SEP     #$20
                STA     _kBootTime+0            ; sec
                XBA
                STA     _kBootTime+1            ; min
                REP     #$20
                PLA                             ; year|hour
                SEP     #$20
                STA     _kBootTime+2            ; hour
                XBA
                STA     _kBootTime+3            ; year
                REP     #$20
                PLA                             ; month|day
                SEP     #$20
                STA     _kBootTime+4            ; day
                XBA
                STA     _kBootTime+5            ; month
                REP     #$20
                PLA                             ; weekday|pad — discard
                PLB                             ; restore caller's DBR
                RTL
