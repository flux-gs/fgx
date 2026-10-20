# DNS resolver — scoping (2026-07-20)

Owner: flux · Status: **BUILT through P3, 2026-07-20** · Repo: `~/projects/Retro/Apple/fgx`

## Outcome (2026-07-20)

Built as scoped — slim resolver in `lib/libc_c/libc_c.c` (`gethostbyname` +
`gethostbyaddr` + static helpers), byte-offset DNS packets, lifted
`include/arpa/nameser.h` (macros only), default `disk_src/etc/hosts`, `h_errno`.
All three phases pass closed-loop (headless MAME, `nstest` probe):

- **P1** `/etc/hosts`: `nstest localhost` → `127.0.0.1` (offline).
- **P2** DNS A: `nstest example.com` → live IP over UDP (nameserver from
  dhclient-written `/etc/resolv.conf`).
- **P3** reverse PTR: `nstest -r 1.1.1.1` → `one.one.one.one`.
- **End-to-end**: `telnet example.com 80` → "Connected to example.com."

**Two bugs found + fixed along the way:**
1. **fcc call-clean miss (ir.c)** — the loop-register-promotion call-clean check
   (`ir_text_has_unsafe_call`) recognized `JSR/JSL/FARCALL` but NOT the pile
   near-call (`PHK/PEA tgt-1/PHK/RTL`). So a libc loop that pile-calls another
   libc fn (`while (fgets(...,f))`) was wrongly deemed call-clean; the live `f`
   got promoted into `_fcc_img2/3` — which `fgets` itself uses — and was
   clobbered across the call → the resolver hung. Fix: `emit_pile_call` tags its
   RTL transfer `; PILECALL` and the call-clean check treats that tag as a call
   (a bare `RTL` check false-fired on early-return epilogues — 146 goldens; the
   tag is precise and only appears in `--pile` output, so userland is untouched).
   (Userland dodged the bug: there fgets is a FARCALL, already detected.)
2. **Large frames on the bank-0 stack** — `_dns_resolve`'s `query[300]`+`resp[512]`
   and `gethostbyaddr`'s `namebuf[256]` overran the small hardware stack (silent,
   no guard trip). Moved to `static` (the resolver is synchronous / non-reentrant
   like BSD `gethostby*`).

Original scoping follows.

Owner: flux · Status: scoped · Repo: `~/projects/Retro/Apple/fgx`

## Goal

Make `gethostbyname("host.example.com")` actually resolve, so telnet (and future
net clients: ftp, ping-by-name, ntp-by-name) work with hostnames, not just
dotted-quad IPs. Today `gethostbyname` is an honest NULL stub (added with the
telnet port); callers fall back to `inet_addr`, i.e. IP-only.

## What already exists (this is mostly plumbing, not new stack)

- **UDP socket surface, proven**: `socket(AF_INET, SOCK_DGRAM, 0)`, `bind`,
  `sendto`, `recvfrom` — all in libc over `SYS_SOCKET/BIND/SENDTO/RECVFROM`
  (71/72/73/74). dhclient is a **working UDP-client** using exactly this loop
  (bind local port → sendto server → poll recvfrom), so DNS is the same shape.
- **The nameserver is already known**: dhclient learns DNS option 6 and writes
  `/etc/resolv.conf` (`nameserver 192.168.2.1`). The file + format exist today.
- **`gethostbyname` entry point** lives in `lib/libc_c/libc_c.c` (the NULL stub),
  with `struct hostent` in `include/netdb.h`. `getservbyname` right beside it is
  the template for "fill a static record, return its pointer."
- **DNS constants** (`T_A=1`, `C_IN=1`, `QUERY`, `PACKETSZ=512`, header offsets)
  are liftable verbatim from `examples/2.11BSD/usr/include/arpa/nameser.h` — pure
  `#define`s, same as `arpa/telnet.h` was.

## Design decision: SLIM purpose-built resolver, NOT the full 2.11BSD res_* port

The 2.11BSD BIND resolver is vendored (`usr/lib/libc/net/res_{init,mkquery,query,
send,comp}.c`, ~1200 lines across 6 files) but porting it verbatim is the wrong
call here:

- **It hits an fcc gap.** `arpa/nameser.h`'s `HEADER` struct is **bitfields**
  (`u_char qr:1; opcode:4; …`), which fcc does not support. `res_mkquery`/
  `res_send` build and read the header through that struct. A slim resolver that
  lays out the 12-byte header by **byte offset** avoids bitfields entirely — no
  new fcc work needed.
- **It's overkill.** res_* carries `_res` global state, multiple nameservers,
  search-domain lists, sortlists, all RR types, DNS name **compression on the
  query side** (`dn_comp`), and TCP fallback. FGX needs: one nameserver, one
  question (A/IN), parse the first A answer.
- **It matches the house style.** The FGX net stack is already a "slim,
  BSD-shaped, from-scratch" IPv4 stack — not a 2.11BSD kernel-net lift. The
  resolver follows the same principle: BSD-informed, FGX-slim. Constants are
  lifted; the machinery is compact and byte-explicit.

Net: **write ~200 lines of compact resolver in libc**, not ~1200 lines of res_*.
(res_comp.c's `dn_expand` is the one piece worth reading closely — response names
use compression pointers and must be skipped correctly; see Risks.)

## Components & phasing

**Phase 1 — `/etc/hosts` lookup (offline, no network).** ~40 lines.
- `gethostbyname` first opens `/etc/hosts`, scans for a name/alias match, and on
  hit fills the static hostent from the dotted-quad in that line (via the
  existing `inet_addr`).
- Ship a default `/etc/hosts` (`127.0.0.1 localhost`) staged from `disk_src/etc/`.
- Testable with **zero network** (offline closed-loop): `gethostbyname("localhost")`
  → 127.0.0.1. This de-risks the hostent/return plumbing before any UDP.

**Phase 2 — DNS A-query over UDP.** ~180 lines. The real resolver, as the
`/etc/hosts`-miss fallback.
- `res_init`-lite: `fopen("/etc/resolv.conf")`, read the first `nameserver` line
  → 4-byte server IP (skip if absent → return NULL, IP-only as today).
- Build the query by byte offset into a 512-byte buffer: 12-byte header
  (random-ish id, flags `0x0100` = RD, qdcount 1, others 0) + QNAME (length-
  prefixed labels: `www.x.com` → `03 w w w 01 x 03 c o m 00`) + QTYPE `A` +
  QCLASS `IN`.
- `socket(SOCK_DGRAM)`; `sendto(server:53)`; poll `recvfrom` with a timeout
  (~2–5 s) and 2–3 retries — the **exact dhclient poll loop**.
- Parse the response: check id + RCODE==0 + ancount>0; skip the question; walk
  answer RRs, skipping each name (compression-pointer aware), taking the first
  `type==A, class==IN` rdata (4 bytes) into the static hostent's `h_addr_list[0]`.
- Wire into `gethostbyname` after the `/etc/hosts` miss.

**Phase 3 — follow-ups (optional, not required for telnet).**
- `gethostbyaddr` (reverse PTR) — most tools don't need it.
- CNAME chasing (usually unnecessary: authoritative replies include the A in the
  same answer section); TC-bit (truncated) → fail rather than TCP-fallback.
- Multiple nameservers / search domains — skip unless a real need appears.

## Data shapes

- `struct hostent` (netdb.h, already there): fill `h_name`, `h_addrtype=AF_INET`,
  `h_length=4`, `h_addr_list[0]` → a static 4-byte address, `[1]=0`. Single static
  record like `getservbyname` — **non-reentrant, matches BSD `gethostbyname`**.
  (Watch the `char*[]` init gap: `h_addr_list` uses `(char**)&static_ptr_arr`,
  same idiom used for getservbyname's aliases.)
- DNS packet: **byte-offset layout, no bitfield struct.** Lift only the `#define`
  constants from `arpa/nameser.h` into a small `include/arpa/nameser.h` (pure
  macros, like arpa/telnet.h).

## Testing (closed-loop, headless)

- **Phase 1**: offline — `gethostbyname("localhost")` and a staged
  `/etc/hosts` entry → assert the resolved IP. No emulator network needed.
- **Phase 2**: the **telnet-capture method** in reverse — a host-side python DNS
  responder bound on the emulator's gateway (`192.168.2.1:53`) that answers a
  canned A record; FGX resolver queries it; assert the parsed IP. Plus a
  **real-LAN** query against the actual nameserver from resolv.conf.
- End-to-end: `telnet <hostname> <port>` reaches "Trying…"/"Connected" against a
  named host (proves the inet_addr-miss → gethostbyname path).

## Risks / edge cases

- **fcc bitfields** — AVOIDED by byte-offset packet construction (the whole
  reason for slim-over-res_*). No new fcc work anticipated; if some construct
  does trip fcc, fix fcc (toolchain-first), don't hack the resolver.
- **Response name compression** (`0xC0` pointer) — must be handled when *skipping*
  the answer RR name to reach the type/rdata. ~15 lines; read `dn_expand` in
  res_comp.c for the exact rule, but we only need skip-not-expand.
- **UDP timeout/retry** — reuse dhclient's proven poll loop; return NULL on
  timeout (caller already degrades to "unknown host").
- **Stack buffers** — 512-byte query + 512-byte response locals = ~1 KB, well
  under the 4 KB frame limit.
- **resolv.conf absent / no nameserver** — return NULL (today's IP-only
  behavior); no regression.
- **`h_errno`** — set HOST_NOT_FOUND / TRY_AGAIN for correctness, though telnet
  only checks `host == NULL`.

## Effort

~1 focused session. Phase 1 is trivial and independently shippable; Phase 2 is
the bulk (~180 lines + one host-side test responder). Lands in libc
(`lib/libc_c/libc_c.c` beside `gethostbyname`/`getservbyname`) + a lifted
`arpa/nameser.h` + a default `disk_src/etc/hosts`. Toolchain-first: if fcc trips,
fix fcc. Held-local per FGX release discipline until a train.

## Corollaries owed (from the telnet port, same net-follow-up bucket)

- `SYS_SHUTDOWN` real half-close (currently a no-op; close does teardown).
- `getenv` prototype in `stdlib.h` (telnet declares it locally today).
