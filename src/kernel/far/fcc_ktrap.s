;==============================================================================
; fcc_ktrap.s - the fcc runtime traps, in their KERNEL form.
;
; tools/gen_fcc_rt.py extracts fcc's runtime into fcc_rt.s starting at
; _fcc_mul16, and stops there because the three routines above that point exit
; or yield through SYS_TRAMP.  A kernel cannot make a syscall against itself, so
; those three are supplied here instead.  The generator FAILS if one of them
; ever drifts below its boundary, so this file cannot silently stop being the
; definition that gets used.
;
; A userland stack overflow is a process's problem and _Sys_Exit prints which
; guard fired.  In the kernel there is nobody to exit to and nothing left worth
; running: the frame that overflowed has already scribbled past the bottom of a
; 256-byte per-pid kernel stack and into whatever bank 0 keeps below it.  So
; these stop the machine, loudly and immediately, in the far bank's own idiom --
; a red border and a spin, the same contract _Far_StubHalt gives an unwired
; export slot.  Continuing would turn a diagnosable trap into corruption
; attributed to some later, innocent subsystem.
;
; A DISTINCT BORDER COLOUR PER TRAP, because the three are reached from
; different places and the colour is the only thing a wedged machine can say:
;   red     ($01) - an unassigned export slot was called  (_Far_StubHalt)
;   yellow  ($0D) - kernel-C HARDWARE stack overflow      (_fcc_stkoflow)
;   magenta ($03) - kernel-C SOFT stack overflow          (_fcc_sfoflow)
;
; AND EACH WRITES A REPORT before it spins -- magic, D, S and the floor, into
; the fixed bank-0 cells at KFGX_TRAP_MAGIC (include/memmap.s).  The magic
; identifies WHICH trap fired, which the border colour also does but only to
; someone holding the machine; the report is readable from a memory dump, so a
; harness run that wedges can say why instead of timing out.
KTRAP_MAGIC_HW  EQU     $C5D0                   ; _fcc_stkoflow fired
KTRAP_MAGIC_SF  EQU     $C5D1                   ; _fcc_sfoflow fired
;
; _fcc_safepoint is NOT here.  It is a cooperative-yield point, which is a
; userland notion -- kernel C runs to completion inside a syscall, and the
; reentrancy bar in include/kernelc.s is what keeps that true.  Kernel C is
; compiled with -fno-safepoints so the call is never emitted; if that flag is
; ever dropped the link fails on the undefined symbol, which is the outcome to
; want.
;==============================================================================

;------------------------------------------------------------------------------
; _fcc_stkoflow - a kernel-C prologue found S below _fcc_stkfloor.
;
; Reached by a near JMP from the prologue, so the offending frame is NOT yet
; established and the stack is still whatever the caller left.  Nothing here
; may push.
;------------------------------------------------------------------------------
; IT RECORDS BEFORE IT SPINS (apple/fgx#261).  The border colour was the whole
; diagnostic, and a colour cannot say WHICH stack, how deep, or against what
; floor.  apple/fgx#225 is the case that makes this worth instructions: the
; guard fired on a FICTIONAL floor -- `_fcc_stkfloor' read before it was written,
; $FFA9 of loader residue -- with a perfectly healthy stack at $F9BD.  Nothing
; on screen could distinguish that from a real overflow, so it presented as a
; layout lottery in which inert `DS' padding decided whether the machine booted,
; and it was found only when someone thought to sample the LIVE PC.
;
; NOTHING HERE PUSHES, which the header states and this must keep: the frame is
; not established and the stack is whatever the caller left -- pushing would
; write into the very region the trap exists to report on.  Absolute stores
; only, and A/X/Y are expendable because the machine stops on the next line.
;
; THE FLOOR IS READ THROUGH THE CALLER'S DP, deliberately.  If D is wrong the
; value recorded is garbage, and THAT IS THE FINDING -- a floor of $FFA9 against
; an S of $F9BD is #225 on sight, where a floor of $0000 is the inert guard
; described in include/kernel.s:632 and an overflow is real.
_fcc_stkoflow   REP     #$30
                MX      %00
                TSC                             ; S first: the number that says
                STAL    KFGX_TRAP_S             ;   how deep it actually got
                TDC
                STAL    KFGX_TRAP_D
                LDA     _fcc_stkfloor           ; DP-relative, through D above
                STAL    KFGX_TRAP_FLOOR
                LDA     #KTRAP_MAGIC_HW         ; magic LAST: a reader that sees
                STAL    KFGX_TRAP_MAGIC         ;   it knows the other three
                SEP     #$20                    ;   were already stored
                MX      %10
                LDA     #$0D                    ; yellow: kernel-C stack
                STAL    $E0C034
@fko_spin       BRA     @fko_spin

;------------------------------------------------------------------------------
; _fcc_sfoflow - the SOFT-frame equivalent, for a kernel-C function compiled
; into fcc's soft-frame mode (FCC_SOFT_SCC).
;
; Nothing selects soft frames for kernel C today, so this is unreached.  It is
; defined anyway because the alternative is an undefined symbol appearing at
; the exact moment someone marks a recursive kernel routine soft -- and because
; a trap that is missing is indistinguishable from a trap that never fires.
;------------------------------------------------------------------------------
; Records the same four words with its own magic, so an unreached trap that
; starts firing is identified by the report rather than by the border colour a
; reader has to look up.
_fcc_sfoflow    REP     #$30
                MX      %00
                TSC
                STAL    KFGX_TRAP_S
                TDC
                STAL    KFGX_TRAP_D
                LDA     _fcc_stkfloor
                STAL    KFGX_TRAP_FLOOR
                LDA     #KTRAP_MAGIC_SF
                STAL    KFGX_TRAP_MAGIC
                SEP     #$20
                MX      %10
                LDA     #$03                    ; magenta: kernel-C soft frame
                STAL    $E0C034
@fso_spin       BRA     @fso_spin
