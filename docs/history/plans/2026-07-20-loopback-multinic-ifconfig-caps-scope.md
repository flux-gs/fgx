# Loopback, multi-NIC, and ifconfig capabilities -- scope + Track B triggers (2026-07-20)

Follow-up to `2026-07-19-networking-roadmap-scope.md` (Track A/B) and the
ROADMAP.md "Networking" bucket. The maintainer raised four gaps after the v1.12.0
networking release: (1) no loopback interface, (2) undefined behavior with two
Uthernet-II cards, (3) `ifconfig -a` doesn't work, (4) the W5100's offload
capabilities aren't reported by `ifconfig`. This doc records the near-term slice
shipped for #3/#4, the code findings behind #1/#2, and the decisions that route
the deep work into Track B. It does NOT re-derive Track B's P1-P6 -- see the
2026-07-19 doc for that.

## 1. Shipped now (near-term slice, tool-only) -- 2026-07-20

`ifconfig` improvements, no kernel/ABI/asm change (held local):
- **Real flags.** The status line was hardcoded `flags=67<UP,BROADCAST,RUNNING>`
  regardless of state; it now renders from the actual `IF_Flags` byte the kernel
  populates (`IFF_LINK_UP` at device-init, `IFF_IP_CONF` on config, `IFF_DHCP` on
  lease). A card that is present but link-down now reads `2<BROADCAST>`, not up.
- **Honest capability line.** A BSD-style `options=<TCP4,UDP4,ICMP4,ARP,CSUM_IP,
  CSUM_TCP,CSUM_UDP>` line reports the W5100's hardware offload. Rendered
  tool-side from interface type: the offload is fixed silicon, the `OFFLOAD_*`
  bits in `include/socket.s` are defined-only (no runtime mask), and the 32-byte
  ifreq is full (no room for a caps field).
- **`-a`** accepted as list-all (bare `ifconfig` already listed all).
- `ifconfig(8)` man page added (none existed). Test: `ifconfig_caps`.

**No cosmetic `lo0`.** A fake loopback entry would be throwaway; `lo0` arrives
organically in Track B (see below), so it is deliberately NOT added now.

## 2. Why loopback and multi-NIC are Track B, not quick fixes

**Loopback needs a software input path we do not have.** In 2.11BSD, `lo0` is not
a special socket path -- `if_loop.c`'s `looutput` feeds the packet straight back
into `ip_input` -> `tcp_input`/`udp_input`, the SAME code as the wire. FGX has no
software `ip_input`: the W5100 does IP/TCP/UDP in hardware, so there is nothing to
loop into. A bespoke socket-layer loopback shim (ring buffers + a pairing table)
was designed and **rejected** as a throwaway divergence -- it is neither the
W5100 path nor BSD netinet, and would be deleted the day the real stack lands.
For `lo0` to appear organically, you need the software input path == Track B.
Decision (the maintainer, 2026-07-20): do NOT build the shim; bring loopback up organically
in Track B (loopback-first is already the roadmap's entry point precisely because
`if_loop` needs no hardware driver). Working UDP loopback = Track B P2/P3;
working TCP loopback = P4 (`tcp_input`).

**Multi-NIC: the table holds 4, the driver drives 1.** `IF_MAX = 4`
(`include/ifnet.s`), so the ifnet table has room. But the W5100 driver is
**self-modifying code bound to one detected slot** (`_u2Slot`): `_w5PatchTbl`
(`w5100_patchsites.s`, generated) bakes the single card's base address
`$E0C084 + (_u2Slot<<4) + regoff` into **231 register-access sites**
(0 MR / 49 ARH / 49 ARL / 133 DAT). With two U2 cards today: slotscan finds the
first, binds to it, the second is silently ignored (no crash -- just invisible
and undriven). Real multi-NIC therefore requires reworking those 231 sites from
one-slot self-mod to **per-card indexed base addressing** (compute the base from
a per-descriptor slot, no self-mod), plus multi-registration in the ifnet table
and a slotscan that registers ALL detected W5100s, not the first. That is a
substantial driver change, staged below.

## 3. The W5100 coexistence-vs-replacement decision

Adopting the software stack forces a fork the earlier docs mention but do not
decide:
- **Coexist (chosen entry).** Software stack serves `127.0.0.0/8` and local
  interface IPs; the W5100 offload keeps the wire; the socket layer dispatches by
  destination. Keeps hardware-offload performance; cost is two stacks and a
  dispatch seam. This is how Track B P1-P4 come up WITHOUT touching the wire path.
- **Replace (deferred).** Demote the W5100 to a raw-Ethernet link (`MACRAW`
  `if_wiz`) and run 2.11BSD `tcp_input` on the 2.8 MHz 65816 for all traffic.
  Faithful and uniform (one stack, `lo0` and the wire are just ifnets under one
  `ip_input`), but software TCP on the 65816 is slow, and it throws away the
  chip's whole value. Revisit only at P5/P6 once a MACRAW `ifnet` exists and the
  performance is measured -- not a prerequisite for loopback.

Decision: **start coexist.** Software stack initially serves only loopback/local;
W5100 unchanged for the wire.

## 4. Staged roadmap additions (append to ROADMAP.md "Networking")

- **[done 2026-07-20]** `ifconfig` real flags + W5100 capability line + `-a`
  (tool-only). Superseded later by the SIOC* model (below).
- **[Track B, when it starts]** loopback-first P1-P4 -> organic `lo0` (UDP first,
  then TCP). See `2026-07-19-networking-roadmap-scope.md` P1-P6. The loopback +
  multi-NIC needs surfaced here (2026-07-20) are the "driving need" the Track B
  deferral was waiting on.
- **[staged] SIOCGIFCONF / SIOCGIFFLAGS socket-ioctl model.** Evolve the kernel
  ifconfig ABI from the bespoke `SYS_IFCONFIG` (32-byte ifreq, `IFC_GETN/GET/SET`)
  to the BSD `SIOC*` ioctls over a socket, so a real 2.11BSD `ifconfig` can be
  ported and the tool-side capability rendering retires in favor of a kernel
  `SIOCGIFCAP`-style report. Fits Track B P1's `ifnet` seam + P6 routing.
- **[staged] multi-NIC.** W5100 driver per-card base rework (retarget the 231
  `_w5PatchTbl` self-mod sites to indexed addressing), ifnet multi-registration,
  slotscan-all. Independent of the software stack but shares the P1 `ifnet` seam.

## Lift sources (verified in examples/2.11BSD/usr/sys/)

`net/if_loop.c`, `net/if.c`, `net/if_sl.c`, `netinet/{in,ip_input,tcp_input,
udp_usrreq}.c`, `h/{mbuf,protosw}.h`. fcc-capability audit of `netinet/` is the
load-bearing first step (bitfields confirmed in `ip.h`/`tcp.h`) -- run before any
Track B commitment.
