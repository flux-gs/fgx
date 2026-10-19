/* ---- fork train V2: BSD exec over SYS_EXECVE ------------------------------
 * execve is a syscall stub, as upstream's is, and libc owns no staging storage
 * at all.  SYS_EXECVE takes A = path, X = the offset of an ARG-BLOCK and Y =
 * that block's bank; the block is argv then envp, a far pointer each.  That is
 * BSD's argument struct -- `struct execa { char *fname; char **argp; char
 * **envp; }' (2.11BSD usr/sys/sys/kern_exec.c:31) -- and, as upstream, it is
 * the CALLER'S FRAME rather than anything the process pre-allocates:
 * `struct execa *uap = (struct execa *)u.u_ap;' (:48) over `int *u_ap;  /' + '*
 * pointer to arglist *' + '/' (usr/sys/h/user.h:51).  blk below is a stack
 * local, so it lives in bank 0 like every 65816 stack.
 *
 * The kernel then walks the caller's vector in place, which is what fuword
 * does upstream: `ap = fuword((caddr_t)uap->argp); uap->argp++;' -- 4.3BSD-Reno
 * kern/kern_exec.c:346 and 2.11BSD kern_exec.c:214, identical code.
 *
 * AN OVER-LONG ARGUMENT LIST is refused by the kernel with E2BIG, where BSD
 * refuses it (`nc >= NCARGS-1', Reno kern_exec.c:373); libc keeps no cap of
 * its own.
 *
 * `path' is still copied, and that is the one piece of this not yet BSD: the
 * kernel reads it as an offset in the caller's data bank, so a path string
 * living anywhere else has to be brought here first.  Widening it belongs with
 * the file_actions half, apple/fgx#304.
 */
static char __lc_exec_path[80];

int execve(char *path, char **argv, char **envp)
{
    char **blk[2];
    unsigned long b;
    int r;

    strcpy(__lc_exec_path, path);
    blk[0] = argv;
    blk[1] = envp;
    b = (unsigned long)&blk[0];
    r = (int)__syscall(11,
                       (unsigned)(unsigned long)__lc_exec_path,
                       (unsigned)b,
                       (unsigned)(b >> 16));
    /* SYS_EXECVE returns only on failure. */
    if (__syscall_c() == 0) errno = r;
    return -1;
}

extern char **environ;

int execv(char *path, char **argv)
{
    /* BSD contract: execv passes the CALLER'S environment "via the external
     * variable environ" -- passing 0 here exec-froze every child of a shell
     * that edits its environment (tcsh's setenv/Setenv repoints environ, and
     * its children saw an EMPTY env: printenv printed nothing and $HOST never
     * propagated, 2026-07-27). */
    return execve(path, argv, environ);
}

