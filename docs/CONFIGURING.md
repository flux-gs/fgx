# Configuring a machine

What a running FGX machine starts at boot, and how to change it.  Every change
here is made on the machine itself, as root, and takes effect at the next boot.

The image ships with only what every machine needs turned on.  Everything that
depends on hardware a machine may not have, or that opens the machine to the
network, is listed in `/etc/rc.local` and commented out.  `/etc/rc` runs that
file last, as 2.11BSD's `rc` does; remove the `#` from a line to turn it on.

## Logins and passwords

The console (Option-1) is a root shell as soon as the machine has booted.  The
other consoles (Option-2 and Option-3) and telnet ask for a login.  Two
accounts can log in, and **both passwords are `fgx`**:

| Account | What it is |
|---|---|
| `root` | the super-user |
| `fgx` | an ordinary user, in group `wheel`, so it can `su` to root |

Change them with `passwd(1)` -- as root, `passwd root` and `passwd fgx` -- before
the machine is on a network you do not control, and before turning on telnet
logins (see [Network services](#network-services)).

## The clock and the time zone

**The IIgs clock keeps local time, and FGX keeps UTC.**  At boot, `/etc/rc`
runs `adjkerntz -i`, which reads the zone from `/etc/localtime` and converts
the IIgs clock's local time to UTC for the kernel (`adjkerntz(8)`; the empty
file `/etc/wall_cmos_clock` is what says the clock keeps local time).

**The image does not know where the machine is, so it ships UTC.**  Until a
zone is chosen, the clock's local time is read as if it were UTC, and the boot
says so:

    time zone not set (UTC); the IIgs clock is read as UTC -- see /etc/rc.local

To choose a zone, copy its file over `/etc/localtime` and reboot:

    cp /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
    reboot

The zones are under `/usr/share/zoneinfo`, named by region and city
(`Europe/London`, `Australia/Sydney`, ...).  `date` then prints local time with
the zone's abbreviation.

**FGX never writes the IIgs clock unless you ask it to.**  Setting the time with
`date(1)`, or keeping it with `ntpd`, changes FGX's clock only; the next boot
reads the IIgs clock again.  This is a deliberate difference from FreeBSD, whose
kernel writes the clock back: the IIgs clock belongs to the machine, and GS/OS
reads it too.  The kernel variable `machdep.disable_rtc_set` controls it -- 1,
the default, leaves the clock alone; 0 writes it back whenever the time is set
(`settimeofday(2)`).

**Daylight saving time.**  The IIgs has no notion of it.  When the clocks
change, `adjkerntz -a` (run from `/etc/crontab`) moves FGX's offset, so FGX's
time stays right while the machine is up -- but set the IIgs clock to the new
local time yourself, from the Control Panel, as GS/OS needs anyway, or FGX reads
it an hour out at the next boot.

### Network time

`ntpd(8)` keeps FGX's clock with the servers in `/etc/ntp.conf`.  It is off by
default.  To turn it on, remove the `#` from its line in `/etc/rc.local`:

    #/sbin/ntpd

It runs only when the network came up at boot.  Choose the time zone first:
with the wrong zone, FGX's clock starts hours out, and `ntpd` refuses an offset
that large (`Clock is too far off`) rather than step the clock by it.

`ntp -s` (`ntp(8)`) sets the clock once from a server, for a machine that does
not need `ntpd` running.

## The RAM disk

Set a RAM disk size in the Control Panel ("RAM disk", in battery RAM) and FGX
mounts it, writable, on `/ram5` at every boot -- `df` shows it as `/dev/ram0`.
It is a ProDOS volume, the same `/RAM5` GS/OS and ProDOS 8 see, and because
the ROM keeps it across a soft reboot, what you put on it is still there after
one.  With no size set there is no RAM disk, and FGX makes none.

On an 8 MB ROM 03 machine the ROM fails to create the RAM disk itself (GS/OS
works around the same bug at boot), so FGX has the ROM make it, sized from the
Control Panel setting.  The boot log says which happened:
`ramdisk: 512 blocks @ bank $38 (adopted)` for a disk the ROM had, `(made)` for
one FGX had the ROM make, `ramdisk: none` for no size set.

## Devices

These modules drive hardware a machine may not have, so `/etc/rc.local` loads
them only when they are turned on.  `/etc/rc` loads the rest -- `net` (sockets
and `pipe(2)`), `ramdisk` (the Control Panel's RAM disk, when there is one),
`pty`, `klog` and `fpsim` -- on every machine.

| Device | Module | What it gives you |
|---|---|---|
| Serial ports | `serial` | the SCC's two ports as terminals: `/dev/tty00` (channel A, the printer port) and `/dev/tty01` (channel B, the modem port), for `tip(1)` and `cu(1)` |
| Packet capture | `bpf` | `/dev/bpf0`, raw Ethernet frames from the Uthernet II, for `netdump` |
| Second Sight card | `sscon` | a fourth console, `ttyv3` (Option-4), on the card's Host Text mode |
| Desk accessories | `cda` | the Ctrl-OA-Esc desk accessory menu with FGX's colours restored, and `/dev/cda` for `loadcda(8)` |

Each has its own line in `/etc/rc.local`; remove the `#` to load it:

    #/sbin/modload serial >/dev/console 2>&1

**Second Sight.**  The card has no slot signature, so `sscon` looks in the slot
the image was built for -- slot 3, set by `sscon.slot` in `cfg/system.cfg`.
Without a card it prints `sscon: no card in slot 3` and does nothing.

**CD-ROMs.**  A CD-ROM drive on a SmartPort card -- an Apple SCSI CD-ROM on
the Apple II SCSI Card -- attaches as `/dev/cd0` with no module to load, and
the boot log says whether a disc is in it (`cd0 at sp0 unit 2: empty`).  The
card presents a CD's ProDOS partition as a disk, so a ProDOS CD mounts with
`mount_prodos -o ro /dev/cd0 /mnt`.  The device is read-only; an ISO 9660
filesystem cannot be mounted yet.

**Desk accessories.**  `cda` only makes the menu work; `loadcda(8)` installs an
accessory, from `/usr/fgx/cda` or anywhere, and it stays in memory until the
machine restarts.

## Network services

`inetd(8)` accepts telnet logins, as `/etc/inetd.conf` lists them.  It is off by
default: a telnet login is a password sent in the clear, and FGX's telnet daemon
is the one from `/testbin`.  To turn it on, remove the `#` from its line in
`/etc/rc.local`:

    #/sbin/inetd

Like `ntpd`, it runs only when the network came up at boot.  The network itself
is always started (`/etc/netstart`, DHCP through `dhclient(8)`); see
[networking.md](networking.md).

## Building an image with a zone already set

When you build the image yourself, it can carry your zone from the start: put
the zone's name in `.fgx_tz` at the top of the source tree, or set `FGX_TZ`, and
rebuild.  See [BUILDING.md](BUILDING.md).
