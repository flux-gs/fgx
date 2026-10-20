# readv(2)/writev(2) the BSD way: one uio, one fo_rw call (apple/fgx#486)

Decision (the maintainer, 2026-09-22): the full 2.11BSD structure, not the libc
gather. Recorded on #486 and in the project notes.

## Upstream, as read

- `vendor/2.11BSD/usr/sys/sys/sys_generic.c`:
  - `readv()` :57-79 and `writev()` :102-124 refuse `iovcnt > 16` with
    EINVAL, `copyin` the vector into `aiov[16]`, and call `rwuio()`.
  - `rwuio()` :127-171:
    - checks the descriptor's FREAD/FWRITE (EBADF);
    - sums `iov_len` into `uio_resid` and refuses a wrapped total with EINVAL;
    - calls `(*Fops[fp->f_type]->fo_rw)(fp, uio)` ONCE;
    - reports `count - uio_resid`;
    - if interrupted after some bytes moved, reports the count, not the error.
  - `read()`/`write()` are the one-entry case of the same path (:84-100).
- `Fops[] = { NULL, &inodeops, &socketops, &pipeops }` (:34). Each `fo_rw` consumes
  the whole uio:
  - `ino_rw` (sys_inode.c:38): files, and devices through `cdevsw` `d_read/d_write(dev, uio, flag)`;
  - `soo_rw` into `sosend`/`soreceive`;
  - `pipe_rw` into `readp`/`writep` (sys_pipe.c:89-154).
- `uiomove()` (kern_subr.c:18) walks the iovecs, so no `fo_rw` knows how many
  entries it was given.

## FGX today (mapped 2026-09-22 on main 479e14abd)

- **Vnodes already have this shape.**
  - Every descriptor open(2) returns is a vnode (`_Fs_RootOpen` -> far bank).
  - read/write reach `_Sys_DevRead`/`_Sys_DevWrite` -> `dev_rw` (far/dev_mount.c) ->
    `rwcommon` (vfs/vfs_syscalls.c:324), which builds a ONE-entry uio and calls
    `fo_read`/`fo_write`. `vn_read`/`vn_write` -> `VOP_READ`/`VOP_WRITE`.
  - Terminals and devices opened by name go on to `spec_read`/`spec_write` ->
    `_Chardev_Bulk` with the uio -> the driver's bulk op (`ttread`/`ttwrite` for
    tty lines, the pty ops, serial, klog).
- **Three descriptor types do not**, and take a single buffer through core
  fileops arms:
  - socket: `_RdOp_Socket`/`_WrOp_Socket`, into net.mod's transports;
  - pipe: `_RdOp_Pipe`/`_WrOp_Pipe`, into net.mod's `_Pipe_Read`/`_Pipe_Write`;
  - the boot console pseudo-FCB that `_Fcb_SeedStdFds` puts in fds 0/1/2:
    `_WrOp_Console`, a per-byte `Con_Write` loop; its read already builds a
    uio for `ttread`.
- **DTYPE_CHARDEV appears unreachable.**
  - Nothing sets `FCB_FL_CHARDEV`: `git grep` finds only tests, at fcb.s:1234,
    fs.s:1672/1770 and syscall.s:5471.
  - So `_RdOp_Chardev`/`_WrOp_Chardev` and their per-byte loops look dead in
    the core bank.
- **Syscall numbers.** read=3 and write=4. BSD's readv/writev numbers 120/121
  are `sigprocmask`/`setitimer` here, and `SYS_NUM_MAX` = 121.
- **uiomove** lives in vfs.mod (kern_subr.c). The tty bank and klog.mod reach it
  through resolved shims; the core bank has none.
- **Byte budgets** (as last recorded):

  | Bank | Free |
  |---|---|
  | core | 175 (42dd79135) |
  | far | 1,176 |
  | tty | ~21 KB |
  | vfs.mod | unmeasured recently (94 at the name-cache move) |

## Order (the maintainer, 2026-09-22): conversions first, syscalls last

U0 -> U2 -> U3 -> U4 -> U1.  Converting pipes, sockets and the console before
the syscalls exist means U1 lands with every descriptor type consuming a uio,
so no interim entry-by-entry walk is ever written.
Syscall numbers 122/123: the tree's policy since the 2026-09-13 syscall review
is BSD's number when free, above the table when spent (120/121 are spent), and
every binary is built against FGX's numbers, so not sharing BSD's costs nothing.

## Increments

**U0: measure, then delete the dead chardev arms.**
- Prove `FCB_FL_CHARDEV` is never set at run time: a trap in the arm, the suite green.
- Then delete `_RdOp_Chardev`/`_WrOp_Chardev` and their loops.
- This frees core-bank bytes before anything is added there.

**U1: SYS_READV / SYS_WRITEV over one uio.**
- New numbers at 122/123, with `SYS_NUM_MAX` raised. Retired stub slots are not
  reused, because an old binary would hit the wrong call.
- ABI mirrors read/write:
  - A = fd, X = iovec array offset, Y = iovcnt;
  - the array's bank is the caller's DBR, set by libc's `__syscall_db`;
  - each `iov_base` carries its own bank, since fcc pointers are 4 bytes.
- The far bank does what `readv`/`writev` + `rwuio` do:
  - `iovcnt > 16` is EINVAL;
  - the vector is copied into a kernel `aiov[16]`;
  - the lengths are summed, and a total past `UIO_MAXRESID` is EINVAL;
  - one uio is built and `fo_read`/`fo_write` is called once;
  - the count is reported, with the count winning over an interrupt once bytes moved.
- `rwcommon` becomes the one-entry case of this, as `read()`/`write()` are
  upstream, rather than a second copy of it.
- Vnode descriptors get BSD's behaviour at once: files, `/dev/console`, every
  terminal. That covers syslogd's targets, so #486's interleaving is fixed here.
- It runs after U2-U4, so every descriptor type already consumes a uio and
  there is no entry-by-entry walk.
- libc: `readv`/`writev` become the syscalls, and uio.c's loop goes.

**U2: pipes take a uio.**
- `pipe_rw` -> `readp`/`writep` in 2.11BSD's shape (sys_pipe.c:89-154), with the
  ring copy done by walking iovecs.
- net.mod's loopback reuses the pipe bodies (net_loop.s), so it comes along.

**U3: sockets take a uio.**
- `soo_rw` -> the transport send/receive walking the uio. This is the base
  `sendmsg`/`recvmsg` needs (2.11BSD uipc_syscalls.c), which are a later,
  separate item.

**U4: the console pseudo-FCB.**
- Either retire it, so fds 0/1/2 are `/dev/console` vnodes as they are once
  getty and login have run; or give it a uio write arm into `ttwrite` like its
  read.
- Decide by reading how upstream init sets up the console (2.11BSD
  sbin/init/init.c).
- After U4 every descriptor type consumes a uio, and U1 can follow.

## Tests (each red before its fix)

- **U1:**
  - `writev` of a 6-entry vector to a file reads back byte-exact;
  - 17 entries is EINVAL;
  - a vector totalling over 65535 is EINVAL;
  - `readv` scatters one read across entries;
  - `writev` to a pipe, then one `read` returns every byte in one call (after U2);
  - old libc behaviour is a separate write per entry, which a pty or pipe
    reader can see as separate reads.
- **U2/U3:** the same vector tests on a pipe and on a loopback socket.
- **Regressions:** the suite, the gate, and the syslog tests (slogprobe, klogprobe).
