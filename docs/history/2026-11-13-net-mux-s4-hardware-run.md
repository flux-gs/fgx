# Net-mux S4: the run on real hardware

Image: `disk/fgxroot-s4.fs` (`feat/net-mux`, the shipping configuration).  Every
socket now runs on the kernel's own network stack: TCP, UDP, raw sockets and
AF_UNIX.  The W5100 carries nothing but frames, through socket 0 in MACRAW mode
with all 8 KB of its buffer memory each way, and the twelve-socket and
three-hardware-socket limits are gone.  A real IIgs, an Uthernet II, and a LAN with
DHCP.  One boot; about 30 minutes.

## 1. The boot

Expect, during boot:

| Line | Means |
|---|---|
| `module: bsdnetd loaded` ... `bsdnet3 loaded` | the stack loads from `/etc/rc` |
| `w5: attached, <the card's MAC>, rx 8192` | socket 0 is the stack's, with the whole 8 KB receive buffer |
| `bsdnet: ok` | the stack came up |
| `u2s1: bound to <address>`, then `gateway` and `dns` | dhclient's lease, through the kernel stack |

No `bound to`, a `PANIC`, a yellow border or a wedge: **stop, and send me the
screen**.  `rx` reading anything but 8192 means the chip did not take the buffer
split: **note it**.

## 2. telnet in from the Mac

On the IIgs:

    /sbin/inetd

From the Mac:

    telnet <the IIgs's address>

(macOS no longer ships `telnet`; `nc <the IIgs's address> 23` reaches the same
prompt.)  Expect a login prompt, and a shell after logging in.  This is the kernel's TCP
accepting a connection from the wire, where S3 still used the chip's.  Log out and
connect again: inetd keeps one listener for every connection, as BSD's does.

## 3. ftp, and its rate

    ftp <server>
    (log in, then)  binary
    get <a file of a megabyte or so> /tmp/f
    quit
    sum /tmp/f

Expect `sum` to match the host's.  **Note the rate** ftp reports.  S3 measured
9.9 KB/s on the chip's TCP; this is the kernel's TCP.  Under MAME a loopback
transfer of 1 MB runs at 25 KB/s, with a third of the time in the stack's
byte-by-byte `bcopy`, so a slower rate than S3's is possible and is the number I
need.

## 4. Many connections at once

With inetd running (step 2), from the Mac, open sixteen sessions at once:

    for i in $(seq 16); do (sleep 60 | nc <the IIgs's address> 23 > /dev/null &); done

Then on the IIgs:

    ps ax | grep -c telnetd

Expect 16 (or 17, counting the grep).  Before S4 the chip allowed three.  When they
have closed, after a minute, the IIgs should be as it was: `ps ax` with no
`telnetd`, and a new `telnet` from the Mac still answered.

## 5. Ping, both ways

From the Mac:

    ping -c 5 <the IIgs's address>

On the IIgs:

    ping <the Mac's address>

Expect replies both ways, each line on the IIgs with a `ttl=`, and **no `DUP!`**.
ping is now a raw socket on the stack, where it used the chip's ICMP before.

## 6. syslog over /dev/log and UDP

    logger -p user.err from the local socket

Expect the line on the console: that is AF_UNIX on the stack.  Then:

    kill `cat /var/run/syslog.pid`
    /sbin/syslogd -u

and from the Mac:

    echo '<11>from the mac' | nc -u -w1 <the IIgs's address> 514

Expect `from the mac` on the IIgs's console.

## 7. netdump

    modload bpf
    netdump 20

(`modload` says `cannot place` if bpf is already loaded; that is fine.)  Expect
`listening on /dev/bpf0` and lines of LAN traffic.  Note how often `[saturated NN]`
appears, against S3's 95 in 300 packets: the ring is 8 KB now, where it was 2 KB.

## What I need back

1. The `w5: attached` line's `rx`, and the `bound to` line.
2. Whether telnet from the Mac reached a shell, twice.
3. ftp's rate and whether `sum` matched.
4. How many telnetd step 4 counted, and whether the machine answered afterward.
5. Whether ping was answered both ways, and any `DUP!`.
6. Whether both syslog lines arrived.
7. netdump's `[saturated]` count, roughly.
8. Anything else odd.
