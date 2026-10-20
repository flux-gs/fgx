# TCP urgent data: implementing the mechanism where BSD puts it

> **STATUS, 2026-09-17 -- U0 HAS LANDED.**  `send(2)` and `recv(2)` refuse
> `MSG_OOB` now (apple/fgx#422), and with it three adjacent defects this
> analysis did not reach: `sendto`/`recvfrom` never carried their flags word at
> all (apple/fgx#440), `send` ignored `MSG_DONTWAIT` (apple/fgx#441), and
> `setsockopt` accepted every option at every level with the value discarded in
> libc (apple/fgx#439).  So **section 4's defect is fixed**, and **section 8's
> `SO_OOBINLINE` question is answered**: upstream ACCEPTS it in `sosetopt`'s
> boolean bag (`uipc_socket.c:672`) and it is vacuous until a mark exists, so it
> belongs to U2/U4 rather than to a refusal.
>
> Two of section 6's predictions did not survive contact.  The `OFFLOAD_URG`
> capability bit is NOT there: `OFFLOAD_UDP`/`ICMP`/`TCP` were measured to have
> zero readers anywhere in the tree, so a fourth would be the same absent
> behaviour behind a present interface this campaign exists to close.  And
> EOPNOTSUPP is not the errno upstream TCP gives -- `PRU_RCVOOB` answers EINVAL
> for an empty mark (`tcp_usrreq.c:253-266`), which is what `telnet(1)` tests
> for, so the client needed an explicit in-band fallback in the same commit or
> U0 would have dropped the connection on every interrupt.
>
> Everything below is the document as written on 2026-09-13, kept in the present
> tense of that date.  `docs/ROADMAP.md` carries the current state.

Scoped by the maintainer 2026-09-13, while evaluating what a full `telnetd(8)` port
would run into.  The position, verbatim in intent:

> we should support tcp urgent in the sense that there are other network
> controllers besides the uthernet2, and although we are uthernet2 shaped
> right now, the underlying stack should correctly implement the mechanism
> even if the w5100 can't actually pass the flag.

This is a design doc, not a campaign charter.  It says what the mechanism is,
where it belongs, what FGX is missing underneath it, and in what order the
pieces can land.  The work items are apple/fgx#422 through apple/fgx#427,
filed against the increments in section 6; this is the document they point
at.


## 1. What the hardware can and cannot do

MEASURED from the vendored datasheet (`examples/marinetti/w5100s-ds-v128e.pdf`,
W5100S v1.2.8), not from recollection.

`Sn_CR` (SOCKET n Command Register, 3.2.2) is the complete command set:

    0x01 OPEN    0x02 LISTEN   0x04 CONNECT   0x08 DISCON   0x10 CLOSE
    0x20 SEND    0x21 SEND_MAC 0x22 SEND_KEEP 0x40 RECV

`Sn_IR` (SOCKET n Interrupt Register, 3.2.3) is the complete notification set:

    bit 4 SENDOK   bit 3 TIMEOUT   bit 2 RECV   bit 1 DISCON   bit 0 CON
    bits 7:5 Reserved

The socket register file (3.2.1 through 3.2.21) contains no urgent-pointer
register and no urgent-related status.  `Sn_SR` (3.2.4) has no urgent state.

SO, IN HARDWARE TCP MODE, THE CHIP CAN NEITHER SEND URGENT DATA NOR REPORT
THAT ANY ARRIVED.  There is no partial support to expose and no register to
read: the offload terminates TCP inside the chip and the host never sees a
segment header.

The one escape hatch is MACRAW, which hands the host raw Ethernet and lets it
run its own TCP.  `Sn_MR` P[3:0] = 0100, and the datasheet is explicit that
"MACRAW Mode is used only with SOCKET 0".  FGX has already spent socket 0 on
`/dev/bpf0` capture (`include/socket.s:72`), so MACRAW is not free either.


## 2. Why the socket layer is the right place, and the driver is not

This is the load-bearing argument for doing the work at all, and it is
upstream's own structure rather than a preference.

In 2.11BSD every part of the urgent MECHANISM lives in
`vendor/2.11BSD/usr/sys/sys/uipc_socket.c`:

| piece                                             | line      |
|---------------------------------------------------|-----------|
| `sosend` splits `PRU_SENDOOB` from `PRU_SEND`     | :390      |
| `soreceive` routes MSG_OOB to `PRU_RCVOOB`        | :441-443  |
| the mark arithmetic, `so_oobmark` / `SS_RCVATMARK`| :544-577  |
| `sohasoutofband` -- SIGURG plus the select wakeup  | :808-824  |

A protocol or driver contributes only two request codes.  A transport that
cannot do out-of-band answers `EOPNOTSUPP`, and THAT IS UPSTREAM'S OWN ANSWER
rather than a divergence we would be inventing: `pr_usrreq` returning
EOPNOTSUPP for PRU_SENDOOB is how every non-OOB protocol behaves.

So "the W5100 cannot pass the flag" does not prevent FGX from having a correct
implementation.  It determines what ONE transport answers.

### The hook already exists

`include/socket.s:33-46` already carries the shape this needs:

    XPORT_NONE/UDP/ICMP/TCP        transport tags, stored in SOCK_Proto
    OFFLOAD_UDP/ICMP/TCP           link-driver capability bits

with the file's own description: "The socket core resolves (type,proto) -> a
tag and routes through the driver's offload handler for that tag."  Urgent
becomes one more capability consulted at that same fork.  No new architecture
is required, which is the main reason this is worth doing now rather than
after a stack rewrite.


## 3. What FGX is missing underneath

Three gaps, and they are the real work.  None of them is about the W5100.

**3.1 `select(2)` has no exceptional set.**  `src/kernel/vfs/vfs_syscalls.c`
says so in its own words:

> THE EXCEPTIONAL SET IS THE THIRD CALL AND IS NOT MADE.  Reno asks a third
> time with flag = 0; FGX's readiness word has two bits and no caller of it
> has an exceptional set to fill, so asking would produce an answer with
> nowhere to go.

That was true when it was written.  `sohasoutofband`'s `SELWAKEUP` is the
caller it was waiting for, and so is `telnetd`'s `stilloob()`, which selects
on the exception set to wait for the urgent mark.  The readiness word needs a
third bit and `vfs_select` needs upstream's third call.

**3.2 Sockets have no owner process group.**  `sohasoutofband` signals
`so->so_pgrp`.  FGX has no `SIOCSPGRP`/`SIOCGPGRP`, and no `fcntl(2)` at all,
so `F_SETOWN` is not available either.  Without an owner there is nobody to
send SIGURG to.  (This is the "what is absent" axis of the syscall-conformity
campaign arriving from a different direction: `fcntl` was already its
standout gap.)

**3.3 Nothing raises SIGURG.**  The signal exists as a number with `SA_IGN`
as its default disposition (`src/kernel/signal.s:2016`), which is correct --
upstream's default for SIGURG is ignore -- but no kernel path ever posts it.


## 4. One defect that exists today, independent of all of the above

`send(fd, buf, len, MSG_OOB)` SILENTLY SUCCEEDS AS AN ORDINARY SEND.  The
flags word reaches the kernel in the argblk and is tested only for
`MSG_DONTWAIT` (`src/modules/net/net_xport.s:1327`); `MSG_OOB` is ignored.

That is the worst of the three possible behaviours.  Refusing is honest and
failing loudly is debuggable, but delivering urgent data in-band with no
indication to either end means a caller that believes it sent OOB and a
receiver that never learns any arrived.  `SIOCATMARK` has the same shape one
layer up: `include/socket.s:31` hardcodes the answer 0 with the comment
"always 0; no urgent", so a caller asking "am I at the mark" is told "no"
by a constant rather than by the transport.

Worth fixing on its own, before and regardless of the mechanism.


## 5. Per-transport dispositions

| transport        | disposition                                            |
|------------------|--------------------------------------------------------|
| loopback         | FULL semantics.  Both ends are in the kernel, so mark, SIGURG, SO_OOBINLINE and SIOCATMARK are all expressible with no hardware involved. |
| W5100 TCP        | Capability ABSENT.  `PRU_SENDOOB`/`PRU_RCVOOB` answer EOPNOTSUPP; SIOCATMARK reads real transport state, which for this transport is permanently "not at mark" -- the same answer as today, but derived rather than asserted. |
| future MACRAW + software TCP | Full, when Track B exists.  Out of scope here. |

THE LOOPBACK CASE IS NOT A CONSOLATION PRIZE.  `telnet_loopback` and
`ttypeneg` already run `telnetd` against `127.0.0.1`, so the SYNCH path
becomes testable end to end, in the suite, with no hardware.  An
implementation that is exercised on every suite run is worth more than one
that waits for a NIC nobody has yet.


## 6. Increments

Ordered smallest-blocker-first, so each lands on its own and the one before it
is what made the next possible.

**U0.  `send(MSG_OOB)` stops lying.**  apple/fgx#422.  Return EOPNOTSUPP where the transport
has no urgent capability.  No new state, no new syscall.  Closes section 4's
defect and is independently shippable.

**U1.  `select(2)` gains its exceptional set.**  apple/fgx#423.  Third call in `vfs_select`,
third bit in the readiness word, `_SelOp_*` arms extended.  Blocks U3 and
blocks `telnetd`'s `stilloob` forever otherwise.

**U2.  Socket-layer urgent state.**  apple/fgx#424.  Port `so_oobmark` and `SS_RCVATMARK`,
`soreceive`'s clamp at the mark (uipc_socket.c:544-577), and make SIOCATMARK
read that state instead of a constant.  Still no way to CREATE a mark, so this
is inert until U4 -- which is why it is testable only as "the mark is never
set and everything still behaves".

**U3.  Owner pgrp and SIGURG.**  apple/fgx#425.  `so_pgrp` plus `SIOCSPGRP`/`SIOCGPGRP`, and
`sohasoutofband` (uipc_socket.c:808) posting SIGURG and waking the exception
set.  Depends on U1.

**U4.  Loopback `PRU_SENDOOB`/`PRU_RCVOOB`.**  apple/fgx#426.  The first transport that can
actually set a mark.  This is the increment that makes U2 and U3 observable,
and the one the fixtures can test.

**U5.  `telnetd` SYNCH.**  apple/fgx#427.  `interrupt()` and `sendbrk()` per upstream, with
the urgent path live on loopback and the inline fallback on the wire.
Depends on U4.

The W5100 driver is touched in U0 only, to declare one capability bit.


## 7. What this does and does not buy

BUYS: correct urgent semantics on loopback, exercised by the existing telnet
fixtures; an honest refusal on the wire instead of silent in-band delivery;
`telnetd`'s last deferred path; and the mechanism sitting where a different
NIC or a software TCP would find it already built.

DOES NOT BUY: urgent data over Ethernet.  FGX has no software TCP -- loopback
is pipe-backed (`src/modules/net/net_loop.s` over `pipe.s`), not a stack -- and
the W5100 terminates TCP in hardware.  Over the wire, `telnetd` will send
`IAC IP`/`IAC DM` inline and the SYNCH flush will not happen.  That divergence
belongs in telnetd(8)'s BUGS section, stated rather than discovered.

NOT A PREREQUISITE FOR ANYTHING CURRENTLY SHIPPING.  Nothing in FGX userland
sends or expects OOB today except `telnetd`'s two deferred functions.


## 8. Open questions

- Does the Uthernet II's W5100 (not the W5100S measured here) differ in any
  register that matters?  The vendored datasheet is the S variant; the part on
  the card is the original.  The socket register file is believed identical in
  the relevant sections, and this should be confirmed before anyone cites this
  document as evidence about the shipping card.
- `SO_OOBINLINE` is defined in `toolchain/include/sys/socket.h:22` with no
  implementation.  U2 should either implement it or make `setsockopt` refuse
  it, for the same reason as section 4.
- Whether `fcntl(2)` arrives before U3, in which case `F_SETOWN` is the
  upstream spelling and `SIOCSPGRP` becomes the compatibility alias rather
  than the primary.
