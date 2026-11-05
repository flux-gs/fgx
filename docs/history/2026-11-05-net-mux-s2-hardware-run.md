# Net-mux S2: the run on real hardware

Image: `disk/fgxroot-s2probe.fs` (`feat/net-mux`, `kernel.netprobe = 1`).  It boots
as a normal system, and nothing network-stack happens until the first command below.
A real IIgs, an Uthernet II, and a LAN with DHCP.  One boot; 10 minutes.

## 1. The stack on the wire

    modload bsdnetd bsdnet0 bsdnet1 bsdnet2 bsdnet3
    sleep 90
    dmesg | tail -24

Expect, in `dmesg`:

| Line | Means |
|---|---|
| `w5: attached, <the card's MAC>` | socket 0 opened in MACRAW |
| `bsdnet: ok` | the self-test passed |
| `bsdnet: callouts ok` | timers fire on time |
| `bsdnet: lo0 echo ok` | IP and ICMP work over loopback |
| `bsdnet: w5 received` | a real frame came through the driver |
| `bsdnet: w5 bad length reopened` | the socket recovers from a nonsense length |
| `bsdnet: w5 pool empty dropped` | no mbufs: the frame is skipped and the machine carries on |
| `bsdnet: w5 torn read survived` | a misread receive count does not cost the ring |
| `bsdnet: arp resolved <gateway's MAC>` | ARP through the kernel |
| `bsdnet: echo reply from gateway` | **S2's proof** |
| `bsdnet: echo rtt N ticks` | **note N**: MAME says 7-8 |
| `bsdnet: burst of 45 got N frames`, `burst errors N` | **note both**: MAME says 33 and 2 |
| `bsdnet: burst drained in ticks N` | **note N**: MAME says 18-19 |
| `bsdnet: alive after burst` | the machine survived the overrun |
| `bsdnet: net stack N of 1024` | **note N**: MAME says 368 |

The `w5 ...` lines each wait for a frame from the LAN, so a very quiet network takes
longer.  Any `bsdnet: BROKEN <n>`, a `PANIC`, a yellow border or a wedge: **stop, and
send me the screen**.

## 2. Hardware TCP beside MACRAW

**This is the run's main question.**  Same boot, stack still loaded, using any FTP
server you like with a file whose checksum you know:

    ftp <server>
    (log in, then)  binary
    get <a file of a megabyte or so> /tmp/f
    quit
    sum /tmp/f

Expect the file to arrive and `sum` to match the host's.  Passive mode is on by
default.  If the control connection works and the data connection does not, say which
error: `No buffer space available` only means something else holds a socket.

## 3. Ping, from another machine

    ping <the IIgs's address>

Expect one reply per request and **no `DUP!`**, with the kernel answering and the chip
blocked by `MR_PB`.  Duplicates mean the chip ignores the bit.  The stack has no
default route yet, so ping from the IIgs's own subnet.

## 4. netdump (optional)

    modload bpf
    netdump 10

Expect `listening on /dev/bpf0` and ten lines of LAN traffic, with no `[saturated]`
unless the LAN is busy.  Answer it from step 3's ping to make traffic.

## What I need back

1. Did step 2's `sum` match?  This decides whether "UDP first, TCP later" stands
   (design section 7).
2. The five noted numbers, and whether step 3 showed `DUP!`.
3. Anything else odd: the card's link lights, the console, timing.

Real hardware is the only thing that can answer these, and MAME could not:

- Does the real W5100 honor the MAC filter bit (`$44`)?  The datasheet I could get
  (v1.1.6) does not document it.
- Does close and reopen really reset the receive pointers?
- What does an overrun do: drop silently, or corrupt a header?
- Do the 7-8 ticks of round trip exist on hardware, or are they the emulator's?
