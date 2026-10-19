/* lib/syscall.h - the FGX C toolchain syscall CONTRACT (documentation).
 *
 * The libc/runtime/crt0 in lib/ are parameterized over exactly these LINK-TIME
 * symbols. A platform (FGX today; the test harness later) makes the libc work by
 * defining their VALUES and providing a trampoline at SYS_TRAMP. Nothing in lib/
 * hard-codes a platform: the symbols are resolved by the linking program.
 *
 *   Symbol           Meaning
 *   ---------------  --------------------------------------------------------------
 *   SYS_TRAMP        Address of the syscall trampoline. Called as:
 *                        JSL SYS_TRAMP ; DFB <syscall-number>
 *                    FGX value: $000328.
 *   SYS_EXIT         Syscall number used by crt0 to terminate a process (FGX: 1).
 *   SYS_READ         read(fd, buf, n)        (FGX: 3).
 *   SYS_WRITE        write(fd, buf, n)       (FGX: 4).
 *   SYS_OPEN         open(path, flags)       (FGX: 5).
 *   SYS_CLOSE        close(fd)               (FGX: 6).
 *   SYS_LSEEK        lseek(fd, off, whence)  (FGX: 19).
 *   SYS_GETKEY       raw console getkey      (FGX: 50).
 *   SYS_GETKEY_NUM   getkey syscall number used by the libc getkey path (FGX: 50).
 *   SYS_GETFSSTAT    getfsstat(buf, n)       (FGX: 67).
 *
 * BUFFER-BANK ABI (critical - see FGX feedback_libc_buffer_must_be_data_bank,
 * feedback_dbr_swap_dbr_rel_reads, feedback_libc_shim_longptr_audit):
 *   For read/write the libc sets the data bank register (DBR) to the I/O buffer's
 *   bank before JSL SYS_TRAMP; the trampoline reads/writes the buffer through DBR.
 *   ANY platform implementing SYS_TRAMP MUST honor this convention.
 *
 * AUTHORITY: FGX owns the VALUES. The numbers above are sourced from FGX
 * include/loader.s; SYS_TRAMP from the userland .link.s files; SYS_GETKEY_NUM from
 * src/userland/lib/libc.s. lib/fgx_syscalls.inc is a machine-extracted COPY for
 * standalone consumers (e.g. the future harness). The golden suite (tests/) defines
 * the EQUs inline per-fixture in _wrap.s and does not consume fgx_syscalls.inc.
 * Keep fgx_syscalls.inc in sync with FGX. (This .h is documentation; the asm resolves
 * the EQUs at link time.)
 */
