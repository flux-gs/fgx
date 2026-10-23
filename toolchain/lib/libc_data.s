;==============================================================================
; libc_data.s - libc's fixed per-process cells, in every program's data
; segment, read and written DBR-relative by libc.s, crt0 and the C members.
;
; This file forward-references EQUs defined in libc.s:
;
; For multi-bank seg1.link.s, define those EQUs inline at the top of
; the link file before PUT'ing libc_data.s.  See tools/fas/seg1.link.s
; for the canonical pattern.
;==============================================================================

; Path and time staging for the syscalls that take them: libc copies a
; caller's string (or a pair of time_t) here, in the data bank, and the kernel
; reads it through _Sys_CallerBank (src/kernel/syscall.s).
_libc_lstrBufA  DS      128                     ; first string-arg scratch
_libc_lstrBufB  DS      128                     ; second string-arg scratch


;------------------------------------------------------------------------------
; LIBC_DATA_PTR - same-segment 4-byte far pointer (T5-C C6, stdio cells;
; since the curses port fcc also emits it for every `&global` in a data
; initialiser — the target lives in seg1 with the cell, and assembly-time
; resolution works across TUs where FGX2_LONG_PTR's export lookup cannot).
;
; The twin pattern of LIBC_EXPORT: defined HERE so every link that PUTs this
; file assembles without macros.s (the FGX1 hand tools: cu/tip/ntpplay/
; sigtest/ntpinfo/fswbig).  Emits:
;   +0..+1  DA <expr>   16-bit offset, ASSEMBLY-resolved (same segment —
;                       unlike FGX2_LONG_PTR, no fgx_ld export lookup)
;   +2      $00         bank byte, PATCHED at load: fgx_ld scans listing
;                       rows for LIBC_DATA_PTR and emits a bank reloc
;                       targeting the CONTAINING (data) segment
;   +3      $00         pad
; In a non-fgx_ld (FGX1) link the bank byte stays $00 — no worse than the
; old 2-byte cells read wide, and nothing FGX1-linked reads these labels
; (verified: only comments).  Params: ]1 documentary tag; ]2 target expr.
;------------------------------------------------------------------------------
LIBC_DATA_PTR   MAC
                DA      ]2
                DFB     $00
                DFB     $00
                <<<

; stdio's state is 2.11BSD's _iob[] (libc_c/findiop.c), a C global in the
; core; <stdio.h> names stdin, stdout and stderr as &_iob[0..2].


;------------------------------------------------------------------------------
; setjmp/longjmp state.  longjmp synthesizes an RTL frame on the user
; stack; _setjmpPC and _setjmpPB cache the destination across the S
; restore (we can't dereference the env pointer once we've moved S to
; env.sp because env may live in stack-relative memory — though here
; it's bank-static, this layout still keeps things tidy).  _setjmpVal
; stashes the return value.
;------------------------------------------------------------------------------
_setjmpPC       DA      0
_setjmpPB       DA      0                       ; only low byte meaningful
_setjmpVal      DA      0

;------------------------------------------------------------------------------
; fcc signal-handler adapter state (libc_start.s _libc_sigtramp + c_signal
; shim; 2026-07-05 audit / redesign T7).
;   _sig_tramp_off  seg0 offset of crt0's trampoline.  _libc_start stashes it
;                   at startup; 0 = runtime without the adapter (FGX1 crt0s do
;                   not provide it yet) -> c_signal returns SIG_ERR instead
;                   of silently no-op'ing.
;   _sig_c_*        the registered C handler far ptrs (offset word, bank byte
;                   + pad), one cell per kernel-delivered signal.  The set here
;                   must match the kernel's catchable set (signal.s
;                   _SigHndBase), _libc_sigtramp's dispatch and libc's
;                   signal(); all four lists are edited together.
;------------------------------------------------------------------------------
_sig_tramp_off  DA      0
; _sig_curmask - libc's shadow of the kernel's 32-bit signal mask.
;
; DECLARED HERE, NOT AS A C STATIC IN sigmask.c (apple/fgx#53).  crt0's
; _sig_tramp has to block the delivered signal in this shadow and unblock it
; again on return, and crt0 is in EVERY binary while the archive carve puts
; sigmask.c's data only in binaries that call sigblock().  A C static would
; therefore resolve in some links and not others -- addtest is one that fails.
; The cells crt0 already reaches (_sig_tramp_off, _sig_c_*) live here for the
; same reason.
_sig_curmask    DA      0                   ; lo16
                DA      0                   ; hi16
; _sig_c_tab - THE PROCESS'S OWN DISPOSITION TABLE, 32 far cells indexed by
; signal number (cell = sig*4: offset word, bank byte, pad).  This is BSD's
; u_signal[NSIG], which lives in per-process memory there for the same reason
; it does here: the kernel has no business holding one address per signal per
; task (apple/fgx#58).
;
; It replaced five named cells -- _sig_c_int/_alrm/_chld/_term/_hup -- and with
; them the five-signal ceiling on what could be caught.  crt0's _sig_tramp
; indexes this by the signum the kernel hands it; libc's signal() writes it and
; ALSO reads it back as the previous disposition, so this doubles as the
; shadow signal() must return (it used to be a separate `static char
; _sig_disp[32]` in signal.c -- 128 bytes that held the same information).
;
; Entry 0 is unused (there is no signal 0) and entries carry the SIG_DFL(0) /
; SIG_IGN(1) sentinels as well as real pointers, which is why the trampoline
; tests `>= 2` before dispatching.
;
; HERE AND NOT AS A C STATIC, for the reason the cells above it give: crt0 is
; in EVERY binary and must reach this, while the archive carve would place a
; signal.c static only in binaries that call signal().
_sig_c_tab      DS      128                 ; 32 signals x 4-byte far cell

;------------------------------------------------------------------------------
; _sig_act_maskoff - the DATA-BANK OFFSET of sigaction's per-signal sa_mask
; table, or 0 when the binary never called sigaction(2).
;
; This is BSD's `u.u_sigmask[NSIG]', the set a handler runs with blocked in
; ADDITION to its own signal.  Upstream applies it in postsig
; (`p_sigmask |= u.u_sigmask[sig] | mask'); FGX's equivalent point is crt0's
; trampoline, which already saves the pre-delivery mask and blocks the delivered
; signal, so it is the one place that can add a set and unwind it again.
;
; AN OFFSET AND NOT THE TABLE, which is the whole point.  The table is 128 bytes
; (32 signals x a 32-bit set) and `_sig_c_tab' above explains why a cell crt0
; reaches has to live here rather than in a C static -- crt0 is in EVERY binary.
; Paying 128 bytes of data in all ~130 tools for a table nearly none of them use
; is the cost this avoids: sigaction(2) keeps the table as its OWN static, which
; the archive carve places only in binaries that call it, and publishes its
; offset here.  Two bytes everywhere, 128 where it is used.  `_sig_tramp_off'
; above is the same arrangement pointing the other way.
;
; Zero means "no sa_mask table", and the trampoline skips the whole arm -- so a
; binary using plain signal(2) pays one LDA and a branch per delivery.
_sig_act_maskoff DA     0                   ; data-bank offset, or 0

;------------------------------------------------------------------------------
; errno (2026-07-06): the cell errno.h promises.  Written by the syscall
; shims' failure tails (SYSCALL_ERR / SYSCALL_ERRSW in fcc_libc_shims.s) with
; the kernel's A-errno; C code reads it via `extern int errno`.
; NOTE: a port must NOT define its own `int errno;` (duplicate label) —
; elvis's system.c has one to delete when elvis comes back.
;------------------------------------------------------------------------------
errno           DA      0


;------------------------------------------------------------------------------
; vfork stash (fork train Stage V0).  The frameless vfork stub in libc.s
; parks the caller's 3-byte RTL address + the syscall result here across the
; trap, because the vfork child reuses the parent's stack bytes.  Shared
; parent/child by definition of vfork; see the stub comment for the nested-
; vfork UB note.
;------------------------------------------------------------------------------
_vfork_ret      DS      4               ; RTL addr: PC word + bank byte + pad
_vfork_res      DS      2               ; A result carried across the rebuild
_vfork_sfp      DS      2               ; parent's _fcc_sfp (soft-frame ptr), same
                                        ; reason as _vfork_fb below.  Inert until
                                        ; the exile predicate turns on (bank-0
                                        ; campaign 1.2) -- carried NOW because it
                                        ; is the same shape, and every place that
                                        ; saves frame state has to move together
                                        ; or the one that was missed shows up as
                                        ; a corrupted local months later.
_vfork_fb       DS      2               ; parent's _fcc_fb (fcc frame base), stashed
                                        ; before the trap and restored on resume: the
                                        ; child clobbers the shared _fcc_fb cell before
                                        ; _exit/exec, so &local in the resumed parent
                                        ; would otherwise compute off a stale base
                                        ; (waitpid(&stack_local) -> status lost).
_vfork_sigtab   DS      128             ; parent's _sig_c_tab, stashed before the
                                        ; trap and restored on resume.  SAME SHAPE
                                        ; AND SAME REASON AS _vfork_fb ABOVE, and
                                        ; the reason that one's comment gives --
                                        ; "every place that saves frame state has
                                        ; to move together or the one that was
                                        ; missed shows up ... months later" -- is
                                        ; how this one was found, months later.
                                        ;
                                        ; apple/fgx#253.  The disposition table is
                                        ; PROCESS state living in the DATA BANK, and
                                        ; a vfork child shares that bank, so the
                                        ; child's own `signal()' calls land in the
                                        ; PARENT'S table.  tcsh's does exactly that
                                        ; before it execs (sh.sem.c:432,
                                        ; `signal(SIGINT, vffree)'), so the parent
                                        ; shell came back from every external
                                        ; command with its SIGINT handler pointing
                                        ; at the CHILD'S cleanup routine -- whose
                                        ; tail is `_exit(1)' (sh.sem.c:617).  The
                                        ; next ^C then ran it: the shell exited 1,
                                        ; and because it died owning the terminal
                                        ; its parent was left SIGTTIN-stopped on a
                                        ; t_pgrp naming a dead group.  MEASURED:
                                        ; the cell reads $8E57/$60 (`pintr', seg4)
                                        ; before the fork and $D215/$61 (`vffree')
                                        ; after it.
                                        ;
                                        ; UPSTREAM HAS NO SUCH TABLE TO CORRUPT, so
                                        ; there is nothing to port: 2.11BSD keeps
                                        ; dispositions in the KERNEL, per proc
                                        ; (u_signal[]/p_sigcatch), and vfork gives
                                        ; the child a proc of its own -- so a
                                        ; child's signal() cannot reach its
                                        ; parent's.  Keeping the C handler pointer
                                        ; in user data is FGX's (crt0 needs a far
                                        ; pointer the kernel cannot hold), so
                                        ; preserving it across vfork is FGX's too.
_vfork_sigmask  DS      4               ; parent's _sig_curmask, stashed with the
                                        ; table above and for the same reason.
                                        ;
                                        ; apple/fgx#253, second pass.  The mask
                                        ; shadow is process state in the shared
                                        ; data bank exactly as `_sig_c_tab' is,
                                        ; and the same tcsh child writes it
                                        ; before it execs -- `sigsetmask(csigmask)'
                                        ; in the child branch (sh.sem.c:392 is
                                        ; `else { /* child */', :399 is the
                                        ; call).  Upstream cannot: 2.11BSD's
                                        ; mask is p_sigmask, kernel per-proc
                                        ; state copied into a NEW proc struct at
                                        ; fork (kern_fork.c:176).
                                        ;
                                        ; AND IT DOES NOT STAY IN USERLAND.
                                        ; `_sig_tramp' writes this shadow BACK
                                        ; INTO THE KERNEL on the way out of a
                                        ; handler (libc_start.s @st_back), so a
                                        ; parent left holding the child's mask
                                        ; reinstalls it for real at its next
                                        ; delivery -- which for tcsh can unblock
                                        ; SIGCHLD inside the hold `pfork' takes
                                        ; across fork+palloc, the exact window
                                        ; libc_c/sigmask.c's own header says
                                        ; that hold exists to protect.
