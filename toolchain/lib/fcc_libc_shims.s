;==============================================================================
; fcc_libc_shims.s — cc-target wrappers around FGX userland libc.
;
; PUT-included by tests via _wrap_libc.s.  Each shim takes cc-target stack
; args (param[0] deepest, param[N-1] on top, retn @ 1,S), marshals to FGX
; libc's register convention (X/Y/A inputs), JSRs the underlying libc
; function, normalises return value to A.
;
; Long-pointer ABI (post 24-bit refactor): pointer args take 4 bytes
; (offset:2 + bank+pad:2).  THE BANK BYTE IS LOAD-BEARING: under FGX2 +
; soft-stack a caller pointer can name the data bank, the soft-stack bank,
; the heap, or bank 0, and the kernel reads every buffer through
; _Sys_CallerBank (= DBR at the JSL).  A shim that passes or fills a caller
; buffer MUST honor the pushed bank — either swap DBR to it around the
; syscall (SYSCALL_PTRARG below / the c_read pattern), read/write through a
; seeded long pointer (LIBC_DP_LP0 / _fcc_ptr2), or stage the bytes into a
; DBR scratch via _libc_lstr_to_dbr.  Dropping the bank is the 2026-07-05
; audit's nine-shim bug class (see docs/history/plans/architecture-redesign.md §I.8).
;
; Stack-offset formula: param[i] offset = 3 + sum(byte_size(param[j])
; for j > i), where byte_size = 4 for pointers, 2 for int/char.
;   c_strlen(s):       s  @ 3
;   c_strcmp(a,b):     a  @ 7,  b  @ 3
;   c_strncmp(a,b,n):  a  @ 9,  b  @ 5,  n  @ 3
;   c_memset(p,c,n):   p  @ 7,  c  @ 5,  n  @ 3
;   c_fread(buf,sz,n,fp): buf @ 9, sz @ 7, n @ 5, fp @ 3
;
; All shims expect MX %00 on entry (cc-target convention).
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; SYSCALL_PTRARG ]1 — swap DBR to a caller-pushed pointer-arg BANK for the
; duration of a syscall, so _Sys_CallerBank (= DBR at the JSL) names the bank
; the pointer actually points into.  ]1 = the bank byte's stack offset AFTER
; the PHB (pre-PHB offset + 1).  Preserves X/Y; leaves MX %00.  Pair with a
; PLB after the JSL (save A across it: TAY / PLB / TYA).  This is the ONE
; blessed pattern for single-pointer syscall shims — hand-rolled copies of it
; are how the audit's nine wrong-bank shims happened.
;------------------------------------------------------------------------------
SYSCALL_PTRARG  MAC
                PHB
                SEP     #$20
                MX      %10
                LDA     ]1+LIBC_FAR,S
                PHA
                PLB
                REP     #$20
                MX      %00
                <<<

;------------------------------------------------------------------------------
; SYSCALL_ERR ]1 / SYSCALL_ERRSW ]1 — the blessed FAILURE tails (2026-07-06):
; on the C=0 path the kernel leaves errno in A; store it into the libc_data
; `errno` cell (making errno.h's promise true) and return ]1 (the -1 / 0 /
; NULL-offset error value).  ERRSW is for shims with a SYSCALL_PTRARG/PHB
; swap pending: the store MUST happen after the PLB, or errno lands in the
; buffer's bank instead of the data bank.
;------------------------------------------------------------------------------
SYSCALL_ERR     MAC
                STA     errno
                LDA     #]1
                <<<

; Shared 3-byte DP long-ptr slots ($F2-$F7, free per the dpmap layout).
; Used by the remaining hand str/mem shims AND by the __asm loops in the
; C-converted pile TU (lib/libc_c/libc_c.c) — keep these EQUs even after
; the last hand user converts.
c_strcmp_a      EQU     $F2                      ; 3-byte long-ptr (arg1)
c_strcmp_b      EQU     $F5                      ; 3-byte long-ptr (arg2)
SYSCALL_ERRSW   MAC
                TAY
                PLB
                TYA
                STA     errno
                LDA     #]1
                <<<

;------------------------------------------------------------------------------
; _libc_ptrret — RETIRED (T5-C orphan sweep): zero callers remain (the C pile
; serves every fcc binary; no hand-asm tool called this entry).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fopen — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_freopen — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fclose — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_popen — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_pclose — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_fread — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fwrite — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fgetc — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_getchar — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fputc — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fputs — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_putchar — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_feof / c_ferror / c_fflush / c_clearerr — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_malloc — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_free — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_realloc — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_lseek — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_atoi — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_atol — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_exit — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_fseek — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_ftell — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_perror — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_strerror — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
; The strerror message-table ENGINE below stays asm until the pile grows a
; data segment (T5-C data tier).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_getfsstat — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_ifctl — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;==============================================================================
; SP4 libc gaps (2026-05-31): read / write / fileno / getenv / fgets / strchr.
; Needed to link vi (fgx.c read(0)/write(1); fileio read/write/fileno;
; cmdline strchr; main getenv).  read/write mirror c_fread/c_fwrite minus the
; sz*n and FILE*->fd (fd is already an int).  getenv has no environment on
; FGX (NULL); fgets is a v1 stub (only the deferred tags reader uses it).
;==============================================================================

;------------------------------------------------------------------------------
; c_read — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_write — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_fileno — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_getenv — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_tgetent — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_tgetstr — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_tgetnum — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_tgetflag — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_fgets — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; c_strchr — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_system — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s):
; /bin/sh -c via the C spawn surface; argv table + literals are PILE DATA
; (lib/libc_c_data.s, the data-plumbing tier).  _libc_build_envp retired
; with it (the C pile's __lc_build_envp took over in batch 8).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_spawnv — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_spawnve — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;==============================================================================
; BSD UDP socket wrappers (2026-06-05).  cc-target shims over the kernel's
; SYS_SOCKET/BIND/SENDTO/RECVFROM/SETSOCKOPT syscalls (numbers 71..75).
;
; All entered MX %00, JSR-called (2-byte return at 1,2), caller cleans args.
; Arg slots: ints are 2 bytes, pointers are 4 bytes (offset lo16 + bank +
; pad), pushed left-to-right so the rightmost arg sits at the lowest offset
; (same layout c_ifctl documents).
;
; Banks: bind/connect hand the kernel the sockaddr's bank as the call's DBR
; (one pointer, so the caller bank is exact).  send/recv/sendto/recvfrom carry
; the buffer's bank in the arg block beside its offset (apple/fgx#480), because
; the block itself is read through the caller bank and the buffer need not be
; there.
;
; Return convention: C=1 -> kernel's A (fd / byte count); C=0 -> -1.
;==============================================================================

;------------------------------------------------------------------------------
; c_socket — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_bind — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_setsockopt — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_sendto — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_recvfrom — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_connect — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_send — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_recv — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_close — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_pipe — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_dup — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_dup2 — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_gtty/c_stty/_c_sgtty — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_ioctl — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;==============================================================================
; POSIX file syscalls (open/creat/stat/unlink) + rindex/strrchr.
;
; These pass a userland pointer (path/buf) to a SYS_* trampoline.  The kernel
; reads/writes it through _Sys_CallerBank (= DBR at the JSL — see
; src/kernel/syscall.s), so each shim swaps DBR to the pointer's bank before the
; trampoline and restores it after, exactly like c_read/c_fread.  That makes
; them multi-bank-safe (e.g. a malloc'd path), not just own-bank.  fcc arg ABI:
; FIRST arg sits at the HIGHEST stack offset; char* = 4-byte long ptr (offset16
; @ +0, bank @ +2); int = 2 bytes; JSR return addr at 1,S..2,S.  After a PHB the
; stack refs shift +1.
;==============================================================================

;------------------------------------------------------------------------------
; c_open — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_creat — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; _libc_epoch / _ep_* — RETIRED (T5-C batch 12): epoch math lives in C
; (__lc_epoch in lib/libc_c/libc_c.c) for both c_stat and c_time.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_time — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s):
; ReadTimeHex via __asm + epoch math in C.
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_stat — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s):
; native->POSIX translate + epoch math now in C (__lc_epoch).  _libc_epoch
; below stays for c_time until its own conversion (T5-C data tier).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_unlink — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_strrchr — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_getkey — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_pollkey — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_ticks — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_yield — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_slotscan — CONVERTED TO C (T5-C); now in lib/libfgx_c/libfgx.c -> lib/libfgx.s (BSD-foundations P1).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_signal(sig, handler) — REAL signal(3) over the fcc handler adapter
; (2026-07-05 audit; replaces the silent no-op stub that SHADOWED the real
; libc.s wrapper and made every install vanish).
;
; Stack: 3..6 = handler (4-byte far fn ptr: 3,4 = offset, 5,6 = bank+pad),
; 7,8 = sig.  The kernel's delivery contract is register+RTL into a 16-bit
; offset in TCB_CodeBank (seg0), which no fcc function can satisfy — so we
; record the C handler's far ptr in libc_data (_sig_c_int/_sig_c_alrm) and
; register crt0_lib.s's _sig_tramp (seg0 offset published in _sig_tramp_off)
; with the kernel; the trampoline re-shapes delivery into a normal far call.
; SIG_DFL(0)/SIG_IGN(1) sentinels forward to the kernel verbatim (its
; handler table treats <2 as "no handler").  Returns A = previous C handler
; offset (0 if none), or -1 (SIG_ERR) on kernel error / missing adapter
; (_sig_tramp_off==0: an FGX1 crt0 that doesn't provide the trampoline yet).
; Kernel-delivered (catchable) signals are SIGINT/SIGALRM/SIGCHLD/SIGTERM/
; SIGHUP -- the set in signal.s _SigHndBase.  For any OTHER signal, SIG_DFL and
; SIG_IGN are still honored (the kernel's per-task IGN mask covers every
; signal), but a real handler has nowhere to live: libc accepts and remembers
; it so a prev = signal(s,h) / signal(s,prev) round-trip works, and it is never
; delivered.  The kernel itself now answers EINVAL to that install.
;
; ⚠️ HANDLER-BODY CONTRACT (docs/userland-abi.md §6A): the C handler may
; ONLY set a plain int flag and return.  Delivery is at syscall exit and
; the trampoline preserves DBR + the syscall's A/Y/C — NOT the DP scratch
; (_fcc_ptr / _fcc_long_hi / LIBC_DP_* / FPR band) or the libc bank
; statics, which may be live in the interrupted shim.  A handler that
; calls libc, does pointer/long arithmetic, or longjmps silently corrupts
; the interrupted call (verified-good shape: multibank c29_handler.c).
;------------------------------------------------------------------------------
_C_SIGINT       EQU     2                         ; kernel ABI (include/loader.s)
_C_SIGALRM      EQU     14

; c_signal — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s);
; the §6A handler-body contract above still governs C handlers.

;------------------------------------------------------------------------------
; c_kill — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_waitpid — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; c_getcwd — CONVERTED TO C (T5-C, lib/libc_c/libc_c.c -> lib/libc_c.s).
;------------------------------------------------------------------------------
