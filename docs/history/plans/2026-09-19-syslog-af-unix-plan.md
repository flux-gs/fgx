# AF_UNIX SOCK_DGRAM + syslog(3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Assembly caveat.** The 65816 blocks below are the intended shape in this
> codebase's house style, not assembler output. Each task's verify step
> assembles and runs; treat a build error as the normal TDD loop, not as a
> defect in the plan. Do NOT hand assembly tasks to a subagent: DP/scratch
> aliasing has produced bugs that way before.

**Goal:** `syslog(3)` delivers to a bound `/dev/log` socket instead of stderr,
so a log line lands in one deterministic place rather than on whatever tty the
caller happened to hold.

**Architecture:** AF_UNIX SOCK_DGRAM as a fourth transport tag (`XPORT_UNIX`)
in FGX's existing socket-descriptor table, delivering through one framed
pipe.s ring owned by the *bound* socket. The name lives on the UFS as a real
`IFSOCK` inode created through `VOP_CREATE`. No new syscall, no mbuf layer, no
`struct socket`.

**Tech Stack:** Merlin32 65816 assembly (`src/modules/net/`, `include/`), C for
the VFS (`src/kernel/vfs/`), fcc C for libc and the probe, ninja build,
`tools/mame_test/run.py` harness under MAME.

**Spec:** `docs/history/plans/2026-09-19-syslog-af-unix-design.md`

## Scope

This plan implements **increments 1-3** of the spec: the transport, the name,
and libc. That is a coherent shippable unit -- it ends with `su`'s message
landing in one place, which is the reported symptom.

One spec budget defers with them: the `NPIPE 8` headroom check wants a live
`syslogd` plus a shell pipeline to count against, so it belongs in that plan,
not this one. What this plan proves instead is the property that makes the
count small -- one ring per bound socket, not per client (Task 2).

**Increments 4-5 (`/dev/klog` + `syslogd` + `logger(1)` + `/etc/syslog.conf`)
get their own plan** and depend on this one. They are a separate subsystem: a
daemon and a chardev, with four missing libc calls (`sigaction`,
`sigprocmask`, `setitimer`, `getservbyname`, `daemon(3)`) as prerequisites.
Do not start them from this document.

## Global Constraints

- **ASCII only** in every FGX file. No em-dashes. Use `--`.
- **Comments describe the CURRENT state only.** No "this used to be", no dated
  measurement transcripts. History belongs in the commit body and the project notes.
  This plan retires three comments that become false; each retirement is a
  step, not an afterthought.
- **Every ported file needs a `docs/PROVENANCE.md` row.**
  `tools/check_provenance.py` fails the build without one.
- **Name the upstream file and function in the commit body.** Commit bodies are
  the changelog: informational, no names, no CI/process, no follow-ups.
- **Fix the toolchain, never work around it.** If fcc rejects something here,
  fix fcc and add a regression fixture. No per-tool asm stub, no local
  reimplementation of a libc function, no sed over generated output.
- **Every probe carries a positive control** -- a known-bad input it must call
  bad. A check whose tool did not run looks like a pass.
- **The gate has a seconds ratchet** (`tools/gate_budget.py`, zero headroom).
  Adding a gate test means retiring one, named in the same commit.
- **Never self-merge an MR. Ask before pushing a feature branch**
  (needs `ALLOW_FEAT_PUSH=1`).
- **Adding a file to `disk_src` needs the ninja regen:**
  `python3 tools/ninja/gen.py -o build.ninja && ninja`. A plain `ninja` will
  not notice -- the regen edge's inputs are gen.py and the manifests, not
  `disk_src`. Files under `disk_src/bin`, `sbin`, `testbin` additionally need a
  `tools/ninja/manifest.json` entry or `mkimage.sh` prunes them.
- **Branch:** `feat/af-unix-syslog`, cut from `main`. Announce when the tree
  moves.

---

## File Structure

**Modified:**

- `include/socket.s` -- `XPORT_UNIX`, two new `SOCK_*` record fields,
  `SOCK_REC_SIZE` 12 -> 14.
- `include/modules.s` -- four new `NETOP_*` offsets are NOT needed; the AF_UNIX
  arms hang off the existing ops. Only `SOCKTBL_BLK_SIZE`'s comment moves.
- `src/modules/net/net.s` -- `net_op_socket`'s AF_UNIX arm; `_Unp_*Try` hooks in
  `net_op_bind`, `net_op_connect`, `net_op_send`, `net_op_recv`,
  `net_op_sendto`, `net_op_recvfrom`; `net_op_table` unchanged.
- `src/kernel/vfs/ufs_vnops.c` -- `ufs_create`'s `VSOCK` arm; `ufs_mknod`'s
  stale "this kernel has neither" comment.
- `src/kernel/vfs/vnode.h` -- the `v_un` comment's "Sockets never arrive".
- `toolchain/lib/libc_c/syslog.c` -- rewritten onto the socket.
- `toolchain/include/syslog.h` -- the missing macros; the header comment's
  "FGX has no syslogd" paragraph.
- `tools/ninja/manifest.json` -- the `unixprobe` tool + staging entries.
- `tools/gate.sh` -- one new case, one retired.
- `docs/PROVENANCE.md`, `docs/CHANGELOG.md`.

**Created:**

- `src/modules/net/unp.s` -- the AF_UNIX transport. Its own file, not appended
  to `net.s` (2023 lines already), because it has one responsibility and the
  `_Unp_*Try` entry points are its whole interface.
- `toolchain/lib/libc_c/strftime.c` -- `strftime(3)`.
- `src/userland/unixprobe/unixprobe.c` + `unixprobe.link.s` -- the probe.
- `tools/mame_test/tests/unixdgram.json`, `tools/mame_test/probes/unixdgram.json`.
- `src/userland/man/pages/man4/unix.4` -- the man page, with BUGS.

---

## Task 1: XPORT_UNIX socket() arm, no ring yet

`socket(AF_UNIX, SOCK_DGRAM, 0)` returns a descriptor that costs no W5100
hardware socket. `SOCK_STREAM` is refused. Nothing sends yet.

**Files:**
- Modify: `include/socket.s:58-61` (tags), `:108-125` (record fields)
- Modify: `src/modules/net/net.s:619-700` (`net_op_socket`)
- Create: `src/userland/unixprobe/unixprobe.c`, `src/userland/unixprobe/unixprobe.link.s`
- Modify: `tools/ninja/manifest.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `XPORT_UNIX EQU 4`; `SOCK_UnpRx EQU 12` (1 B, pipe index this
  socket READS, `SOCK_LOOP_NONE` = none); `SOCK_UnpPeer EQU 13` (1 B, peer
  descriptor index, `SOCK_LOOP_NONE` = unconnected); `SOCK_REC_SIZE EQU 14`.

- [ ] **Step 1: Write the failing probe**

Create `src/userland/unixprobe/unixprobe.c`. Model:
`src/userland/loopprobe/loopprobe.c` (same shape -- one process, no peer, no
hardware, prints a single PASS line the harness greps).

```c
/* unixprobe -- prove the AF_UNIX SOCK_DGRAM transport end to end, headless,
 * with no hardware, no peer process and no network.
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * WHY IT PROVES SOMETHING.  A descriptor is serviced by the AF_UNIX transport
 * only when SOCK_Proto carries XPORT_UNIX, which socket() sets from the DOMAIN
 * argument alone.  So reaching a successful socket() at all means the new arm
 * ran; and because AF_UNIX never calls _W5_SockAlloc, three consecutive
 * socket() calls must ALL succeed on a machine with three usable hardware
 * sockets -- which is the assertion that separates "AF_UNIX works" from
 * "AF_UNIX quietly borrowed the W5100".
 *
 * THE NEGATIVE ASSERTIONS ARE THE POINT.  A kernel that answered every
 * socket() with a descriptor would pass a positive-only probe.  SOCK_STREAM
 * must be REFUSED (EPROTOTYPE): the spec scopes it out deliberately, and a
 * silent success there would hand a caller a descriptor with no transport
 * behind it.
 */
#include <sys/types.h>
#include <sys/socket.h>
#include <errno.h>
#include <stdio.h>

#define AF_UNIX 1

int
main()
{
    int fd[3];
    int i;
    int r;

    /* POSITIVE CONTROL FIRST: SOCK_STREAM must be refused.  If this SUCCEEDS
     * the transport is answering requests it has no implementation for, and
     * every later PASS in this file is worthless. */
    r = socket(AF_UNIX, SOCK_STREAM, 0);
    if (r >= 0) {
        printf("unixprobe: FAIL stream-not-refused fd=%d\n", r);
        return (1);
    }
    if (errno != EPROTOTYPE) {
        printf("unixprobe: FAIL stream-wrong-errno %d\n", errno);
        return (1);
    }

    /* Three descriptors, none of which may consume a W5100 socket.  The
     * machine has three usable (0 is reserved for /dev/bpf0 MACRAW), so if
     * AF_UNIX took one each this would still pass -- which is why Task 2 adds
     * the interleaved AF_INET check.  Here it only proves alloc works. */
    for (i = 0; i < 3; i++) {
        fd[i] = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (fd[i] < 0) {
            printf("unixprobe: FAIL socket-%d errno=%d\n", i, errno);
            return (1);
        }
    }

    for (i = 0; i < 3; i++)
        (void)close(fd[i]);

    printf("unixprobe: PASS socket alloc + stream refused\n");
    return (0);
}
```

Create `src/userland/unixprobe/unixprobe.link.s` by copying
`src/userland/loopprobe/loopprobe.link.s` and changing the program name in it.

- [ ] **Step 2: Add the manifest entries**

In `tools/ninja/manifest.json`, the `tools` array gains:

```json
{"name": "unixprobe"}
```

and the `staging` array gains:

```json
{"src": "bin/unixprobe.bin", "dst": "disk_src/testbin/unixprobe"}
```

- [ ] **Step 3: Register the harness test NOW, before the first run**

The test must exist before the probe can be run at all, so it is created here
rather than after the implementation. Create
`tools/mame_test/tests/unixdgram.json`, modelled on
`tools/mame_test/tests/sockleak.json`:

```json
{
 "name": "unixdgram",
 "description": "AF_UNIX SOCK_DGRAM: socket() must allocate a descriptor without claiming a W5100 hardware socket, and SOCK_STREAM must be refused EPROTOTYPE.  The stream refusal is the positive control: a transport that answered every socket() with a descriptor would pass a positive-only probe, and the spec scopes SOCK_STREAM out deliberately -- upstream's SOCK_STREAM AF_UNIX is what pipe(2) is built from, and this kernel has real pipes.  Three consecutive AF_UNIX sockets prove the arm does not borrow from the three usable hardware sockets (0 is reserved for /dev/bpf0 MACRAW).",
 "command": "/testbin/unixprobe",
 "exit_on_prompt": false,
 "timeout_s": 180,
 "post_gap_frames": 800,
 "expect": {
  "screen_contains": [
   "unixprobe: PASS"
  ],
  "screen_lacks": [
   "unixprobe: FAIL",
   "PANIC",
   "BRK"
  ]
 }
}
```

Create `tools/mame_test/probes/unixdgram.json` with the same `command` and
`"expect": {"screen_lacks": ["PANIC","BRK"]}`.

- [ ] **Step 4: Regenerate, build, and confirm the probe FAILS for the right reason**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: FAIL, with `unixprobe: FAIL stream-wrong-errno 22` on screen -- EINVAL
22 from `net_op_socket`'s existing `@ss_einval`, not EPROTOTYPE. That specific
message is the probe correctly reporting the arm is absent. A different failure
means the probe or the manifest is wrong, not the kernel; fix that before
going on.

- [ ] **Step 5: Add the tag and the record fields**

In `include/socket.s`, after `XPORT_TCP`:

```
XPORT_UNIX      EQU     4           ; AF_UNIX SOCK_DGRAM (unp.s).  A new TAG
                                    ; rather than a SOCK_HwIdx sentinel like
                                    ; loopback's: loopback IS an ordinary
                                    ; SOCK_STREAM to userland and re-tagging it
                                    ; would break every SOCK_Proto == XPORT_TCP
                                    ; test, but AF_UNIX must NOT inherit
                                    ; XPORT_UDP's paths, which read sin_port and
                                    ; sin_addr from a sockaddr_in an AF_UNIX
                                    ; caller never supplies.
```

After `SOCK_LoopFlags`:

```
; AF_UNIX SOCK_DGRAM state.  A datagram lands in the RECEIVER's buffer
; (4.3BSD-Reno uipc_usrreq.c, PRU_SEND: sbappendaddr(&so2->so_rcv, ...)), so
; the ring belongs to the BOUND socket and a client holds none.  One ring for
; /dev/log serves every client, which is what keeps this inside NPIPE 8 --
; shared with shell pipes -- however many processes log.
SOCK_UnpRx      EQU     12          ; 1  pipe index this BOUND socket reads
                                    ;    (SOCK_LOOP_NONE = not bound)
SOCK_UnpPeer    EQU     13          ; 1  peer descriptor index for a connected
                                    ;    client (SOCK_LOOP_NONE = unconnected)
SOCK_REC_SIZE   EQU     14
```

Delete the old `SOCK_REC_SIZE EQU 12` line. Update the `SOCK_REC_SIZE`
paragraph above it: it currently says the 8 -> 12 growth was free because the
constant has exactly two users, both stride adds. Confirm that is still true
before trusting it:

```bash
grep -n "SOCK_REC_SIZE" src/ include/ -r
```

Expected: the two `ADC #SOCK_REC_SIZE` sites in `net.s` plus the definition and
`SOCKTBL_BLK_SIZE`. If a third user appears, stop and report -- the growth is
not free and the plan needs revising.

- [ ] **Step 6: Add the AF_UNIX arm to net_op_socket**

In `src/modules/net/net.s`, `net_op_socket` currently reads:

```
                AND     #$00FF
                CMP     #AF_INET
                BNE     @ss_einval
```

Replace with a two-way family branch. AF_UNIX takes its own path because it
must reach `@ss_proceed`'s descriptor allocation WITHOUT `_W5_SockAlloc`:

```
                AND     #$00FF
                CMP     #AF_UNIX
                BEQ     @ss_unix
                CMP     #AF_INET
                BNE     @ss_einval
```

and a new arm before `@ss_proceed`:

```
; AF_UNIX: SOCK_DGRAM only, and NO hardware socket is claimed.  Loopback has to
; take one and give it back later (_Loop_ReleaseHw, apple/fgx#132) because at
; socket() time nothing knows the destination is 127/8 -- bind or connect
; decides it.  The DOMAIN argument decides this one, here, so taking a W5100
; slot and returning it would be strictly worse: there are three usable and
; syslogd holds its descriptor for the life of the boot.
@ss_unix        TXA
                AND     #$00FF
                CMP     #SOCK_DGRAM
                BNE     @ss_eprototype
                LDA     #XPORT_UNIX
                STA     _sockTmpTag
                LDA     #SOCK_HW_NONE
                STA     _sockTmpHw
                BRA     @ss_findL               ; skip _W5_SockAlloc entirely
@ss_eprototype  LDA     #EPROTOTYPE
                CLC
                RTL
```

`@ss_proceed` keeps `JSR _W5_SockAlloc` for the AF_INET families; the AF_UNIX
arm jumps past it to the descriptor scan. Confirm `@ss_findL` is the right
label for "the descriptor table scan, hardware already decided" by reading
`net.s:619-700`; if the scan expects `_sockTmpHw` in A rather than a static,
match whatever the AF_INET path leaves.

Initialise the two new fields wherever the arm fills the record: `SOCK_UnpRx`
and `SOCK_UnpPeer` both to `SOCK_LOOP_NONE`. A zero there would read as
"descriptor 0 is my peer", which is a live descriptor.

- [ ] **Step 7: Define AF_UNIX and EPROTOTYPE where both sides can see them**

```bash
grep -n "AF_INET\|EPROTOTYPE" include/socket.s include/errno.s toolchain/include/sys/socket.h toolchain/include/errno.h
```

Add `AF_UNIX EQU 1` to `include/socket.s` beside `AF_INET`, and `#define
AF_UNIX 1` to `toolchain/include/sys/socket.h`. If `EPROTOTYPE` is absent from
`include/errno.s`, add it with BSD's number (41) and add the matching
`#define` to `toolchain/include/errno.h`. Both sides must agree; the probe
compares against the C value.

Then remove the local `#define AF_UNIX 1` from `unixprobe.c` -- it was there
only so Step 1 compiled before the header existed. A probe carrying its own
copy of a system constant is how the two drift apart.

- [ ] **Step 8: Build and run -- the probe must now PASS**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: PASS, with `unixprobe: PASS socket alloc + stream refused` on screen.

- [ ] **Step 9: Prove the test can go red**

Temporarily change the `@ss_unix` arm's `CMP #SOCK_DGRAM` / `BNE` to fall
through to `@ss_proceed` (so SOCK_STREAM is accepted), rebuild, and re-run.

```bash
python3 tools/mame_test/run.py unixdgram
```

Expected: FAIL with `unixprobe: FAIL stream-not-refused`. A test that cannot go
red is not coverage. Revert the mutation and confirm PASS again before
committing.

- [ ] **Step 10: Commit**

```bash
git add include/socket.s include/errno.s src/modules/net/net.s \
  toolchain/include/sys/socket.h toolchain/include/errno.h \
  src/userland/unixprobe tools/ninja/manifest.json \
  tools/mame_test/tests/unixdgram.json tools/mame_test/probes/unixdgram.json
git commit
```

Commit body names the upstream: the family/type resolution follows
4.3BSD-Reno `kern/uipc_usrreq.c`'s domain, and the refusal of SOCK_STREAM is
FGX's own scoping, stated as such.

---

## Task 2: the framed ring -- datagrams between two paired descriptors

Two AF_UNIX descriptors, paired by hand through `SOCK_UnpPeer`, move whole
datagrams with boundaries intact. No filesystem name yet.

**Files:**
- Create: `src/modules/net/unp.s`
- Modify: `src/modules/net/net.s` (`net_op_send`, `net_op_recv`, `net_op_sendto`, `net_op_recvfrom`)
- Modify: `src/modules/net/net.link.s` (add `unp.s` to the link list)
- Modify: `src/userland/unixprobe/unixprobe.c`

**Interfaces:**
- Consumes: `XPORT_UNIX`, `SOCK_UnpRx`, `SOCK_UnpPeer` from Task 1.
- Produces:
  - `_Unp_SendTry` -- entry: nothing (args from `_Sys_Saved*`, as every net op).
    Sets `_unpHandled` nonzero and returns the op's `A`+`C` if the descriptor
    is `XPORT_UNIX`; leaves `_unpHandled` zero otherwise. MX %00.
  - `_Unp_RecvTry` -- same contract, receive side.
  - `_Unp_PairAlloc` -- entry: A = bound descriptor index. Allocates one
    pipe.s ring via `_Pipe_Alloc` and stores its index in that descriptor's
    `SOCK_UnpRx`. Out: C=1, or C=0 + A = errno (ENFILE).
  - `_unpHandled` -- 1-byte core-bank static, the `_loopHandled` analogue.

- [ ] **Step 1: Extend the probe with the failing datagram case**

Add to `unixprobe.c`, after the socket-alloc block and before the final PASS.
This needs a pairing hook, which does not exist yet -- use `sendto` with a
`sockaddr_un` naming nothing, which Task 4 makes work by path; for now the
pairing is what Task 2 provides via an unnamed `connect` to a descriptor
number. Read `net_op_connect` first and match the argblock it already takes.

```c
    /* Datagram boundaries.  THREE writes of different lengths, then three
     * reads: a byte-stream ring would hand back 6+6+6 as one 18-byte read and
     * a boundary-preserving one gives back exactly three records.  A single
     * round trip cannot tell those apart, which is why there are three. */
    static char *msg[3] = { "a", "bbbb", "ccccccccc" };
    char         buf[64];
    int          n;

    for (i = 0; i < 3; i++)
        if (send(fd[0], msg[i], strlen(msg[i]), 0) != (int)strlen(msg[i])) {
            printf("unixprobe: FAIL send-%d errno=%d\n", i, errno);
            return (1);
        }

    for (i = 0; i < 3; i++) {
        n = recv(fd[1], buf, sizeof buf, 0);
        if (n != (int)strlen(msg[i])) {
            printf("unixprobe: FAIL recv-%d got=%d want=%d\n",
                   i, n, (int)strlen(msg[i]));
            return (1);
        }
        buf[n] = '\0';
        if (strcmp(buf, msg[i]) != 0) {
            printf("unixprobe: FAIL recv-%d content\n", i);
            return (1);
        }
    }

    /* POSITIVE CONTROL: a datagram larger than the ring must be refused
     * WHOLE, not truncated.  A truncating write splits one message across two
     * records and corrupts every boundary after it, and the next recv would
     * return plausible-looking bytes -- so this is the assertion that a
     * truncation bug could not hide from. */
    {
        static char big[PIPE_MAX_PLUS];   /* see Step 6 for the constant */
        if (send(fd[0], big, sizeof big, 0) >= 0) {
            printf("unixprobe: FAIL oversize-accepted\n");
            return (1);
        }
        if (errno != ENOBUFS) {
            printf("unixprobe: FAIL oversize-wrong-errno %d\n", errno);
            return (1);
        }
        /* and the ring must still be usable -- the refusal must not have left
         * a partial header behind */
        if (send(fd[0], "z", 1, 0) != 1 ||
            recv(fd[1], buf, sizeof buf, 0) != 1 || buf[0] != 'z') {
            printf("unixprobe: FAIL ring-corrupt-after-refusal\n");
            return (1);
        }
    }
```

- [ ] **Step 2: Run it and confirm it fails at the send**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: FAIL at `unixprobe: FAIL send-0` -- `net_op_send` has no AF_UNIX arm,
so it falls through to `_Net_Xport_Send`, which has no `XPORT_UNIX` handler.

- [ ] **Step 3: Create src/modules/net/unp.s with the framing**

The record format, from the spec section 4.2:

```
+0  2 B  payload length (bytes, host order)
+2  1 B  sender name length (0 for sun_noname)
+3  n B  sender name, if any
+3+n     payload
```

`_Unp_SendTry` writes header+payload as one `_Pipe_WriteAt` into the PEER's
ring; `_Unp_RecvTry` reads the 3-byte header, then exactly `len` bytes.

The pipe.s scratch contract, from `pipe.s:302-400`: set `_pipeRecOff` to the
ring's record offset, `_pipeReqLen` to the byte count, `_pipeBufOff` and
`_pipeBufBank` to the source/destination, then `JSR _Pipe_WriteAt` or
`_Pipe_ReadAt`. Out: A = bytes + C=1, or A = errno + C=0.

```
;==============================================================================
; unp.s - AF_UNIX SOCK_DGRAM transport.  Lives in net.mod beside net_loop.s,
; which it is modelled on: a socket with no hardware behind it, delivering
; through pipe.s rings.
;
; THE RING BELONGS TO THE BOUND SOCKET, NOT THE CONNECTION.  4.3BSD-Reno
; kern/uipc_usrreq.c, PRU_SEND, SOCK_DGRAM arm:
;
;       so2 = unp->unp_conn->unp_socket;
;       if (sbappendaddr(&so2->so_rcv, from, m, control)) {
;
; The datagram is appended to the RECEIVER's receive buffer.  So one ring
; serves /dev/log however many clients log into it, and a client descriptor
; owns no ring at all -- only its peer's index in SOCK_UnpPeer.  That is what
; keeps this inside NPIPE 8, which is the whole machine's pipe count and is
; shared with shell pipes.
;
; A RECORD IS FRAMED BECAUSE pipe.s IS A BYTE STREAM.  sbappendaddr appends an
; address plus the data as one record; a ring has no record concept, so the
; boundary is carried explicitly:
;
;       +0  2 B  payload length (host order)
;       +2  1 B  sender name length (0 = sun_noname)
;       +3  n B  sender name
;       +3+n     payload
;
; A datagram that does not fit the ring's free space is DROPPED WHOLE with
; ENOBUFS, never truncated -- which is sbappendaddr returning 0 and PRU_SEND
; setting ENOBUFS.  Truncating would split one message across two records and
; corrupt every boundary after it.
;
; syslog(3) never binds, so every record this transport carries in practice has
; a zero-length name and recvfrom's `from' is a zero-length sockaddr_un.  The
; name field exists so a future named sender needs no format change.
;==============================================================================

                MX      %00

UNP_HDR_LEN     EQU     3               ; length(2) + namelen(1), name absent

;------------------------------------------------------------------------------
; _Unp_SendTry - the XPORT_UNIX arm of net_op_send/net_op_sendto.
;
; Mirrors _Loop_SendTry's contract exactly, because net_op_send's existing
; shape is `JSR _Loop_SendTry / PHP / PHA / LDA _loopHandled / BEQ hw' and this
; sits in front of it: set _unpHandled nonzero and return A+C when the
; descriptor is ours, leave it zero to fall through.
;
; In:  args in _Sys_SavedA (argblk offset), _Sys_SavedX (fd), _Sys_CallerBank.
; Out: _unpHandled = 0 -> not ours, A/C undefined.
;      _unpHandled != 0 -> A+C are the op's result.
; MX %00.  Clobbers A, X, Y.
;------------------------------------------------------------------------------
_Unp_SendTry    MX      %00
                STZ     _unpHandled
                ; resolve fd -> descriptor; not a socket at all is not ours
                LDA     _Sys_SavedX
                JSL     SYS_NETKC_SOCKFDTODESC
                BCC     @us_notours
                STY     _sockTmpOff
                ; SOCK_Proto == XPORT_UNIX ?
                TYA
                CLC
                ADC     #SOCK_Proto
                TAY
                SEP     #$20
                MX      %10
                LDA     [_sockTablePtr],Y
                CMP     #XPORT_UNIX
                REP     #$20
                MX      %00
                BEQ     @us_ours
@us_notours     RTS
@us_ours        SEP     #$20
                MX      %10
                LDA     #$01
                STA     _unpHandled
                REP     #$20
                MX      %00
                ; ... peer lookup (SOCK_UnpPeer), ENOTCONN if SOCK_LOOP_NONE;
                ; peer's SOCK_UnpRx -> _pipeRecOff; free space check against
                ; UNP_HDR_LEN + len -> ENOBUFS whole; header write then payload
                ; write, both via _Pipe_WriteAt; return the PAYLOAD count, not
                ; the framed count, because that is what send(2) promises.
                RTS
```

Write the body out in full following that outline. Two things it must get
right, both of which pipe.s's header calls out:

1. `_pipeRecOff` is the *record* offset, not the index -- `_Pipe_FdToIdx`
   returns it in Y and the loopback path stores it before calling `_Pipe_*At`.
   AF_UNIX has no pipe fd, so compute it from the index in `SOCK_UnpRx` the way
   `net_loop.s` does.
2. The header and the payload are two `_Pipe_WriteAt` calls, so the free-space
   check must cover BOTH before either runs. Checking per-call would let a
   header land with no room for its payload, which is the corruption the
   probe's `ring-corrupt-after-refusal` assertion exists to catch.

- [ ] **Step 4: Write _Unp_RecvTry**

Same `try` contract. Reads the 3-byte header via `_Pipe_ReadAt` with
`_pipeReqLen = UNP_HDR_LEN`, then `min(len, caller's max)` bytes of payload.

A payload longer than the caller's buffer is **truncated and the remainder
discarded**, which is `recvfrom`'s documented datagram behaviour -- the rest of
the record must be consumed so the next read starts on a boundary. Set
`MSG_TRUNC` if FGX has it; if not, say so in the man page's BUGS rather than
inventing a flag.

- [ ] **Step 5: Hook both into net.s and the link list**

In `net_op_send`, ahead of the existing loopback try:

```
net_op_send     MX      %00
                ; AF_UNIX FIRST.  Same `try' shape as the loopback arm below:
                ; the transport claims the call or leaves _unpHandled zero.  It
                ; goes first because its test is a single SOCK_Proto compare,
                ; where _Loop_SendTry resolves more state before deciding.
                JSR     _Unp_SendTry
                PHP
                PHA
                LDA     _unpHandled
                BEQ     @nou_send_loop
                PLA
                PLP
                RTL
@nou_send_loop  PLA
                PLP
                JSR     _Loop_SendTry
                ...
```

Repeat for `net_op_recv`, `net_op_sendto`, `net_op_recvfrom`. Add `unp.s` to
`src/modules/net/net.link.s`.

- [ ] **Step 6: Add the pairing hook and the oversize constant**

Task 2 has no filesystem names, so the probe needs a way to pair two
descriptors. Add the minimum: `connect()`'s AF_UNIX arm accepts a
`sockaddr_un` whose `sun_path` is empty and whose family is AF_UNIX, and pairs
with the descriptor named in the argblock -- an FGX-only interim that Task 4
replaces with `namei`. Mark it `/* interim: Task 4 replaces this with the
name lookup */` and delete it in Task 4. Do not leave it behind.

Define `PIPE_MAX_PLUS` in the probe as `4097` -- one byte past
`PIPE_MAX_BUFSZ` (`include/kernel.s:813`), so the oversize case is oversize
even after the ring has grown to its ceiling.

- [ ] **Step 7: Build and run -- must PASS**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: `unixprobe: PASS` with all three boundary reads and the oversize
refusal.

- [ ] **Step 8: Prove the boundary assertion can go red**

Mutate `_Unp_RecvTry` to ignore the header's length and return whatever the
ring holds. Rebuild, re-run.

Expected: FAIL at `recv-0 got=14 want=1` (the three messages coalesced). Revert
and confirm PASS.

- [ ] **Step 9: Measure the core-bank cost**

The spec requires this measured, not estimated.

```bash
ninja && python3 tools/check_stack_budget.py 2>/dev/null; grep -rn "core bank\|bank0" build/*.map 2>/dev/null | head
```

Find the report the bank-0 residency campaign uses (see
`project_fgx_bank0_residency_campaign` in the ledger and
`tools/check_ntty.py`'s neighbours) and record the delta for `_unpHandled` plus
any `_unp*` scratch that had to stay core-bank. Put the number in the commit
body. If it exceeds the campaign's headroom, stop and report rather than
landing it.

- [ ] **Step 10: Commit**

```bash
git add src/modules/net/unp.s src/modules/net/net.s src/modules/net/net.link.s \
  src/userland/unixprobe/unixprobe.c include/kernel.s
git commit
```

Body names `4.3BSD-Reno kern/uipc_usrreq.c`'s `PRU_SEND` SOCK_DGRAM arm and
`sbappendaddr` as the source of the receiver-owns-the-buffer rule, and states
the ring-versus-mbuf divergence.

---

## Task 3: VSOCK through ufs_create

An `IFSOCK` inode can exist on the volume. This is a one-line behaviour change
plus two comment retirements, and it is worth its own commit because it changes
the filesystem and nothing else.

**Files:**
- Modify: `src/kernel/vfs/ufs_vnops.c:1222-1243` (`ufs_create`), `:2085-2088` (`ufs_mknod`'s comment)
- Modify: `src/kernel/vfs/vnode.h` (the `v_un` comment)
- Create: `src/userland/unixprobe/` -- extend the existing probe

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: `ufs_create` honours `vap->va_type == VSOCK` by setting `IFSOCK`.

- [ ] **Step 1: Write the failing check**

`ufs_create` is reached from `open(O_CREAT)`, which cannot ask for `VSOCK`, so
the probe cannot reach this yet. Assert it from the other end instead --
`ls -l` on a node that Task 4 creates. For THIS task, the test is a kernel-side
one: add to the probe a stat of a path that does not exist yet and expect
ENOENT, then in Task 4 flip it to expect `S_IFSOCK`. Note that ordering
explicitly in the probe:

```c
    /* Task 4 creates /dev/log and flips this to an S_ISSOCK assertion.  Until
     * then the only honest check is that nothing is there -- a probe that
     * asserted S_IFSOCK here would be asserting against a file this task
     * cannot create. */
    {
        struct stat sb;
        if (stat("/dev/log", &sb) == 0) {
            printf("unixprobe: FAIL devlog-exists-early\n");
            return (1);
        }
    }
```

- [ ] **Step 2: Add the VSOCK arm**

In `src/kernel/vfs/ufs_vnops.c`, `ufs_create`:

```c
    mode = (int)(vap->va_mode & 07777);
    if (vap->va_type == VDIR)
        mode |= IFDIR;
    else if (vap->va_type == VLNK)
        mode |= IFLNK;
    else if (vap->va_type == VSOCK)
        mode |= IFSOCK;
    else
        mode |= IFREG;
```

Extend `ufs_create`'s header comment: the type bits come from `va_type`, and
`VSOCK` is now one of them, reached from `unp_bind` rather than from `open(2)`.
Reno's `unp_bind` uses `VOP_CREATE` with `va_type = VSOCK`, not `VOP_MKNOD` --
name that, because the reflex is to look for `mknod`.

- [ ] **Step 3: Retire ufs_mknod's stale claim**

`ufs_mknod`'s header currently reads:

> NOT SUPPORTED HERE, and refused rather than mis-made: VFIFO and VSOCK (this
> kernel has neither, and Reno's MAKEIMODE would accept both)

Half of that is now false. Rewrite so it describes the current state: `VSOCK`
exists and arrives through `VOP_CREATE`, which is upstream's route for it;
`ufs_mknod` still refuses it, and refuses `VFIFO`, which this kernel does not
have. Keep the badsect paragraph, which is unaffected.

- [ ] **Step 4: Retire vnode.h's "Sockets never arrive"**

`src/kernel/vfs/vnode.h`'s `v_un` comment ends:

> THE TWO ARMS CANNOT BOTH BE LIVE: a covered directory is VDIR and a VDIR has
> no specinfo.  Sockets never arrive.

The socket arm is now live. Rewrite it to state the three arms, that a VSOCK
uses the socket arm with a cast exactly as `vfs_mountat` casts for
`mountedhere`, and that `sizeof(struct vnode)` is unchanged -- so
`vfslayout.c`'s boot assertion still holds. Confirm that last claim:

```bash
grep -rn "sizeof(struct vnode)\|vfslayout" src/kernel/vfs/ | head
```

- [ ] **Step 5: Build, run the whole suite for blast radius**

`ufs_create` is on the `open(O_CREAT)` path, which is every file creation on
the system. The blast radius is wide and the change is one `else if`, so the
check is a broad smoke run, not a deep probe.

```bash
ninja && python3 tools/mame_test/run.py
```

Expected: no new failures against the pre-task baseline. Record which tests
were already red before this task so a pre-existing red is not read as a
regression.

- [ ] **Step 6: Commit**

```bash
git add src/kernel/vfs/ufs_vnops.c src/kernel/vfs/vnode.h
git commit
```

Body names `4.3BSD-Reno ufs/ufs_vnops.c`'s `ufs_create` and
`kern/uipc_usrreq.c`'s `unp_bind`, and states that `VOP_CREATE` rather than
`VOP_MKNOD` is upstream's route for a socket node.

---

## Task 4: unp_bind and unp_connect -- the name on the filesystem

`/dev/log` becomes a real bound node reachable by path.

**Files:**
- Modify: `src/modules/net/unp.s` (bind/connect arms)
- Modify: `src/modules/net/net.s` (`net_op_bind`, `net_op_connect`)
- Modify: `src/kernel/vfs/vfs_syscalls.c` (a kernel service for the namei, if the module cannot reach namei directly)
- Modify: `src/userland/unixprobe/unixprobe.c`
- Modify: `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: `_Unp_SendTry`, `_Unp_RecvTry`, `_Unp_PairAlloc`, `SOCK_UnpRx`,
  `SOCK_UnpPeer`, `ufs_create`'s VSOCK arm.
- Produces: `_Unp_BindTry`, `_Unp_ConnectTry` -- same `try` contract as
  `_Unp_SendTry`, using `_unpHandled`.

- [ ] **Step 1: Extend the probe to the named case**

Replace Task 3's `devlog-exists-early` block with the real assertions:

```c
    /* Bind a name, and prove it is a SOCKET on the volume and not the regular
     * file ufs_create would have made before the VSOCK arm existed. */
    {
        struct sockaddr_un sun;
        struct stat        sb;

        (void)unlink("/tmp/unixprobe.sock");
        sun.sun_family = AF_UNIX;
        strcpy(sun.sun_path, "/tmp/unixprobe.sock");
        if (bind(fd[0], (struct sockaddr *)&sun, sizeof sun) < 0) {
            printf("unixprobe: FAIL bind errno=%d\n", errno);
            return (1);
        }
        if (stat("/tmp/unixprobe.sock", &sb) < 0) {
            printf("unixprobe: FAIL bind-no-node errno=%d\n", errno);
            return (1);
        }
        if (!S_ISSOCK(sb.st_mode)) {
            printf("unixprobe: FAIL bind-wrong-type mode=%o\n",
                   (unsigned)sb.st_mode);
            return (1);
        }

        /* POSITIVE CONTROL 1: a SECOND bind of the same name must be refused
         * EADDRINUSE.  Upstream's comment marks adopt-and-wakeup as a FIFO
         * improvement it did not make, and neither do we -- so a silent
         * success here would mean two sockets believing they own one name. */
        if (bind(fd[1], (struct sockaddr *)&sun, sizeof sun) >= 0) {
            printf("unixprobe: FAIL rebind-accepted\n");
            return (1);
        }
        if (errno != EADDRINUSE) {
            printf("unixprobe: FAIL rebind-wrong-errno %d\n", errno);
            return (1);
        }

        /* POSITIVE CONTROL 2: connect to a REGULAR FILE must be ENOTSOCK.
         * This is unp_connect's `vp->v_type != VSOCK' check, and without it
         * connect would hand back a descriptor wired to a vnode with no
         * socket behind it. */
        {
            int tf = creat("/tmp/unixprobe.reg", 0666);
            if (tf >= 0)
                (void)close(tf);
            strcpy(sun.sun_path, "/tmp/unixprobe.reg");
            if (connect(fd[1], (struct sockaddr *)&sun, sizeof sun) >= 0) {
                printf("unixprobe: FAIL connect-regfile-accepted\n");
                return (1);
            }
            if (errno != ENOTSOCK) {
                printf("unixprobe: FAIL connect-regfile-errno %d\n", errno);
                return (1);
            }
        }

        /* And the real thing: connect by name, then a datagram by name. */
        strcpy(sun.sun_path, "/tmp/unixprobe.sock");
        if (connect(fd[1], (struct sockaddr *)&sun, sizeof sun) < 0) {
            printf("unixprobe: FAIL connect errno=%d\n", errno);
            return (1);
        }
        if (send(fd[1], "named", 5, 0) != 5) {
            printf("unixprobe: FAIL named-send errno=%d\n", errno);
            return (1);
        }
        n = recv(fd[0], buf, sizeof buf, 0);
        if (n != 5) {
            printf("unixprobe: FAIL named-recv got=%d\n", n);
            return (1);
        }
    }
```

- [ ] **Step 2: Run it, confirm it fails at bind**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: FAIL at `unixprobe: FAIL bind errno=...` -- `net_op_bind` has no
AF_UNIX arm.

- [ ] **Step 3: Write _Unp_BindTry**

Following `unp_bind` (`examples/4.3BSD-Reno/kern/uipc_usrreq.c`), in order:

1. Already bound (`SOCK_UnpRx != SOCK_LOOP_NONE`) -> EINVAL. Upstream:
   `if (unp->unp_vnode != NULL) return (EINVAL);`
2. `namei(CREATE | FOLLOW | LOCKPARENT)` on `sun_path`.
3. Node exists -> EADDRINUSE.
4. `VOP_CREATE` with `va_type = VSOCK`, `va_mode = 0777`.
5. Record the descriptor index on the vnode's `v_un` socket arm, cast exactly
   as `vfs_syscalls.c:vfs_mountat` casts for `mountedhere`.
6. `_Unp_PairAlloc` for this descriptor's receive ring.

The module cannot call `namei` directly -- it is kernel-side. Route through the
`SYS_KCALL` multiplexed service slot the way `net_loop.s`'s `_NlKC_*` shims do
(see `src/modules/net/net_loop.s:31-55` for the three routes and which one a
call takes). Add a `KSVC_*` service for the bind lookup rather than a new
bank-0 JT slot, because a JT slot costs core-bank bytes and the ratchet is
tight.

`sun_path` arrives in the caller's bank; copy it into kernel space before the
`namei`, and bound the copy at the `sockaddr_un` path size. An unterminated
path is upstream's explicit case:

```c
	if (nam->m_len == MLEN) {
		if (*(mtod(nam, caddr_t) + nam->m_len - 1) != 0)
			return (EINVAL);
	} else
		*(mtod(nam, caddr_t) + nam->m_len) = 0;
```

- [ ] **Step 4: Write _Unp_ConnectTry**

Following `unp_connect`:

1. `namei(LOOKUP | FOLLOW | LOCKLEAF)`.
2. `vp->v_type != VSOCK` -> ENOTSOCK.
3. `VOP_ACCESS(vp, VWRITE)` -> EACCES. FGX is not a secure platform, but BSD
   permission checks still port, and `syslogd` chmods `/dev/log` 0666 on
   purpose -- so this check is what makes that chmod mean something.
4. Peer's descriptor index from `v_un` into this descriptor's `SOCK_UnpPeer`.

- [ ] **Step 5: Delete Task 2's interim pairing hook**

Remove the `/* interim: Task 4 replaces this with the name lookup */` arm from
`connect()`. Confirm nothing still calls it:

```bash
grep -rn "interim: Task 4" src/
```

Expected: no matches. A pairing path that two roads can serve hides defects in
the gap.

- [ ] **Step 6: Teardown -- the name outlives the socket**

`close()` on a bound AF_UNIX socket must free the ring and clear the vnode's
socket arm, but must NOT unlink the name: upstream leaves the node, which is
why `syslogd` does `(void) unlink(LogName)` before binding. Extend the
existing `NETOP_SockTeardown` path (`_Sock_Teardown`) with the `XPORT_UNIX`
arm. Add to the probe:

```c
    /* The NAME outlives the socket, as upstream's does -- which is why syslogd
     * unlinks before it binds.  A close that unlinked would make a second
     * syslogd start silently succeed where upstream's would collide. */
    (void)close(fd[0]);
    {
        struct stat sb;
        if (stat("/tmp/unixprobe.sock", &sb) < 0) {
            printf("unixprobe: FAIL name-vanished-on-close\n");
            return (1);
        }
    }
    (void)unlink("/tmp/unixprobe.sock");
    (void)unlink("/tmp/unixprobe.reg");
```

- [ ] **Step 7: Build and run -- must PASS**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

- [ ] **Step 8: Prove the ENOTSOCK control can go red**

Mutate `_Unp_ConnectTry` to skip the `v_type != VSOCK` check. Rebuild, re-run.

Expected: FAIL at `connect-regfile-accepted`. Revert, confirm PASS.

- [ ] **Step 9: Add the PROVENANCE rows**

In `docs/PROVENANCE.md`, add rows for `src/modules/net/unp.s` naming
`vendor/4.3BSD-Reno/kern/uipc_usrreq.c` (`unp_bind`, `unp_connect`, `PRU_SEND`).
Vendor the file if it is not already in `vendor/`:

```bash
ls vendor/4.3BSD-Reno/kern/uipc_usrreq.c || cp examples/4.3BSD-Reno/kern/uipc_usrreq.c vendor/4.3BSD-Reno/kern/
python3 tools/check_provenance.py
```

Expected: green. Anything taken from gitignored `examples/` is vendored in the
same commit.

- [ ] **Step 10: Commit**

```bash
git add src/modules/net/unp.s src/modules/net/net.s src/kernel/vfs/vfs_syscalls.c \
  src/userland/unixprobe/unixprobe.c docs/PROVENANCE.md \
  vendor/4.3BSD-Reno/kern/uipc_usrreq.c
git commit
```

---

## Task 5: strftime(3)

`syslog(3)`'s timestamp prefix needs it, and it is absent. Its own task because
it is standalone libc with a standalone test.

**Files:**
- Create: `toolchain/lib/libc_c/strftime.c`
- Modify: `toolchain/include/time.h`
- Modify: `tools/ninja/gen.py` (the libc source list, if not globbed)

**Interfaces:**
- Consumes: `localtime` (`toolchain/lib/libc_c/ctime.c`).
- Produces: `size_t strftime(char *buf, size_t maxsize, char *fmt, struct tm *t);`
  K&R declaration in `time.h` as `size_t strftime();` to match house style.

- [ ] **Step 1: Port from 4.3BSD-Reno, NOT 2.11BSD -- 2.11BSD's %h is broken**

The standing rule prefers 2.11BSD, and this is the documented exception.
Both trees have the file:

- `examples/2.11BSD/usr/lib/libc/gen/strftime.c` (271 lines)
- `examples/4.3BSD-Reno/lib/libc/string/strftime.c`

**2.11BSD's `%h` returns the FULL month name.** It carries only two tables,
`Afmt[]` and `Bfmt[]`, both full words, and synthesises the abbreviation
inline for `'b'` alone:

```c
			case 'B':
			case 'b':
			case 'h':
				if	(ch == 'b')
					{
					bcopy(Bfmt[t->tm_mon], junk, 3);
					junk[3] = '\0';
					cp = junk;
					}
				else
					cp = Bfmt[t->tm_mon];
```

so `'h'` takes the `else` and yields `"September"`. Reno carries four tables
(`afmt`/`Afmt`, `bfmt`/`Bfmt`) and groups `'h'` with `'b'` against the
abbreviated one:

```c
			case 'b':
			case 'h':
				if (t->tm_mon < 0 || t->tm_mon > 11)
					return(0);
				if (!_add(bfmt[t->tm_mon]))
					return(0);
```

**The only `%h` caller in the entire 2.11BSD tree is `syslog.c:123`** -- the
exact line Task 6 ports. So a faithful 2.11BSD port would put
`"September 19 03:04:05 "` in every syslog line and in `/usr/adm/messages`,
where every other Unix writes `"Sep 19 ..."`, and the `syslogd` of the next
plan would have to parse it.

Port Reno's. Verify the two readings above against the files first rather than
trusting this plan:

```bash
grep -n "fmt\[\] *=" examples/2.11BSD/usr/lib/libc/gen/strftime.c
grep -n "fmt\[\] *=" examples/4.3BSD-Reno/lib/libc/string/strftime.c
grep -rn '"%h' examples/2.11BSD/usr/
```

Expected: 2.11BSD has two tables, Reno has four, and `syslog.c` is the sole
`%h` caller. State the choice and the reason in the commit body -- picking the
correct upstream is not diverging from upstream.

- [ ] **Step 2: Write the failing test**

`syslog` uses exactly one format: `"%h %e %T "`. That is the minimum the test
must cover, plus the truncation contract.

Add to `src/userland/unixprobe/unixprobe.c` -- it is already the AF_UNIX/syslog
probe and a second binary for three assertions is not worth a manifest entry:

```c
    /* strftime's one caller-visible contract: syslog's exact format, and
     * truncation returning 0 with the buffer untouched past maxsize.  The
     * truncation case is the control -- a strftime that wrote past the end
     * would corrupt syslog's tbuf and the corruption would look like a
     * message-formatting bug. */
    {
        struct tm  tmv;
        char       tb[32];
        size_t     k;

        tmv.tm_mon = 0;      /* Jan */
        tmv.tm_mday = 2;
        tmv.tm_hour = 3;
        tmv.tm_min = 4;
        tmv.tm_sec = 5;
        k = strftime(tb, sizeof tb, "%h %e %T ", &tmv);
        if (k == 0 || strcmp(tb, "Jan  2 03:04:05 ") != 0) {
            printf("unixprobe: FAIL strftime got='%s' n=%u\n", tb, (unsigned)k);
            return (1);
        }
        tb[4] = '\377';
        if (strftime(tb, 4, "%h %e %T ", &tmv) != 0) {
            printf("unixprobe: FAIL strftime-trunc-nonzero\n");
            return (1);
        }
        if (tb[4] != '\377') {
            printf("unixprobe: FAIL strftime-trunc-overran\n");
            return (1);
        }
    }
```

Note `"%e"` is space-padded, so `mday` 2 gives `" 2"` and the expected string
has two spaces after `Jan`. Confirm that against the upstream `strftime` rather
than trusting this plan's spelling: if the port pads differently, fix the
expectation to match the source, not the source to match the expectation.

- [ ] **Step 3: Run it and watch it fail**

```bash
ninja 2>&1 | head -20
```

Expected: link error, undefined `strftime`.

- [ ] **Step 4: Port strftime.c and declare it**

Port `examples/4.3BSD-Reno/lib/libc/string/strftime.c`, vendoring it into
`vendor/4.3BSD-Reno/lib/libc/string/` in the same commit. Its header comment
must record why Reno and not 2.11BSD, in one sentence: 2.11BSD's `%h` yields
the full month name, and `syslog` is its only caller.

If fcc rejects any construct in it, **fix fcc** -- do not
rewrite the C to dodge the compiler. Add a regression fixture for the reject,
get goldens green, and quote the deciding sentence of K&R 2nd ed Appendix A in
that commit (indexed as `kr_c`:
`mcp__gs-mcp__search_iigs_docs(q, doc_filter=["kr_c"])`).

Declare in `toolchain/include/time.h` in house style:

```c
size_t strftime();
```

- [ ] **Step 5: Build and run -- must PASS**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

- [ ] **Step 6: Commit**

```bash
python3 tools/check_provenance.py
git add toolchain/lib/libc_c/strftime.c toolchain/include/time.h \
  src/userland/unixprobe/unixprobe.c docs/PROVENANCE.md \
  vendor/4.3BSD-Reno/lib/libc/string/strftime.c
git commit
```

Body names `4.3BSD-Reno lib/libc/string/strftime.c`, states that 2.11BSD's copy
was rejected because its `%h` returns the full month name against Reno's
abbreviated one, that `syslog.c:123` is that conversion's only caller in the
2.11BSD tree, and any conversions deliberately not ported.

---

## Task 6: syslog(3) onto the socket

The symptom dies here.

**Files:**
- Modify: `toolchain/lib/libc_c/syslog.c` (rewrite)
- Modify: `toolchain/include/syslog.h`
- Modify: `src/userland/su/su.c:21` (the BUGS line)
- Modify: `docs/PROVENANCE.md`

**Interfaces:**
- Consumes: AF_UNIX from Tasks 1-4, `strftime` from Task 5.
- Produces: `openlog`, `syslog`, `closelog`, `vsyslog`, `setlogmask` with
  upstream semantics.

- [ ] **Step 1: Add the missing macros**

In `toolchain/include/syslog.h`:

```c
#define LOG_PERROR      0x20    /* log to stderr as well */

#define LOG_PRIMASK     0x07    /* mask to extract priority part */
#define LOG_FACMASK     0x03f8  /* mask to extract facility part */
#define LOG_PRI(p)      ((p) & LOG_PRIMASK)
#define LOG_MAKEPRI(fac, pri)   (((fac) << 3) | (pri))
#define LOG_MASK(pri)   (1 << (pri))
#define LOG_UPTO(pri)   ((1 << ((pri)+1)) - 1)
#define LOG_NFACILITIES 24      /* current number of facilities */

#define LOG_NEWS        (7<<3)  /* network news subsystem */
#define LOG_UUCP        (8<<3)  /* UUCP subsystem */
#define LOG_CRON        (15<<3) /* clock daemon */
#define LOG_LOCAL1      (17<<3)
#define LOG_LOCAL2      (18<<3)
#define LOG_LOCAL3      (19<<3)
#define LOG_LOCAL4      (20<<3)
#define LOG_LOCAL5      (21<<3)
#define LOG_LOCAL6      (22<<3)
#define LOG_LOCAL7      (23<<3)

#define _PATH_LOG       "/dev/log"
```

Take every value from `examples/2.11BSD/usr/include/syslog.h` rather than this
plan -- a value copied from a plan is a value nobody checked.

Rewrite the header's opening comment. It currently says FGX has no syslogd and
that `syslog()` writes to stderr; after this task the first is still true and
the second is not. State the current state: the line goes to `/dev/log` when
something is bound there, and falls back to `/usr/adm/messages` and then
`/dev/console` when nothing is. Remove the "Consequence worth knowing"
paragraph about detached daemons losing stderr -- it stops being true.

- [ ] **Step 2: Write the failing check**

Add to the probe:

```c
    /* syslog(3) must reach a BOUND /dev/log rather than stderr.  Bind it here,
     * in this process, then log and read the datagram back -- which is the
     * only way to prove the sink WITHOUT syslogd existing yet.
     *
     * THE CONTROL IS THE PREFIX, not merely that bytes arrived: a syslog that
     * still wrote to stderr would leave this recv blocking forever, and a
     * syslog that reached the socket but dropped the <pri> would be
     * unparseable by the syslogd that Task 4 of the NEXT plan adds. */
    {
        struct sockaddr_un sun;
        int                lg;
        char               lb[256];

        lg = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (lg < 0) {
            printf("unixprobe: FAIL log-socket errno=%d\n", errno);
            return (1);
        }
        (void)unlink("/dev/log");
        sun.sun_family = AF_UNIX;
        strcpy(sun.sun_path, "/dev/log");
        if (bind(lg, (struct sockaddr *)&sun, sizeof sun) < 0) {
            printf("unixprobe: FAIL log-bind errno=%d\n", errno);
            return (1);
        }

        openlog("unixprobe", LOG_PID, LOG_AUTH);
        syslog(LOG_NOTICE, "hello %d", 42);

        n = recv(lg, lb, sizeof lb - 1, 0);
        if (n <= 0) {
            printf("unixprobe: FAIL log-recv got=%d\n", n);
            return (1);
        }
        lb[n] = '\0';
        /* "<pri>Mon dd hh:mm:ss unixprobe[pid]: hello 42" */
        if (lb[0] != '<') {
            printf("unixprobe: FAIL log-no-pri '%s'\n", lb);
            return (1);
        }
        if (strstr(lb, "unixprobe[") == (char *)0 ||
            strstr(lb, "hello 42") == (char *)0) {
            printf("unixprobe: FAIL log-body '%s'\n", lb);
            return (1);
        }
        closelog();
        (void)close(lg);
        (void)unlink("/dev/log");
    }
```

- [ ] **Step 3: Run it and watch it fail**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram
```

Expected: FAIL at `log-recv got=-1` or a hang to the timeout -- `syslog()`
still writes to stderr, so nothing arrives on the socket. A timeout here is a
correct failure, not a harness problem.

- [ ] **Step 4: Rewrite syslog.c from upstream**

Port `examples/2.11BSD/usr/lib/libc/gen/syslog.c` (sccsid 8.4.3, 1995/07/15).
Keep, deliberately:

- the `#ifdef pdp11` fallback -- it is upstream's own socketless path and
  becomes FGX's belt-and-braces for single-user and for before `syslogd`
  starts. Compile it unconditionally rather than under `pdp11`, and say in the
  comment that it is upstream's arm, not an FGX invention;
- `%m` handling, which the current FGX file already gets right and telnetd
  relies on;
- `__progname` as the default `LogTag` -- it exists, at
  `toolchain/lib/crt0_far.s:427`, a 2-byte near cell holding a bank-0 offset.

Replace `writev` (header-only in FGX) in the LOG_PERROR path with two
`write`s, and note that substitution in the file's comment.

Watch the stack. `syslog` had a 270-byte frame and `slogprobe`
(`/testbin/slogprobe`) exists to measure exactly this via `procinfo`. Upstream
declares `char tbuf[640], fmt_cpy[512]` -- over 1 KB of locals, which is far
more than the current FGX file's `SL_FMT_MAX 256`. Measure before assuming it
fits:

```bash
python3 tools/mame_test/run.py slogprobe
```

If the frame does not fit, the fix is a smaller `tbuf`/`fmt_cpy` bounded by
syslogd's `MAXLINE` 1024, with the narrowing stated in the file comment and the
man page -- not a silent truncation.

- [ ] **Step 5: Build and run -- must PASS**

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja disk/fgxufs.po
python3 tools/mame_test/run.py unixdgram slogprobe
```

- [ ] **Step 6: Prove the sink assertion can go red**

Revert `syslog()`'s send to `fprintf(stderr, ...)` only. Rebuild, re-run.

Expected: FAIL at `log-recv`. Revert, confirm PASS.

- [ ] **Step 7: Update su's BUGS line**

`src/userland/su/su.c:21` reads:

> BUGS: syslog(3) writes to the console here, there being no syslogd.

That was two claims and both change: it goes to `/dev/log` now, and with no
`syslogd` yet the fallback is `/usr/adm/messages`. Rewrite to the current
state. Do the same for any other affected caller:

```bash
grep -rn "no syslogd\|there being no" src/userland/ toolchain/
```

- [ ] **Step 8: Run the affected callers' own tests**

`su`, `inetd`, `telnetd` and `reboot` all call `syslog`. Their sink just
changed, so the blast radius is all four.

```bash
python3 tools/mame_test/run.py
```

Expected: no new failures against the baseline recorded in Task 3 Step 5.

- [ ] **Step 9: Commit**

```bash
git add toolchain/lib/libc_c/syslog.c toolchain/include/syslog.h \
  src/userland/su/su.c src/userland/unixprobe/unixprobe.c docs/PROVENANCE.md
git commit
```

Body names `examples/2.11BSD/usr/lib/libc/gen/syslog.c` and its sccsid, and
states that the `#ifdef pdp11` file fallback is upstream's own arm.

---

## Task 7: gate wiring, man page, changelog

**Files:**
- Modify: `tools/gate.sh`
- Create: `src/userland/man/pages/man4/unix.4`
- Modify: `docs/CHANGELOG.md`, `docs/ROADMAP.md`

- [ ] **Step 1: Pick the retiree**

The gate has a seconds ratchet with zero headroom, so `unixdgram` costs another
case its slot.

```bash
python3 tools/gate_budget.py
sed -n '600,660p' tools/gate.sh
```

Choose a case whose coverage `unixdgram` subsumes or which has not gone red in
the longest time, and justify the choice in the commit body. Do not simply
raise the budget.

- [ ] **Step 2: Add unixdgram, remove the retiree**

Edit the case list at `tools/gate.sh:625`. Add a comment block in the style of
the `sockleak`/`selwild` ones at `:786`: what the test guards, and the evidence
it can go red -- cite the two mutations from Task 2 Step 8 and Task 6 Step 6.

- [ ] **Step 3: Write the man page**

Create `src/userland/man/pages/man4/unix.4`, modelled on an existing man4 page.
BUGS must state every divergence from the spec's section 7:

- no SOCK_STREAM (EPROTOTYPE); upstream's is what `pipe(2)` is built from and
  this kernel has real pipes;
- no access rights / SCM_RIGHTS;
- every record carries a zero-length sender name in practice, because
  `syslog(3)` never binds;
- a datagram too large for the ring is dropped whole with ENOBUFS; upstream's
  ceiling is `sb_hiwat` against an mbuf pool, FGX's is a 4 KB grown ring;
- whether `MSG_TRUNC` is reported, per Task 2 Step 4.

- [ ] **Step 4: Confirm the man page builds and check the gate rule**

A doc-only change does not need the full gate -- ask what the edit can reach.
The man page is staged onto the image, so it needs the regen:

```bash
python3 tools/ninja/gen.py -o build.ninja && ninja
```

- [ ] **Step 5: Changelog and roadmap**

`docs/CHANGELOG.md` gets the increment. `docs/ROADMAP.md` gets at most a
one-paragraph pointer noting that increments 4-5 (`/dev/klog`, `syslogd`,
`logger`, `syslog.conf`) remain, with their libc prerequisites named.

- [ ] **Step 6: Full gate**

```bash
tools/gate.sh
```

Expected: green. **Read which stage failed if it is not** -- gate.sh stops at
its first red stage, and a vacuous-needle stop has hidden a red boot test for
four increments before.

- [ ] **Step 7: Commit, then stop**

```bash
git add tools/gate.sh src/userland/man/pages/man4/unix.4 \
  docs/CHANGELOG.md docs/ROADMAP.md
git commit
```

Then **stop and report**. Do not push the feature branch (needs
`ALLOW_FEAT_PUSH=1` and the maintainer's OK) and never self-merge the MR.

---

## Post-plan: what to write to memory

Capture promptly, group `fgx`, not deferred to the end:

- `add_triplet`: `ufs_create` -- the `VSOCK` arm and that `unp_bind` uses
  `VOP_CREATE` not `VOP_MKNOD` (kills the mknod reflex next time).
- `add_triplet`: the receiver-owns-the-ring rule from `sbappendaddr`, and that
  it is what keeps AF_UNIX inside `NPIPE 8`.
- `add_memory`: one focused episode for the measured core-bank delta from
  Task 2 Step 9, since that is the number the residency campaign will want.
- Note the three retired comments, so a later reader does not re-derive that
  "sockets never arrive".
