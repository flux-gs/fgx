;==============================================================================
; console_kbd.s - Keyboard input (heartbeat-driven ring buffer).
;
; The Apple IIgs has no hardware keyboard IRQ.  Mega II latches the most
; recent ASCII + strobe into $C000 and that latch is one-deep — if the
; foreground takes longer than 16 ms (one VBL) between Con_PollKey calls,
; the next strobe overwrites the unread one and the keystroke is lost.
; A full SHR scroll alone takes ~100 ms, so any typing during command
; output reliably dropped keys.
;
; Fix: the kernel heartbeat task (src/kernel/toolbox.s::_HBTickTask) polls
; $E0C000 at every VBL and enqueues fresh keystrokes into a 16-entry ring
; in kernel-bank globals (_kKbdRing[], see include/memmap.s; the kernel bank
; is MM-assigned at runtime — $02 is the assembly ORG only).  Con_PollKey now
; just dequeues from that ring — it never touches the hardware directly.
;
; Auto-repeat: the IIgs ADB controller already does hardware auto-repeat
; (re-strobing $C000 at the user-configured rate), so the previous
; software auto-repeat in this file was redundant.  Dropping it removes
; the call-rate dependency (which broke once Con_GetKey wasn't a tight
; spin loop) and lets the ring honor whatever rate ADB delivers.
;
; Public:
;   Con_PollKey   Non-blocking. C=1 + A=key if ring non-empty; C=0 if empty.
;   Con_GetKey    Blocking; spins until a key is available.
;==============================================================================

;------------------------------------------------------------------------------
; Con_PollKey - non-blocking dequeue from the heartbeat-fed kbd ring.
;
; Entry: M=0, X=0.
; Exit:  C=1 + A = key (low byte, high byte clear) if ring was non-empty.
;        C=0 + A = 0 if empty.
;        Caller M/X/I restored from entry PHP (so callers running with IRQs
;        unmasked stay unmasked; our PLP at exit ends the atomic window).
;
; Atomicity: SEI right after PHP so the heartbeat can't fire between us
; reading _kKbdRingCount and updating _kKbdRingTail.  PLP at exit restores
; caller's I flag (typically I=0 — kernel runs with IRQs enabled outside
; explicit critical sections), which re-opens the heartbeat.
;------------------------------------------------------------------------------
Con_PollKey     MX      %00
                PHP                             ; save caller M/X/I
                REP     #$30
                MX      %00
                SEI                             ; atomic ring access

                ; VIRTUAL-CONSOLE GATE (apple/fgx#41).  THE ONE CHOKE POINT:
                ; every path that consumes a keystroke -- read(2)'s discipline,
                ; SYS_GETKEY, SYS_POLLKEY, the pipe ^C peek, the socket ^C peek,
                ; Con_GetKey's own loop -- bottoms out here, so gating here
                ; covers all of them AND anything added later, by construction.
                ;
                ; Gating each CONSUMER instead was tried and does not converge:
                ; it produced three different predicates for the same question
                ; (_Vc_RdTtyIsActive, _Vc_CttyIsActive, _Tty_CurIsFg's tty[0]
                ; compare) and still left _Tty_PollByte's console arm ungated.
                ; A keystroke belongs to the console the user is LOOKING AT;
                ; that is one fact, so it deserves one test in one place.
                ;
                ; The per-consumer gates that remain are not redundant: they let
                ; a reader BLOCK (sleep on WCHAN_KBD) instead of spinning on an
                ; empty poll.  This one decides eligibility; those decide waiting.
_cfp114         JSL     _FarSh_VcKbdOK
                BCC     @pk_empty               ; not our console: the ring reads
                                                ;   EMPTY, exactly as if no key
                                                ;   had been typed at all
                ; The keyboard ring stays in the CORE bank -- the heartbeat ISR
                ; fills it (toolbox.s) and must not take a cross-bank hit at
                ; interrupt time.  Every access here is therefore long, with a
                ; _cfp marker so Far_BankInit patches the bank byte.
_cfp100         LDAL    _kKbdRingCount
                BEQ     @pk_empty

_cfp101         LDAL    _kKbdRingTail           ; LDX has no long form: via A
                TAX
                SEP     #$20
                MX      %10
_cfp102         LDAL    _kKbdRing,X             ; key byte -> A.lo (long,X is $BF)
                REP     #$20
                MX      %00
                AND     #$00FF                  ; clean hidden hi-byte
                PHA                             ; save key across index work

                INX
                CPX     #KBD_RING_SZ
                BCC     @pk_nowrap
                LDX     #0
@pk_nowrap
                TXA                             ; STX has no long form: via A
_cfp103         STAL    _kKbdRingTail
_cfp104         LDAL    _kKbdRingCount          ; DEC has no long form either
                DEC
_cfp105         STAL    _kKbdRingCount

                PLA                             ; recover key (16-bit)
                PLP                             ; restore caller flags (un-SEI)
                SEC
                RTS

@pk_empty       LDA     #0
                PLP                             ; restore caller flags (un-SEI)
                CLC
                RTS

;------------------------------------------------------------------------------
; Con_GetKey - block until a key is available; return A = ASCII (low byte).
;
; Phase 4.1: instead of busy-spinning on Con_PollKey, _sleep on WCHAN_KBD when
; the ring is empty.  swtch's idle loop wakes WCHAN_KBD sleepers when the
; heartbeat enqueues a key, so the CPU WAIs between keystrokes.  Only reached
; from syscall handlers (_Sys_Read fd 0, _Sys_GetKey), so _curTask is always a
; live task — safe for _sleep.
;------------------------------------------------------------------------------
; Out: C=1 + A = key, or C=0 = INTERRUPTED (a signal is pending for this task).
; The C=0 arm exists because a ^C never reaches this ring: when a shell owns the
; tty the heartbeat consumes ^C as a SIGNAL rather than enqueueing it, so polling
; alone can never observe it.  Before, this loop simply re-slept -- woken on
; every switch, re-polling a ring that would never fill -- and the syscall
; boundary that runs _Sys_CheckSignal was never reached, so ^C killed no
; foreground job blocked in read() (issue #2).
Con_GetKey      MX      %00
@gk_L           JSR     Con_PollKey
                BCS     @gk_done                ; C=1: got a key
                LDA     #WCHAN_KBD              ; ring empty — block instead of spin
                LDX     #PRIO_HIGH              ; pri (reserved)
_cfp020         JSL     _FarSh_Sleep         ; woken by swtch idle loop on keypress;
                                             ;   C=1 = a signal wants us to stop
                BCC     @gk_L
                CLC                             ; interrupted: no key for the caller
                RTS
@gk_done        RTS

;==============================================================================
; END console_kbd.s
;==============================================================================
