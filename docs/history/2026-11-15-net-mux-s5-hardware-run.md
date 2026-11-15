# Net-mux S5: the run on real hardware

Image: `disk/fgxroot-s5.fs` (`feat/net-mux`, the shipping configuration).  The card
has one name, `wz0`, and `ifconfig`, `route` and `dhclient` configure it the way
2.11BSD does, with ioctls on a socket; FGX's own interface call is gone.
`ifconfig` shows the card's MAC on an `ether` line.  AF_UNIX passes descriptors,
and the file table holds 128.  A real IIgs, an Uthernet II, and a LAN with DHCP.
One boot; about 40 minutes.

## 1. The boot

Expect, during boot:

| Line | Means |
|---|---|
| `module: bsdnetd loaded` ... `bsdnet3 loaded` | the stack loads from `/etc/rc` |
| `w5: attached, <the card's MAC>, rx 8192` | socket 0 is the stack's |
| `bsdnet: ok` | the stack came up |
| `wz0: bound to <address> -- renewal in N seconds`, then `gateway` and `dns` | dhclient's lease, set through `SIOCSIFADDR` and `SIOCADDRT` |

The lease line now names `wz0`, where S4's said `u2s1`.  No `bound to`, a `PANIC`,
a yellow border or a wedge: **stop, and send me the screen**.

## 2. ifconfig

    ifconfig wz0
    ifconfig lo0

Expect for `wz0`:

    wz0: flags=63<UP,BROADCAST,NOTRAILERS,RUNNING>
            inet <the lease's address> netmask FFFFFF00 broadcast <the LAN's broadcast>
            ether <the card's MAC>

and for `lo0` `flags=9<UP,LOOPBACK>` and `inet 127.0.0.1 netmask FF000000`.  The
`ether` line must match the MAC on the `w5: attached` line.  `u2s1` should appear
nowhere: `ifconfig u2s1` answers `ioctl (SIOCGIFFLAGS): no such interface`.

## 3. route, and route -f

Note the gateway from the `bound to` line, and pick an address off the LAN that
answers ping (`8.8.8.8` usually does).

    ping 8.8.8.8 3
    route -nf
    ping <the gateway> 3
    ping 8.8.8.8 3
    route add default <the gateway> 1
    ping 8.8.8.8 3

Expect replies to the first ping.  `route -nf` prints `Flushing routing tables:`,
then `default`, the gateway and `done` on one line; like 2.11BSD's, it finds the
table through the name list `/netnix` and reads it through `/dev/mem`.  The
gateway still answers after it (the LAN's route is the interface's, not a
gateway route, so `-f` keeps it).  The second ping to 8.8.8.8 gets no replies:
there is no default route.  `route add` prints `add net default: gateway <the
gateway>`, and the third ping is answered again.

## 4. dhclient by hand

    dhclient

Expect the `bound to` line again, with the same address.  dhclient deletes the
default route through the lease's gateway, which step 3 added, and adds its own.  Then:

    ping 8.8.8.8 3

answered.

## 5. A static address, from netstart's commented lines

`/etc/netstart` carries a static configuration, commented out, in place of
dhclient.  Run its lines by hand, with a free address on the LAN (one outside the
DHCP server's range), the LAN's netmask and broadcast, and the gateway:

    route -nf
    ifconfig wz0 inet <a free address> netmask 255.255.255.0 broadcast <the LAN's broadcast>
    route add default <the gateway> 1
    ifconfig wz0

Expect `ifconfig wz0` to show the new address.  From the Mac:

    ping -c 3 <the new address>

answered.  On the IIgs, `ping 8.8.8.8 3` answered.  Then put the lease back:

    dhclient

and `ifconfig wz0` shows the lease's address again.

## 6. Descriptor passing over AF_UNIX

    /testbin/unixprobe -r
    /testbin/unixprobe -r gc

Expect `UNIX R ok`, then `UNIX R gc ok` after a few seconds.  The first sends an
open file's descriptor over an AF_UNIX socket and reads the file through the
received one after the sender closed its own.  The second does it 150 times with
the message never read, which only finishes if the kernel closes each in-flight
file.  This is machine-independent, so MAME has passed it; on hardware it is a
check that nothing in the timing differs.

## 7. S4's steps once more

The S4 page, `docs/history/2026-11-13-net-mux-s4-hardware-run.md`, steps 2 to 7:
telnet in from the Mac twice, ftp and its rate, sixteen connections at once, ping
both ways with no `DUP!`, syslog over `/dev/log` and UDP, and netdump.  Expect what
that page expects.  Under MAME the 1 MB `lo0` transfer now takes 27.5 s, 37 KB/s
(S4: 28.6 s).

## What I need back

1. The `bound to` line, and whether it names `wz0`.
2. `ifconfig wz0`'s three lines, and whether `ether` matched the attach line.
3. Step 3: which pings were answered, and what `route -f` printed.
4. Whether dhclient by hand bound again.
5. Whether the static address answered the Mac, and dhclient put the lease back.
6. Both `UNIX R` lines.
7. S4's list, items 2 to 7.
8. Anything else odd.
