;==============================================================================
; itimer.s - setitimer(2), ITIMER_REAL.  FAR BANK.
;
; SYS_SETITIMER (#121).  The core bank keeps a five-byte thunk
; (src/kernel/signal.s) and the arithmetic lives here, the road `_Sys_Uptime',
; the two RTC calls and `_Sys_SigProcMaskFar' already take.
;
; THE TIMER ITSELF IS THE ONE alarm(2) ALREADY HAD.  `_kAlarmTicks'
; (include/memmap.s) is a per-task 32-bit tick countdown that the heartbeat
; decrements at 60 Hz, and `_kAlarmReload' (src/kernel/signal.s) is the 16-bit
; per-task reload this call adds.  When the counter reaches zero
; `_Sys_AlarmTickAll' copies the reload into it UNCONDITIONALLY, which is
; upstream's own rule and the whole of its ITIMER_REAL engine:
;
;     if (p->p_realtimer.it_value && !--p->p_realtimer.it_value) {
;             psignal(p, SIGALRM);
;             p->p_realtimer.it_value = p->p_realtimer.it_interval;
;     }
;                       -- vendor/2.11BSD/usr/sys/sys/kern_synch.c:48-51
;
; A zero reload therefore leaves a one-shot, which is what alarm(2) is, and no
; arm anywhere needs to ask whether a timer repeats.
;
; SECONDS IN, and that is upstream's representation and not a simplification:
; setitimer stores `p->p_realtimer.it_value = aitv.it_value.tv_sec' and merely
; increments it when any tv_usec is set (usr/sys/sys/kern_time.c:215-223).
; ITIMER_REAL on a PDP-11 has one-second resolution and so does this.
;
; BOTH TABLES ARE KERNEL-BANK GLOBALS, reached from here by `_cfpNNN'-marked
; long addressing whose bank byte `Far_BankInit' rewrites to the live core bank
; at boot (tools/gen_far_bankpatch.py, direction `far'; docs/history/plans/far-kernel-bank.md
; 2.4).  That is the same mechanism the loader's 43 sites in this bank use.
;==============================================================================

_itvValSec      DS      2               ; requested it_value, seconds
_itvIntSec      DS      2               ; requested it_interval, seconds
_itvSlot4       DS      2               ; (pid-1)*4, the counter's index
_itvSlot2       DS      2               ; (pid-1)*2, the reload's index
_itvOldLo       DS      2               ; the counter as found, for the return
_itvOldHi       DS      2
_itvTickLo      DS      2               ; seconds*60, 32-bit
_itvTickHi      DS      2
_itvT0          DS      2               ; the multiplier's own scratch
_itvT1          DS      2
_itvT2          DS      2

;------------------------------------------------------------------------------
; _Sys_SetITimerFar - arm the calling task's ITIMER_REAL.
;
; In:  A = it_value SECONDS, X = it_interval SECONDS, Y = which.  MX %00.
; Out: C=1, A = the OLD counter's remaining TICKS lo16, Y = hi16.
;      C=0 + A = EINVAL (a `which' other than ITIMER_REAL, or an interval past
;      ITIMER_MAX_INTERVAL) or ESRCH (no current task).
;
; A = low word and Y = HIGH word is the 32-bit return convention `__syscall_y()'
; reads back, as lseek does.  TICKS rather than seconds because ticks is the
; only resolution the kernel holds the remainder at; libc divides by 60 to fill
; `oitv->it_value', which is where upstream's own rounding lives.
;
; WHY THE INTERVAL HAS A CEILING AND THE VALUE HAS NONE: the reload table is
; 16-bit to halve its size, and the seconds-to-ticks conversion is `_Sys_Alarm's
; s*64 - s*4, whose INTERMEDIATE binds first -- 1023*64 fits sixteen bits and
; 1024*64 does not.  Past it this returns EINVAL rather than storing a truncated
; interval, because a timer that fires at 44 seconds having been asked for 300
; is a wrong answer wearing a success.  it_value goes to the 32-bit counter
; through the 32-bit multiplier below and takes any 16-bit second count.
;
; ITIMER_VIRTUAL and ITIMER_PROF are EINVAL.  Upstream keeps them in
; `u.u_timer[]' and charges them against CPU time this kernel does not account;
; a timer that silently never fired would be worse than a refusal.
;------------------------------------------------------------------------------
_Sys_SetITimerFar ENT
                MX      %00
                CPY     #ITIMER_REAL
                BEQ     @sit_whichOK
                LDA     #EINVAL
                CLC
                RTL                             ; no DBR pushed yet
@sit_whichOK    PHB                             ; the scratch above is far-bank
                PHK
                PLB
                STA     _itvValSec
                STX     _itvIntSec

                LDA     _itvIntSec
                CMP     #ITIMER_MAX_INTERVAL+1
                BCC     @sit_intOK
                LDA     #EINVAL
                BRA     @sit_fail
@sit_intOK      LDA     _curTask
                AND     #$00FF
                BNE     @sit_haveTask
                LDA     #ESRCH                  ; the kernel's own page reads 0
                BRA     @sit_fail
@sit_haveTask   DEC
                ASL
                ASL                             ; (pid-1)*4
                STA     _itvSlot4
                LSR                             ; (pid-1)*2
                STA     _itvSlot2

                ; THE OLD REMAINDER FIRST, before either store overwrites it.
                LDX     _itvSlot4
_cfp901         LDAL    _kAlarmTicks,X
                STA     _itvOldLo
_cfp902         LDAL    _kAlarmTicks+2,X
                STA     _itvOldHi

                ; The reload, 16-bit ticks.  Written BEFORE the counter so that
                ; a zero it_value cannot be re-armed by a reload landing after
                ; it -- the heartbeat only reads this when the counter expires,
                ; but the order costs nothing and removes the question.
                LDA     _itvIntSec
                JSR     _Itv_Ticks16
                LDX     _itvSlot2
_cfp903         STAL    _kAlarmReload,X

                ; The counter, 32-bit ticks.
                LDA     _itvValSec
                JSR     _Itv_Ticks32
                LDX     _itvSlot4
                LDA     _itvTickLo
_cfp904         STAL    _kAlarmTicks,X
                LDA     _itvTickHi
_cfp905         STAL    _kAlarmTicks+2,X

                LDA     _itvOldLo
                LDY     _itvOldHi
                SEC
                PLB                             ; restore the caller's DBR
                RTL
@sit_fail       CLC                             ; A holds the errno; PLB keeps C
                PLB
                RTL

;------------------------------------------------------------------------------
; _Itv_Ticks16 - A = seconds (0..ITIMER_MAX_INTERVAL) -> A = seconds*60, 16-bit.
;
; s*60 as s*64 - s*4, which is `_Sys_Alarm's arithmetic; the caller has already
; refused anything whose s*64 would not fit.  Clobbers A and the scratch.
;------------------------------------------------------------------------------
_Itv_Ticks16    MX      %00
                STA     _itvT0
                ASL
                ASL                             ; s*4
                STA     _itvT1
                LDA     _itvT0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL                             ; s*64
                SEC
                SBC     _itvT1                  ; s*60
                RTS

;------------------------------------------------------------------------------
; _Itv_Ticks32 - A = seconds -> _itvTickLo/_itvTickHi = seconds*60, 32-bit.
;
; The same s*64 - s*4, carried 32-bit so it_value takes any 16-bit second count:
; 65535 s is 3,932,100 ticks, which needs the counter's full width.  Clobbers A,
; X and the scratch.
;------------------------------------------------------------------------------
_Itv_Ticks32    MX      %00
                STA     _itvT0
                STA     _itvTickLo
                STZ     _itvTickHi
                LDX     #6
@t32_x64        ASL     _itvTickLo
                ROL     _itvTickHi
                DEX
                BNE     @t32_x64                ; tick = s*64

                LDA     _itvT0
                STA     _itvT1
                STZ     _itvT2
                ASL     _itvT1
                ROL     _itvT2
                ASL     _itvT1
                ROL     _itvT2                  ; t = s*4

                SEC
                LDA     _itvTickLo
                SBC     _itvT1
                STA     _itvTickLo
                LDA     _itvTickHi
                SBC     _itvT2
                STA     _itvTickHi              ; s*60
                RTS
