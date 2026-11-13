# Net-mux S3: the run on real hardware

Image: `disk/fgxroot-s3.fs` (`feat/net-mux`, the shipping configuration).  UDP now
runs on the kernel's own network stack; the network modules load at boot and take
the DHCP lease through it.  TCP and ping are still the chip's.  A real IIgs, an
Uthernet II, and a LAN with DHCP.  One boot; about 20 minutes.

## 1. The boot

Expect, during boot:

| Line | Means |
|---|---|
| `module: bsdnetd loaded` ... `bsdnet3 loaded` | the stack loads from `/etc/rc` |
| `w5: attached, <the card's MAC>` | socket 0 is the stack's, in MACRAW |
| `bsdnet: ok` | the stack came up |
| `u2s1: bound to <address>`, then `gateway` and `dns` | **dhclient's lease, through the kernel stack**, from 0.0.0.0 |

No `bound to` (a `no DHCPOFFER`), a `PANIC`, a yellow border or a wedge: **stop, and
send me the screen**.

A line reading just `%s: %s` is 2.11BSD's `duplicate IP address!! sent from ethernet
address ...`: the stack's console messages print only their format string.  Under
MAME the host's network answers ARP for the guest's address, so it appears there; on
your LAN it would mean another station claims the IIgs's address.  **Note it if you
see it.**

## 2. NTP

    /sbin/ntpd
    sleep 300
    ntpdc -n 127.0.0.1
    date

Expect `ntpdc` to print its peer table (`(rem)  Address ... Strat Poll Reach`), with
the servers in `/etc/ntp.conf` resolved to addresses and a nonzero `Reach`, and one
marked `*` once ntpd has chosen it, and `date` right.  (ntpd logs to local3, which
the shipped `syslog.conf` sends nowhere, so the peer table is the evidence.)

## 3. syslog over UDP, from another machine

    kill `cat /var/run/syslog.pid`
    /sbin/syslogd -u

Then from the Mac (or any host on the LAN):

    echo '<11>from the mac' | nc -u -w1 <the IIgs's address> 514

Expect `from the mac` on the IIgs's console (user.err goes there).

## 4. Ping from another subnet

From a host on a different subnet than the IIgs, the far side of the gateway:

    ping <the IIgs's address>

Expect replies.  S2 could not answer these: the stack had no default route.  Still
**no `DUP!`**.

## 5. ftp, and its rate

As in S2:

    ftp <server>
    (log in, then)  binary
    get <a file of a megabyte or so> /tmp/f
    quit
    sum /tmp/f

Expect `sum` to match the host's.  **Note the rate** ftp reports: S2 measured
9.6 KB/s with the stack loaded and 9.9 without.  ftp is still the chip's TCP, so the
question is whether anything moved.

## 6. netdump

    modload bpf
    netdump 20

(`modload` says `cannot place` if rc.local already loaded it; that is fine.)  Expect
`listening on /dev/bpf0` and lines of LAN traffic; step 4's ping makes some.  Note how
often `[saturated NN]` appears, against S2's "frequent".

## 7. The transmit wait (optional: a second image)

`disk/fgxroot-s3probe.fs` is the same tree with the self-test (`kernel.netprobe = 1`).
Boot it, wait 90 seconds after the lease, and:

    dmesg | grep bsdnet

Expect `bsdnet: five full frames sent in ticks N` (**note N**; MAME says 1-2) and no
`bsdnet: BROKEN` line.  This is the one check MAME cannot make: its chip reports the
transmit ring free the instant a frame is sent, so the new wait for a frame still on
the wire is exercised only on hardware.  The S2 lines (`echo rtt`, `burst of 45`)
are there too, if you want to compare them with S2's run.

## What I need back

1. The `bound to` line, and whether ntpdc showed a selected peer.
2. Whether step 3's line arrived, and whether step 4's ping was answered.
3. ftp's rate and whether `sum` matched.
4. netdump's `[saturated]` count, roughly.
5. If you ran step 7: N, and any `BROKEN`.
6. Anything else odd.

## Results (2026-11-10 to 2026-11-12)

A ROM 03 IIgs with a TransWarp at 15.4 MHz, booting from a MicroDrive Turbo, with an
Uthernet II in slot 1.

| Step | Result |
|---|---|
| 1. Boot | lease 192.168.1.137 through the stack, from 0.0.0.0 |
| 2. NTP | a `*` peer, Reach 077, once the IIgs's clock was within 1000 s of true (ntpd's `WAYTOOBIG`); `ntpdc`'s offset is 32-bit milliseconds and wraps past 24.8 days |
| 3. syslog -u | lines from the Mac arrived, 4-10 s after `nc` |
| 4. Ping from another subnet | answered |
| 5. ftp | 1048576 bytes at 9.9 KB/s; `sum` not compared |
| 6. netdump | 95 `[saturated]` in 300 packets, on a LAN with mDNS, LLMNR and 802.1Q traffic |
| 7. Transmit wait | not run |

Two hard freezes (no keys, no disk or CPU activity) came during the first sessions,
each after the network steps and a long idle, and one reboot after a freeze then
stalled in fsck before any network module loaded.  The card's file system checked
consistent, not marked clean, last written about 30 s before the freeze.  None
reproduced afterward: not under MAME (45 minutes of flood and idle, the card in slot
4, unsolicited syslog datagrams), not on the hardware with an image that colored the
border by kernel path, and not on the hardware with this image again, through the
same steps and a night's idle.  The machine has had marginal-hardware hangs before,
and the fsck stall happened with no network code running; the freezes are recorded
here unexplained.
