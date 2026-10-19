# Track B S0 -- fcc prerequisites for the 2.11BSD netinet port

Status: APPROVED by the maintainer 2026-09-27, after apple/fgx!399.  The
maintainer chose the Track B slice for UDP loopback, per-datagram dispatch, the four-part decomposition and this S0 list with a hidden-pointer
struct return (2026-09-27).  Item 3.1 has LANDED (22d3333ae, in apple/fgx!399);
3.2-3.8 remain.

## 1. Why

UDP over 127/8 is built as the first Track B slice: 2.11BSD's own `if_loop.c`
-> `ip_input` -> `udp_input` path, with `in_pcb`, mbufs and socket buffers,
on an `lo0` interface that has nothing to do with the W5100 (the 2026-07-20
decision, reaffirmed; a socket-layer datagram shim was declined again).

The slice is four sub-projects, each with its own design, plan and branch:

| | Sub-project | Delivers |
|---|---|---|
| **S0** | fcc prerequisites (this document) | the compiler reads the netinet sources as 2.11BSD's compiler did |
| S1 | machine seam + packaging | FGX `netparam.h`/`mbuf.h` for 4-byte pointers and a banked mbuf pool, `spl`/netisr on FGX scheduling, a multi-module split with import tables (the VFS precedent) |
| S2 | substrate running | mbufs, domain/protosw, sockbufs, `in_pcb`, `lo0`, `ip_input`/`ip_output`, proven by an in-kernel probe |
| S3 | socket integration + UDP | `udp_usrreq`; every AF_INET UDP descriptor owns a BSD socket and inpcb; datagrams to 127/8 or the card's own address go through `lo0`, the rest through the W5100; `ntpdc 127.0.0.1` talks to ntpd |

S0 comes first because two of its items are SILENT: they compile and give the
wrong layout, and everything after S0 would be built on it.

## 2. The audit this is built from

2026-09-27, in scratch, never in the tree: the twelve files of the loopback
UDP path (`net/{if_loop,if,route}.c`, `netinet/{ip_input,ip_output,udp_usrreq,
in_pcb,in,in_proto}.c`, `sys/{uipc_mbuf,uipc_socket2,uipc_domain}.c`, from
`examples/2.11BSD/usr/sys`) were compiled with `fcc --module-bank` against a
configured-kernel include tree.  All twelve compile once the items below are
worked around; together they are about 55k instructions (140-150 KB, several
module banks) and a 36 KB mbuf pool.

Blockers that are NOT fcc's and are S1's: the PDP-11 machine seam
(`net_mac.h`'s supervisor-space `KScall`/`SKcall`, `spl*` writing the PDP PS,
`setsoftnet`, `label_t`, `UCHAR`, `ui_pad`), the mbuf data model (`struct
mbuf` is 132 bytes against `MSIZE` 128 with 4-byte pointers; `dtom`/`mtod`
cast pointers through `int`), `SUPERVISOR`-gated globals, and tentative
definitions that need common semantics.  Non-conforming 2.11BSD source is
recorded where the port meets it (section 4).

## 3. The items

Every item is fixed in the toolchain, never worked around in a ported file.
Each is its own commit: a fixture that fails first, the fix, goldens green,
and the deciding sentence quoted in the commit.

### 3.1 Char-typed bit-fields are laid out in bytes -- LANDED

Landed on `feat/ntp` as 22d3333ae (merged in apple/fgx!399), because that branch
introduced `<netinet/ip.h>`.  Fixture `tests/M8/char_bitfield_bytes`.  As
built: a byte unit is ACCESSED as the aligned word holding it, shifted, rather
than with byte accesses -- the struct's size is rounded to even, so that word
is always inside it, and emit.c's four bit-field arms stay one 16-bit shape.
After an int unit using more than eight bits a char field starts past those
bits, where ccom would overlap them.  The text below is the design as
approved.

`struct ip { u_char ip_hl:4, ip_v:4; u_char ip_tos; ... }` is 22 bytes under
fcc and 20 on the wire.  fcc gives every bit-field a 16-bit, word-aligned
container (`parse_stmt.c`, the bit-field arm).

K&R A.8.3: a field "has type int, unsigned int, or signed int", and "Adjacent
field members of structures are packed into implementation-dependent storage
units in an implementation-dependent direction."  So a char-typed field is
already an extension fcc accepts, and its unit is fcc's to define.  It is
defined as the compiler 2.11BSD's headers were written against defines it --
`examples/2.11BSD/usr/lib/ccom/c03.c`, `align()`:

- a `char`/`unsigned char` field takes a BYTE unit and no word alignment
  (`if (flen+bitoffs > NBPC) { bitoffs = 0; a += 1; }`); a width over 8 is an
  error ("Field too long");
- an `int`/`unsigned` field takes a WORD unit, word aligned, as today;
- a width of 0 ends the unit.

A char-unit field is read and written with byte accesses: a 16-bit access to a
byte unit at the end of a struct reads past it.

This also fixes `toolchain/include/netinet/ip.h`, the only char-typed
bit-fields in the tree today (added on `feat/ntp`), whose `struct ip` is 22
bytes now.

### 3.2 `##` token pasting

K&R A.12.3: "if the definition token sequence for either kind of macro
contains a ## operator, then just after replacement of the parameters, each ##
is deleted, together with any white space on either side, so as to concatenate
the adjacent tokens and form a new token" -- `cat(var, 123)` yields `var123`.
An argument next to `##` is substituted WITHOUT being macro-expanded ("Unless
the parameter in the replacement sequence is preceded by #, or preceded or
followed by ##, the argument tokens are examined for macro calls"), and `##`
may not begin or end a replacement sequence.  fcc's preprocessor rejects `#`
outside a directive today.

`uipc_domain.c` spells it `x/**/domain`, the Reiser-cpp idiom.  A.12 phase 3
says a comment is replaced by a single space, so that is non-conforming; the
port writes `##` and records the divergence in its provenance row.

### 3.3 A block-scope `extern` keeps its struct type

`{ extern struct domain unixdomain; unixdomain.dom_next = ...; }` answers "no
such field".  A.8.1: "A declaration with extern, used inside a function,
specifies that the storage for the declared objects is defined elsewhere."
The declaration carries its full type; only its storage is elsewhere.

### 3.4 `extern` of an incomplete struct

`extern struct domain inetdomain;` before `struct domain` is complete is
refused ("requires complete type").  A.8.3: incomplete types "may be mentioned
in contexts where their size is not needed, for example in declarations (not
definitions)".  The size is needed at a definition, a `sizeof`, or a use that
reads or copies the object -- and is checked there instead.

### 3.5 Struct assignment into an array element

`ip_srcrt.route[i] = dst;` with `route` an array of `struct in_addr` is
refused ("struct-array element LHS requires '.field'").  A.7.17: in simple
assignment "both operands are structures or unions of the same type" is one
of the permitted cases -- whatever lvalue designates the left one.

### 3.6 Address constants in static initializers

`{ ..., &inetsw[sizeof(inetsw)/sizeof(inetsw[0])] }` and `{ t+4 }` are refused
in an initializer.  A.7.19: in an initializer "the unary & operator may be
applied to external or static objects, and to external and static arrays
subscripted with a constant expression", and "Initializers must evaluate
either to a constant or to the address of a previously declared external or
static object plus or minus a constant".

### 3.7 `&` takes any lvalue

`&(((struct in_ifaddr *)ia)->ia_addr)` (`IA_SIN`) and `&(p->q)->r`
(`sorwakeup`) are refused: fcc's `&` recognises a list of operand shapes.
A.7.4.2: "The operand must be an lvalue referring neither to a bit-field nor
to an object declared as register".  The fix routes `&`'s operand through the
uniform lvalue walker (`build_lvalue_suffixes` / `N_LV_CHAIN`, which the store
and member paths already share), so any lvalue -- a parenthesised or cast
primary followed by member, arrow and subscript suffixes -- has an address,
and the shape list is deleted rather than extended.  The plan reads the
current `&` arms (`parse_expr.c`) before choosing which shapes the walker
already covers.

### 3.8 Struct return by value -- hidden caller pointer

`struct in_addr in_makeaddr()` is refused ("return-by-value struct not
supported (M8)").  A.10.1: "A function may return an arithmetic type, a
structure, a union, a pointer, or void".

2.11BSD's ccom returns a struct by assigning it into a static per-function
block (`funcblk`, `c04.c` `doret()`) and returning its address.  FGX does NOT
copy that: a signal handler, or a preempted task, calling the same function
between the callee's store and the caller's copy gets the other call's value.
Instead the CALLER passes a hidden pointer to a temporary of its own, and the
callee copies the returned value through it (the maintainer, 2026-09-27).  It changes
the calling sequence of struct-returning functions only, and there are none
today, because fcc refuses them.  The hidden pointer is documented in
`docs/` beside fcc's other calling conventions, and a struct-returning
function called with no declaration in scope is refused rather than guessed.

## 4. Non-conforming 2.11BSD source the port meets

Recorded in the ported file's provenance row and its commit, never "fixed" in
fcc:

- `h/signal.h:129` -- `int sc_ovno` with no `;` before `}` (A.8.3's
  struct-declaration ends in `;`).  FGX does not port the PDP `signal.h`.
- `sys/uipc_domain.c:24` -- `x/**/domain` pasting (3.2).

## 5. Testing

Per item: one `toolchain/tests/M*/` fixture with an oracle value, watched
failing before the fix and passing after (the struct_arg_member pattern), the
full `toolchain/tests/run.sh` goldens green, and `run_runtime.py --names` for
the new fixtures on FGX.  3.1 also asserts `sizeof(struct ip) == 20` through
`<netinet/ip.h>`.  The branch ends with `tools/gate.sh` green.  No gate test
is added.

S0 is done when the twelve audit files compile under fcc with none of the
audit's fcc workarounds -- only the S1 machine seam left to supply.  That
re-run is the branch's closing check, in scratch, with the audit's include
tree.

## 6. Order

3.1 first: it is ABI-visible and silent, and its goldens change is the one to
read closely.  Then the small additive items 3.2-3.6, then 3.7 and 3.8, which
need their own reading of `parse_expr.c` before the shape is final.  Each
item ships alone; none depends on another.
