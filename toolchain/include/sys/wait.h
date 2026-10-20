/* FGX libc — sys/wait.h.  wait(2)/waitpid(2) status decode + spawnv().
 *
 * FGX wait-status encoding (verified against src/kernel/process.s):
 *   - normal _exit(code):  status = code << 8   (HIGH byte = exit code, LOW
 *     byte = 0).  The kernel builds this with XBA at process.s:429; libc's
 *     system() extracts the code via the same XBA.
 *   - stopped (WUNTRACED): status = (WSTOPSIG << 8) | 0x7F   (LOW byte $7F,
 *     HIGH byte = stop signal), built at process.s:1086.
 *   - signal termination is NOT currently produced by the kernel; the
 *     WIFSIGNALED/WTERMSIG macros follow the classic BSD low-byte convention
 *     so they are correct if/when it is.
 *
 * fcc `int` is 16-bit SIGNED and `>>` is ARITHMETIC (sign-extends), so an exit
 * code >= 128 (status >= 0x8000) sign-extends on the shift — WEXITSTATUS/
 * WSTOPSIG MUST mask with & 0xFF after the shift.  Do not drop the mask.
 *
 * Prototypes are K&R (unspecified args) to match the port's call sites.
 */
#ifndef _SYS_WAIT_H
#define _SYS_WAIT_H

/* waitpid() options. */
#define WNOHANG         1               /* return 0 rather than block */
#define WUNTRACED       2               /* also report stopped children */

/* Status decode, over an `int' filled by waitpid()/wait() OR a `union wait'.
 * 4.3BSD-Reno's form (sys/wait.h): every macro reads its argument through
 *
 *     #define _W_INT(w)  (*(int *)&(w))    -- "convert union wait to int"
 *
 * so the same spelling serves 4.3BSD code that declares `int status' and
 * 2.11BSD code that declares `union wait status' (Vixie cron's WAIT_T), and
 * the argument must be an lvalue, as upstream's must.  The union is laid out
 * below so its w_status IS that int.  The `& 0xFF' after each `>> 8' is FGX's:
 * see the header note on the arithmetic shift. */
#define _W_INT(w)       (*(int *)&(w))
#define _WSTATUS(x)     (_W_INT(x) & 0177)
#define WIFEXITED(s)    (_WSTATUS(s) == 0)                  /* normal _exit */
#define WEXITSTATUS(s)  ((_W_INT(s) >> 8) & 0xFF)           /* exit code (HIGH byte) */
#define WIFSIGNALED(s)  (_WSTATUS(s) != 0177 && _WSTATUS(s) != 0)
#define WTERMSIG(s)     (_WSTATUS(s))                       /* termination signal */
#define WIFSTOPPED(s)   (_WSTATUS(s) == 0177)               /* stopped child */
#define WSTOPSIG(s)     ((_W_INT(s) >> 8) & 0xFF)           /* stop signal (HIGH byte) */
#define WCOREFLAG       0200
#define WCOREDUMP(s)    (_W_INT(s) & WCOREFLAG)

int waitpid(int pid, int *status, int options);  /* SYS_WAITPID */

/* wait(&status) -- reap ANY child.  Implemented as waitpid(-1, status, 0) in
 * libc_c.c, and deliberately so: the raw SYS_WAIT path drops the status
 * pointer's BANK, so a caller passing an fcc local (a bank-0 hardware-stack
 * address) had its status written into the data bank instead.  That is the bug
 * that made every bsh `$?` read 0.  Declared here since 2026-08-04 -- it was
 * described as "no binding exists yet", which was true when this header was
 * written and had stopped being true; init(8) reached it through an implicit
 * declaration. */
/* union wait -- 2.11BSD usr/sys/h/wait.h:23-40, with its member aliases.
 * Added at UFS 2.1 for fsck(8)'s preen driver, which declares `union wait
 * status;' and reads status.w_retcode.  The W* macros above take it too.
 *
 * The bitfield order IS the layout, and it agrees with the int macros above:
 * w_Termsig occupies the low seven bits and w_Retcode the high byte, which is
 * what WTERMSIG((s)&0x7F) and WEXITSTATUS((s)>>8) already assume. */
union wait {
        int     w_status;               /* used in syscall */
        struct {
                unsigned short  w_Termsig:7;    /* termination signal */
                unsigned short  w_Coredump:1;   /* core dump indicator */
                unsigned short  w_Retcode:8;    /* exit code if w_termsig==0 */
        } w_T;
        struct {
                unsigned short  w_Stopval:8;    /* == W_STOPPED if stopped */
                unsigned short  w_Stopsig:8;    /* signal that stopped us */
        } w_S;
};

#define w_termsig       w_T.w_Termsig
#define w_coredump      w_T.w_Coredump
#define w_retcode       w_T.w_Retcode
#define w_stopval       w_S.w_Stopval
#define w_stopsig       w_S.w_Stopsig

/* 2.11BSD usr/sys/h/wait.h:51.  The value w_stopval carries when the child is
 * stopped rather than dead, and the constant upstream's own WIF* macros test
 * against -- so a port that reaches for the union (which is what upstream's
 * macros take) can spell the test the way upstream spells it instead of
 * writing 0177 out.  It agrees with WIFSTOPPED's 0x7F above. */
#define WSTOPPED        0177

int wait(int *status);

/* spawnv(path, argv) -> child pid (zombie; reap with waitpid), or -1.
 * FGX-simplified 2-arg binding for SYS_POSIX_SPAWN (#43); envp is empty (no
 * envp arg — a bare `0` for it would push a 2-byte int under K&R and corrupt
 * the frame).  argv MUST be a data-bank global/static (see c_spawnv in
 * fcc_libc_shims.s for the constraint).  Deliberately NOT named posix_spawn
 * (that name is left free for a conforming wrapper). */
int spawnv(char *path, int *argv);

#endif /* _SYS_WAIT_H */
