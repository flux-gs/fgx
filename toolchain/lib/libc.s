;==============================================================================
; libc.s - the parts of FGX's libc that 2.11BSD also writes in assembly.
;
;   getpid          syscall stub (2.11BSD lib/libc/pdp/sys, generated)
;   vfork           frameless by necessity (2.11BSD lib/libc/pdp/sys/vfork.s)
;   setjmp/longjmp  save and restore the machine state
;                   (2.11BSD lib/libc/pdp/gen/setjmp.s)
;
; Everything else in libc is C, in toolchain/lib/libc_c.  Each routine runs
; with DBR = the caller's data bank, where its cells in libc_data.s live, and
; returns through LIBC_RET: RTL where LIBC_FAR is 1 (every program's pile),
; RTS in the near flavour some fixture wrappers still assemble.
;==============================================================================

LIBC_DP_SRC     EQU     $E4
LIBC_DP_DST     EQU     $E6
LIBC_DP_TMP     EQU     $E8

;------------------------------------------------------------------------------
; Shared-libc (P3-0) flavor plumbing.  Every wrapper that PUTs libc.s /
; fcc_libc_shims.s defines LIBC_FAR: 0 = near flavor (FGX1: JSR entry, RTS
; exit, classic n,S offsets), 1 = far flavor (FGX2 shared pile segment:
; JSL [FGX2_FARCALL] entry, RTL exit, n,S offsets +1 — the JSL frame
; carries the caller's PB).
;
; LIBC_RET    - flavor-correct return, PUBLIC (fcc-callable) entries ONLY;
;               internal JSR/RTS helpers keep plain RTS.
; LIBC_EXPORT - 0-byte marker placed AT a public label; fgx_ld records it
;               (same semantics as fcc's FGX2_EXPORT) so FGX2_FARCALL
;               resolves into the shared pile.  Expands to nothing, so it
;               is harmless in near links, which never run fgx_ld.
;------------------------------------------------------------------------------
LIBC_EXPORT     MAC
                DS      0                        ; 0 bytes (merlin32 rejects a
                <<<                              ; fully empty macro body)
LIBC_RET        MAC
                DO      LIBC_FAR
                RTL
                ELSE
                RTS
                FIN
                <<<

; sprintf bank-aware output long-pointer (3 bytes: $E4-$E6 = buffer offset +
; buffer bank).  ALIASES LIBC_DP_SRC + LIBC_DP_DST.lo — those slots are idle
; for the entire sprintf pf_run: the format walk holds the fmt ptr in LP0
; ($EB-$ED), %s holds its source in TMP ($E8-$EA), and the number formatters
; use data-bank scratch only (verified).  sprintf seeds this once at entry
; from Y (offset) + _fcc_pf_outbank (bank); pf_emit then stores each byte via
; `STA [LIBC_DP_SPOUT],Y` (Y carries into the bank).  This fixes sprintf to a
; malloc'd buffer that lives outside DBR — the old `STA (dp)` was DBR-relative
; and dropped every byte in the wrong 64K.
LIBC_DP_SPOUT   EQU     $E4

; Slice 4.5 multi-bank: 3-byte long-pointer DP scratch slot used by
; printf/pf_run for cross-bank format reads + _libc_lstr_to_dbr helper.
; Placed at $EB so the long-indirect extension byte ($EB+2 = $ED)
; doesn't collide with LIBC_DP_TMP's own long-indirect extension byte
; at $EA (pf_emit_str writes there, would otherwise clobber LP0's low
; word).  $E0-$E3 ARGS, $E4-$E5 SRC, $E6-$E7 DST, $E8-$EA TMP (long).
LIBC_DP_LP0     EQU     $EB                     ; 3-byte long-ptr (input)

LIBC_LSTR_MAX   EQU     128                     ; scratch buffer cap

SYS_GETPID_NUM  EQU     20                      ; getpid() trap selector
SYS_VFORK_NUM   EQU     46                      ; vfork() trap selector (fork
                                                ; train; BSD's 66 is squatted
                                                ; by SYS_POLLKEY on FGX)
SYS_SIGSETMASK_NUM EQU  102                     ; sigsetmask(2) (longjmp, #64).
                                                ; Spelled out rather than reusing
                                                ; libc_start.s's _LS_SETMASK: libc.s
                                                ; is PUT into near links too, and
                                                ; the FGX1 crt0 defines no such EQU.

;------------------------------------------------------------------------------
; getpid - return current task's pid in A.
;------------------------------------------------------------------------------
                LIBC_EXPORT getpid
getpid          MX      %00
                JSL     SYS_TRAMP
                DFB     SYS_GETPID_NUM
                LIBC_RET

;------------------------------------------------------------------------------
; vfork - BSD vfork(2), fork train Stage V0.  The child borrows the parent's
; whole image + stack until it execve()s or _exit()s; the parent is blocked
; (WCHAN_VFORK) meanwhile.  Child: A=0.  Parent (at resume): A=child pid.
; Error: A=-1, errno set.
;
; FRAMELESS ON PURPOSE — the same reason BSD libc wrote vfork.s in assembly:
; after the child returns through this stub, its own pushes reuse the stack
; bytes that held our caller's RTL address, so when the parent later resumes
; at the syscall exit those bytes are garbage.  We pull the 3-byte RTL
; address into per-process libc DATA cells before the trap and rebuild it on
; the stack on BOTH exits (child first, parent at resume).  The cells are
; shared parent/child (same data bank — that's what vfork means), so a
; nested pre-exec vfork from the child would clobber the stash: UB, exactly
; as documented for BSD vfork.  The result rides a data cell across the
; rebuild because X is the syscall-exit clobber hazard (userland-abi §3.5)
; and LDA/STA/PHA/SEP/REP leave carry alone, so the kernel's C flag survives
; to the error test.
;------------------------------------------------------------------------------
                LIBC_EXPORT vfork
vfork           MX      %00
                PLA                             ; RTL addr: PC word (low first)
                STA     _vfork_ret
                SEP     #$20
                MX      %10
                PLA                             ; RTL addr: bank byte
                STA     _vfork_ret+2
                REP     #$20
                MX      %00
                ; P3-3 &local: stash the fcc frame-base pointer _fcc_fb (16-bit
                ; offset; bank invariantly 0) alongside the RTL bytes.  The child
                ; borrows the shared data bank and clobbers _fcc_fb via its own
                ; call prologues before _exit/exec, so without this the resumed
                ; parent computes &local off a stale base and stores through a
                ; wrong address (waitpid(pid,&stack_local,0) silently loses the
                ; status; reads are n,S and survive, only &local carriers break).
                ; Restored on the common exit path, mirroring setjmp/longjmp.
                LDA     _fcc_fb
                STA     _vfork_fb
                LDA     _fcc_sfp
                STA     _vfork_sfp
                ; AND THE SIGNAL DISPOSITION TABLE, for the same reason and in
                ; the same shape (apple/fgx#253).  `_sig_c_tab' is process state
                ; that lives in the DATA BANK -- crt0's trampoline dispatches
                ; through it and needs a far pointer the kernel cannot hold --
                ; and a vfork child shares that bank, so the child's own
                ; `signal()' calls write the PARENT'S table.  tcsh's child does
                ; exactly that before it execs (sh.sem.c:432,
                ; `signal(SIGINT, vffree)'), which left the resumed shell with
                ; its SIGINT handler pointing at the child's cleanup routine --
                ; whose tail is `_exit(1)'.  Upstream has no such table to
                ; corrupt: 2.11BSD keeps dispositions in the kernel, per proc,
                ; and vfork gives the child a proc of its own.
                ;
                ; ONE WINDOW THIS CANNOT CLOSE, stated rather than left to be
                ; found: the kernel delivers pending signals at SYSCALL EXIT,
                ; which for the resumed parent is before the first instruction
                ; of the restore below.  A caught signal that is pending and
                ; unblocked at that instant dispatches through `_sig_c_tab'
                ; while it still holds the child's writes.  Nothing at this
                ; layer can help -- the restore cannot run earlier than the
                ; syscall it returns from -- so closing it needs a per-task
                ; table in the kernel, or delivery deferred past the stub.
                ; tcsh is shielded wherever it blocks the signal across the
                ; fork (sh.sem.c:290 blocks SIGINT and SIGCHLD together) and
                ; not on the `nosigchld' path, which blocks only SIGCHLD.
                LDX     #0
@vf_sigSave     LDA     _sig_c_tab,X
                STA     _vfork_sigtab,X
                INX
                INX
                CPX     #128
                BCC     @vf_sigSave
                ; AND THE MASK SHADOW, which is the same state by the same
                ; argument: the child writes it too (tcsh's does, sh.sem.c:399,
                ; inside the `else { /* child */' at :392), and `_sig_tramp'
                ; pushes this shadow back into the KERNEL when a handler
                ; returns (libc_start.s _libc_sigtramp, @st_back) -- so a
                ; parent left holding the child's mask does not merely
                ; mis-remember, it reinstalls it.
                LDA     _sig_curmask
                STA     _vfork_sigmask
                LDA     _sig_curmask+2
                STA     _vfork_sigmask+2
                JSL     SYS_TRAMP
                DFB     SYS_VFORK_NUM
                ; Child (A=0) and, later, the resumed parent (A=pid) both
                ; pass through here.  C=0 = error (EAGAIN/ENOSYS): no child
                ; exists, but the RTL bytes are already pulled, so the
                ; rebuild path below is common to all three exits.
                BCS     @vf_ok
                STA     errno                   ; SYSCALL_ERR pattern
                LDA     #$FFFF                  ; -1
@vf_ok          STA     _vfork_res              ; keep result across the pushes
                ; Restore _fcc_fb for the resumed parent (harmless no-op for the
                ; child, whose _fcc_fb still holds the shared base).  LDA/STA
                ; leave carry alone, so the C=error flag survives to the RTL.
                LDA     _vfork_fb
                STA     _fcc_fb
                LDA     _vfork_sfp
                STA     _fcc_sfp
                ; PUT THE DISPOSITION TABLE BACK.  Unconditional, like the two
                ; restores above: for the CHILD it writes back what is already
                ; there (it has not called signal() yet -- that comes after this
                ; stub returns), and for the resumed PARENT it undoes whatever
                ; the child wrote.
                ;
                ; PHP/PLP AND NOT A BARE LOOP: the header above turns on
                ; LDA/STA/PHA/SEP/REP leaving carry alone, so the kernel's C
                ; reaches the caller's error test through the rebuild.  `CPX'
                ; does not -- and the direction matters, because the harmless
                ; reading is the wrong one.  The loop exits with X = 128, so
                ; `CPX #128' leaves C=1: without this bracket every vfork would
                ; report SUCCESS, swallowing the EAGAIN/ENOMEM the error path
                ; two screens up exists to return.  A bracket that only stopped
                ; spurious failures would be a nicety; this one stops a failed
                ; fork from reading as a child that never existed.
                PHP
                LDX     #0
@vf_sigRest     LDA     _vfork_sigtab,X
                STA     _sig_c_tab,X
                INX
                INX
                CPX     #128
                BCC     @vf_sigRest
                LDA     _vfork_sigmask
                STA     _sig_curmask
                LDA     _vfork_sigmask+2
                STA     _sig_curmask+2
                PLP
                SEP     #$20
                MX      %10
                LDA     _vfork_ret+2
                PHA                             ; rebuild: bank byte deepest
                REP     #$20
                MX      %00
                LDA     _vfork_ret
                PHA                             ; then the PC word
                LDA     _vfork_res
                RTL

;==============================================================================
; setjmp / longjmp: non-local goto.
;
; ABI:
;   setjmp   X = jmp_buf ptr (16-bit, caller's bank).  Returns:
;              A = 0     on direct call
;              A = val   on resume via longjmp
;            Y, DBR, DP preserved.  Flags restored to caller's (PHP/PLP).
;
;   longjmp  X = jmp_buf ptr, A = val.  Does not return.  Resumes
;            setjmp's caller as if setjmp had just returned, with A
;            set to val (or 1 if val == 0, per C standard).
;
; jmp_buf layout (16 bytes; 10 -> 12 in bank-0 stack campaign 1.1, 12 -> 16
; for the signal mask in apple/fgx#64):
;   +0       PB     program bank at setjmp call
;   +1       DBR    data bank register
;   +2..+3   _fcc_fb   fcc frame base (was the P/pad pair pre-P3-3)
;   +4..+5   PC     16-bit return PC offset (the JSR-saved value)
;   +6..+7   SP     16-bit S BEFORE setjmp's JSR was issued
;   +8..+9   DP     16-bit direct-page register
;   +10..+11 _fcc_sfp  soft-frame pointer (1.1).  Inert until the exile
;                      predicate turns on: nothing moves it yet, so a longjmp
;                      restores the same value it saved.  It is carried NOW so
;                      the jmp_buf ABI change lands separately from the codegen
;                      change that gives it meaning -- if one of the two breaks
;                      something, which one is not a guess.
;                      Keep toolchain/include/setjmp.h's _jb[] in step.
;   +12..+15 the 32-bit signal mask (apple/fgx#64).  BSD's setjmp/longjmp save
;                      and restore it; _setjmp/_longjmp are the pair that does
;                      not.  Without this, a handler that longjmps out (bsh's
;                      fault.c, and the standard BSD idiom) skips crt0's
;                      trampoline unblock and leaves its own signal blocked
;                      forever -- one ^C per process.
;
; longjmp returns to the saved (pb:pc+1) by synthesizing an RTL
; frame on the user stack: push pb, then pc (16-bit), then RTL.  RTL
; pops 3 bytes and increments PC, so we feed it env.pc (which is the
; JSR-saved value already one less than the actual return address)
; and the right PB.  This is bank-clean — no DP cell, no indirect
; through bank 0, and works for cross-bank setjmp/longjmp pairs too
; (the saved DBR and PB are independent).
;==============================================================================

                LIBC_EXPORT setjmp
setjmp          MX      %00
                PHP
                REP     #$30
                MX      %00
                PHY                              ; preserve Y across call

                ; +0  PB.  Near (JSR entry): caller PB == our PB — PHK.
                ; Far (JSL entry): the caller's PB is IN the frame at 6,S
                ; (1..2 = Y, 3 = P, 4..5 = ret PC, 6 = PB) — the old PHK
                ; "same-bank assumption" would capture the LIBC bank and
                ; longjmp would RTL into the wrong bank.
                DO      LIBC_FAR
                SEP     #$20
                MX      %10
                LDA     6,S
                ELSE
                PHK
                SEP     #$20
                MX      %10
                PLA
                FIN
                STA:    $0000,X
                ; +1  DBR.
                PHB
                PLA
                STA:    $0001,X
                REP     #$20
                MX      %00
                ; +2..+3  P3-3: the fcc frame-base pointer _fcc_fb (offset word;
                ; bank invariantly 0).  longjmp restores it so &local carriers
                ; (addresses computed off _fcc_fb) resolve in the resumed frame.
                ; (Was the zeroed "P reserved / pad" pair pre-P3-3.)
                LDA     _fcc_fb
                STA:    $0002,X

                ; +4..+5  PC.  Stack at this point:
                ;   1,S = saved Y.lo  (PHY)
                ;   2,S = saved Y.hi
                ;   3,S = saved P     (PHP, 1 byte)
                ;   4,S = ret PC.lo   (JSR- or JSL-saved)
                ;   5,S = ret PC.hi
                ;   (6,S = PB, far flavor only — DEEPER than PC, so the
                ;    4,S read is flavor-independent; do NOT shift it.)
                LDA     4,S
                STA:    $0004,X

                ; +6..+7  SP = caller's S before the setjmp call.
                ;   current S = caller_S - 2 (JSR) or 3 (JSL)
                ;             - 1 (PHP) - 2 (PHY)  = caller_S - (5+LIBC_FAR)
                TSC
                CLC
                ADC     #5+LIBC_FAR
                STA:    $0006,X

                ; +8..+9  DP.
                TDC
                STA:    $0008,X

                ; +10..+11  soft-frame pointer (1.1).
                LDA     _fcc_sfp
                STA:    $000A,X

                ; +12..+15  the signal mask (#64).  libc's shadow, not a
                ; syscall: sigsetmask keeps it exact and crt0's trampoline
                ; maintains it across delivery, so reading it here costs two
                ; loads instead of a trap.
                LDA     _sig_curmask
                STA:    $000C,X
                LDA     _sig_curmask+2
                STA:    $000E,X

                PLY
                PLP
                LDA     #0
                LIBC_RET

                LIBC_EXPORT longjmp
longjmp         MX      %00
                REP     #$30
                MX      %00

                ; Normalize val (C: longjmp(env, 0) makes setjmp return 1).
                CMP     #0
                BNE     @lj_valOK
                LDA     #1
@lj_valOK       STA     _setjmpVal

                ; --- #64: reinstall the mask setjmp saved, BEFORE the jump ---
                ; BSD's longjmp is sigsetmask(saved) then _longjmp, in that
                ; order, and the order is load-bearing here: this syscall's own
                ; exit may deliver a signal it has just unblocked, and that
                ; delivery must nest on a LIVE frame -- doing it after the TCS
                ; below would run a handler on a stack we have already rewound
                ; but not yet returned into.
                ;
                ; Both halves, as crt0's trampoline does: the kernel holds the
                ; real mask, but libc computes sigblock(m) as
                ; sigsetmask(shadow | m), so a stale shadow would reinstate the
                ; block at the caller's next sigblock() -- which for tcsh's
                ; pintr1 is its first act.
                LDA:    $000C,X                  ; saved mask lo16
                STA     _sig_curmask
                LDA:    $000E,X                  ; saved mask hi16
                STA     _sig_curmask+2
                PHX                              ; env: the syscall clobbers X
                LDA     _sig_curmask             ; SYS_SIGSETMASK: A=lo, X=hi
                LDX     _sig_curmask+2
                JSL     SYS_TRAMP
                DFB     SYS_SIGSETMASK_NUM
                PLX

                ; Stash env.pc and env.pb in bank-statics so we can
                ; load them after S restore.
                LDA:    $0004,X                  ; env.pc (16-bit)
                STA     _setjmpPC
                SEP     #$20
                MX      %10
                LDA:    $0000,X                  ; env.pb (1 byte)
                STA     _setjmpPB
                REP     #$20
                MX      %00

                ; Restore DP.
                LDA:    $0008,X
                TCD

                ; Restore DBR.
                SEP     #$20
                MX      %10
                LDA:    $0001,X
                PHA
                PLB
                REP     #$20
                MX      %00

                ; Restore S = env.sp.  After this, we synthesize an
                ; RTL frame on top: push pb, pch, pcl (RTL pops PCL,
                ; PCH, PB and adds 1 to PC).
                LDA:    $0006,X
                TCS

                ; P3-3: restore the fcc frame-base pointer saved at setjmp
                ; (+2..+3), so &local carriers in the resumed frame resolve.
                ; (Locals themselves are n,S, S-relative — restored by the TCS
                ; above; only _fcc_fb-based &local addresses need this.)
                ; X still = env here.
                LDA:    $0002,X
                STA     _fcc_fb

                ; ... and the soft-frame pointer, for the same reason: a frame
                ; resumed by longjmp must see the soft frame it had at setjmp.
                LDA:    $000A,X
                STA     _fcc_sfp

                ; Push the saved PB byte (RTL-frame top).
                SEP     #$20
                MX      %10
                LDA     _setjmpPB
                PHA
                REP     #$20
                MX      %00

                ; Push the saved PC word (PCL at lowest addr — top —
                ; matches RTL's pop order).
                LDA     _setjmpPC
                PHA

                ; Load return value, RTL to (pb : pc + 1).
                LDA     _setjmpVal
                RTL


STDIN_FD        EQU     0
STDOUT_FD       EQU     1
STDERR_FD       EQU     2

SYS_READ_NUM    EQU     3
SYS_OPEN_NUM    EQU     5
SYS_CLOSE_NUM   EQU     6
SYS_LSEEK_NUM   EQU     19
SYS_GETKEY_NUM  EQU     50

; struct __sFILE { short _file; short _flag; } — 4 B per entry.
; Field offsets accessed via DP-pointer (LIBC_DP_TMP),Y.
__sFILE_file    EQU     0
__sFILE_flag    EQU     2
__sFILE_size    EQU     4
LIBC_NFILE      EQU     8                        ; max simultaneous open FILEs

; FILE _flag bits (4.3BSD-compatible subset; buffering bits reserved).
_IOREAD         EQU     $0001
_IOWRT          EQU     $0002
_IONBF          EQU     $0004                    ; reserved — always unbuffered today
_IOEOF          EQU     $0010
_IOERR          EQU     $0020

; SEEK_SET / SEEK_CUR / SEEK_END — match kernel SYS_LSEEK whence values.
SEEK_SET        EQU     0
SEEK_CUR        EQU     1
SEEK_END        EQU     2


O_RDONLY_       EQU     $0000
O_WRONLY_       EQU     $0001
O_APPEND_       EQU     $0008
O_CREAT_        EQU     $0200
O_TRUNC_        EQU     $0400
