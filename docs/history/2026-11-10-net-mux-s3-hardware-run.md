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
