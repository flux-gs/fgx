# Interrupt-driven serial on the Apple IIgs — a how-to

A self-contained guide to writing interrupt-driven SCC code on the Apple IIgs,
distilled from Apple Technical Note IIGS #18, the GNO/ME kernel's `sccf.asm`
driver, the Serial Interrupt Manager (SIM) tool, and counter-examples
(MTERM, SIS) showing what polled and non-serial code look like in
comparison.

This file is intended to be loaded into a fresh Claude Code session as
background. It assumes you have the **gs-mcp** server available and references
files by their MCP `repo_id` + path so they can be fetched with
`get_example_file` / `get_iigs_page`.

> **gs-mcp** is a **[cCc] internal tool** — the IIgs hardware-documentation and
> example-corpus MCP server these notes reference (`get_iigs_page`,
> `get_example_file`, `get_firmware_entry`, …). It isn't publicly distributed;
> it's available to select developers. **Enquire within [cCc] for access.** The
> rest of this guide is self-contained and readable without it; the MCP
> references are for fetching the cited source files.

---

## 1. The landscape: who owns the SCC?

The Apple IIgs has a single Zilog Z8530 SCC with two channels. Channel A is
the printer port, channel B is the modem port. Multiple system components
want to handle interrupts from it:

- **AppleTalk** (if active) owns one of the two channels exclusively.
- **The IIgs serial firmware** (Pascal 1.1 protocol on `$Cn00`) thinks it
  owns the SCC interrupt vector whenever it is in use — and many things
  use it without you realizing (CDAs that print, the Print Manager, the
  Text tool set, GS/OS character drivers for the serial ports).
- **MIDI** drivers can hook the same SCC interrupt path.
- **Your code**, if you want IRQ-driven serial.

Apple TN IIGS #18 ("Do-It-Yourself SCC Access", revised June 1990 by Jim
Luther — get it via `get_iigs_page doc_id=tn_iigs page=18`) lays down
the four rules of polite SCC programming:

1. Before using a port, check that AppleTalk is not using it. Two methods
   depending on ROM version + ProDOS-8 vs GS/OS — TN18 has reference code.
2. **Do not attach to the SCC Interrupt Handler Vector ($0009) directly.**
   The serial firmware grabs it whenever it runs. Attach via the OS:
   `ALLOC_INTERRUPT` (ProDOS 8 / GS/OS ProDOS 16) is the only correct path.
   `BindInt` with VRN $0009 has the same problem and is also forbidden.
3. Never issue a Force Hardware Reset to WR9 (`%11xxxxxx`). The hardware
   reset at system startup is sufficient. Channel reset bits should not
   touch the interrupt-control bits (D5–D0); AppleTalk expects those to
   stay `001010`.
4. Always read RR3 *on channel A* to find which channel has pending
   interrupts. RR3 in channel B returns zeros.

Plus the hints:

- Synchronize with the SCC by doing one throwaway read of RR0 before the
  first real access.
- Disable interrupts (`SEI`) during the two-step "select register / access
  register" sequence to avoid races with the other channel's traffic.
- WR11 bit 7 must be 1 on channel A and 0 on channel B (single oscillator
  shared between channels via the /SYNC pin).

**If you don't want to obey all this, stick to the serial firmware** (the
TN literally says so). The firmware is a polled-poll-style API: status
call, then read or write. Cheap to write, costs CPU at speed. MTERM
(MTERM.MODEM.S) and TelCom/2 (via GNO's `.ttya` driver, see below) are
working references for the polled path.

If you DO need IRQ — for sustained rates above ~9600 baud, for background
RX while the foreground is busy, for any serious terminal program — read
on.

---

## 2. The MCP corpus pointers

The complete worked example of "do this right" lives in
`repo_id=gno` (the GnoConsortium/gno monorepo) under `kern/drivers/`. The
high-value files:

| Path | Lines | Purpose |
|---|---|---|
| `kern/drivers/sccf.asm` | 762 | Unified SCC driver (Rx/Tx/status IRQ handler + init + ring-buffer API) |
| `kern/drivers/sccf.mac` | 250 | ORCA/M macros (`subroutine`, `return`, `long`, `short`, `ph2`, `ph4`, `_ReadBParam`) |
| `kern/drivers/msccf.asm` | 11 | Modem-port build stub: `copy sccf.asm` with `md.equates` |
| `kern/drivers/psccf.asm` | 11 | Printer-port build stub: `copy sccf.asm` with `pr.equates` |
| `kern/drivers/md.equates` | 12 | Modem-port equates ($E0C038/$E0C03A, Ch B masks) |
| `kern/drivers/pr.equates` | 12 | Printer-port equates ($E0C039/$E0C03B, Ch A masks) |
| `kern/gno/inc/tty.inc` | — | `SerialData` direct-page layout (ibuf_*, obuf_*, fcon_*, etc.) |
| `sys/sim/sim.doc` | 105 | SIM tool API + install/remove recipe |
| `sys/sim/simlib.asm` | 99 | C-callable SIM glue (InstallIntVect, RemoveIntVect, SIMVersion) |
| `sys/sim/sim.h` | — | C header for SIM calls |

A redundant slimmer copy of the same kernel lives at `repo_id=gno_kern`
(ksherlock/gno-kern) under `drivers/sccf.asm` etc. Either is fine; prefer
`gno` for browsing because it includes the userland (`usr.sbin/getty/`,
`bin/stty/`) that exercises the driver.

Counter-examples in the corpus:

- `repo_id=itty_bitty_vtty` — boots without GS/OS, drives the SCC directly.
  Another IRQ-driven SCC reference, smaller in scope; useful comparison.
- `repo_id=tc2` (TelCom/2) — uses GNO's `.ttya` device through `pts.c` /
  `port.c`. The IRQ work is inside GNO; tc2 is a userland consumer.
- `repo_id=marlene` — Marinetti telnet client; doesn't touch serial at all
  (network only).
- MTERM source (not in corpus, but referenced for contrast) — polled
  Pascal-firmware client.

---

## 3. Architecture: one driver, two ports

The clever bit of `kern/drivers/` is that `sccf.asm` is **port-agnostic
source compiled twice** with different equates:

```
                                  ┌──── md.equates  (modem,  Ch B, $E0C038/$E0C03A)
msccf.asm ─── copy sccf.asm ──────┤
                                  ├──── sccf.mac (macros)
                                  └──── ../gno/inc/tty.inc + equates

psccf.asm ─── copy sccf.asm ──────┐
                                  └──── pr.equates  (printer, Ch A, $E0C039/$E0C03B)
```

`msccf.asm` and `psccf.asm` are 11-line stubs:

```asm
* msccf.asm — modem variant
    mcopy sccf.mac
    copy  equates
    copy  ../gno/inc/tty.inc
    copy  md.equates
    copy  sccf.asm
```

The equates select everything that differs between channels:

| Equate | `md.equates` (modem, Ch B) | `pr.equates` (printer, Ch A) |
|---|---|---|
| `CtlPanBaud` | `$12` (control panel item) | `$6` |
| `PortControl` | `$E0C038` (Ch B WR/RR cmd) | `$E0C039` (Ch A cmd) |
| `PortData` | `$E0C03A` (Ch B data) | `$E0C03B` (Ch A data) |
| `PortNum` | `2` (SIM modem port) | `1` (SIM printer port) |
| `Channel_Rx` | `%00000100` (Ch B Rx bit in RR3) | `%00100000` (Ch A Rx bit) |
| `Channel_Tx` | `%00000010` (Ch B Tx bit) | `%00010000` (Ch A Tx bit) |
| `Reg11` | `%01010000` (no xtal — Ch B is slaved) | `%11010000` (xtal on — Ch A drives) |
| `PortReset` | `%01000000` (channel B reset in WR9) | `%10000000` (channel A reset) |

This is the right factoring. Copy it. Do not write two parallel drivers.

**Important addressing note:** all SCC access is via `$E0Cnnn`, not bare
`$C038`. That's the bank-$E0 shadow. In native mode with data bank
not guaranteed to be 0, this is the only safe way to address I/O. The
driver uses `sta >PortControl` (long absolute) so the assembled code
includes the bank byte.

---

## 4. SIM — the interrupt arbitration tool

GNO's solution to TN18 Rule #2 is a system extension called **SIM** (Serial
Interrupt Manager), shipped as a PIF (Permanent INIT File) in
`*:System:System.Setup/`. SIM:

1. Replaces the first ~quarter of the IIgs main interrupt handler.
2. After AppleTalk and MIDI have been checked (so neither loses data),
   SIM checks RR3 in Channel A for pending non-MIDI async serial interrupts.
3. Dispatches to handler routines registered via `InstallIntVect(port, addr)`.

From `sys/sim/sim.doc`:

> SIM always has priority over the standard firmware handlers, and if the
> firmware is used to initialize a port which is already being handled by
> a SIM handler a crash may result. […] Data rates of up to 57600 baud
> are possible with no resulting data loss.

The SIM API is reached via `_SendRequest` (System 6.x IPC) using the name
`'SerialIntrMgr~Entry~'`. `simlib.asm` wraps that for you:

```asm
InstallIntVect    START
    using   SIMLibData
result   equ   0
    subroutine (4:address,2:port),2
    lda     port
    sta     SIMport
    lda     address
    sta     SIMaddress
    lda     address+2
    sta     SIMaddress+2
    lda     #SIMInstallHand
    jsr     DoSIMCall
    lda     |Gerror
    sta     result
    return 2:result
    END
```

C-side header from `sys/sim/sim.h`:

```c
extern int INSTALLINTVECT(int port, unsigned long address);
extern int REMOVEINTVECT (int port, unsigned long address);
#define InstallIntVect INSTALLINTVECT
```

Errors that matter:

| Code | Constant | Meaning |
|---|---|---|
| $0001 | `SIMAlreadyInst` | Another driver/app already owns this port |
| $0003 | `SIMATalkActive` | AppleTalk is using this port — tell the user, don't touch |
| $0005 | `SIMInvalidPort` | Port number was not 1 or 2 |
| $0006 | `SIMNotFound` | The SIM tool itself isn't loaded |

**Your driver should always check for these and degrade gracefully.** In
GNO, `StartSerial` calls `jsr InstallInt`, stores the returned error,
and if non-zero skips the `InitSCC2` call that arms the SCC interrupt
master enable — i.e. the SCC never starts generating interrupts if
nobody's listening.

---

## 5. The canonical install / uninstall sequence

From `sys/sim/sim.doc` and confirmed by `sccf.asm:584-624` (`StartSerial`)
and `sccf.asm:633-642` (`EndSerial`):

**Install** (must be done in this exact order):

1. Initialize the SCC registers — *but leave interrupts disabled*. In
   sccf.asm this is `InitSCC`, which walks the `async_data` table and
   programs WR4, WR2, WR3 (Rx off), WR5 (Tx off), WR9 (master IE off),
   WR10, WR11, WR12/13 (baud), WR14 (BRG on), WR3 again (Rx on), WR5
   again (Tx on), WR15 (CTS-change interrupts armed but nothing else).
2. Call `InstallIntVect(port, handler)` via SIM.
3. Enable SCC interrupts — `InitSCC2` writes WR1 = `%00010010` (Rx int on
   all chars + Tx int enable) and WR9 = `%1010` (master enable, status
   low).

**Uninstall** (also strict order):

1. Drain pending output (`FlushOutQ` spins on `obuf_mark` until zero).
2. Shut down SCC: clear WR9 master enable, clear WR1 source enables, do
   the prescribed "clear pending Tx overrun" (WR0 ← `%11010000`) and
   "clear pending Tx interrupt" (WR0 ← `%00101000`) sequences. This is
   `DeInitSCC`.
3. Call `RemoveIntVect(port, handler)`.

`StartSerial` in `sccf.asm`:

```asm
StartSerial    START
    using   SerialData
    subroutine (4:dp,4:inb,4:outb),2
    ...                            ; zero ring-buffer state, set sizes=4096
    jsl     InitSCC                ; step 1
    jsr     InstallInt             ; step 2 — calls INSTALLINTVECT
    sta     |temp
    cmp     #0
    bne     handlerErr             ; if SIM rejected, don't arm interrupts
    jsr     InitSCC2               ; step 3
handlerErr  pld
    lda     temp
    sta     result
    return 2:result
    END
```

---

## 6. The interrupt handler — `IntVect` in sccf.asm

This is the file's center of gravity. SIM has already read RR3 from
channel A and *passes the bit field in A* when it `jsl`s your handler.
Your code is purely a dispatch decoder.

### Entry conventions (set by SIM)

- Entered with the SCC's RR3 contents in A.
- `m` flag and `x` flag are 8-bit (this is a SIM contract — confirm by
  the `longa off / longi off / php / long x` sequence in `IntVect`).
- Data bank, direct page, and stack are whatever the interrupted code
  had. Don't trust them.
- Return with `clc / rtl` if you handled it, `sec / rtl` if it wasn't
  yours.

### The dispatch skeleton

```asm
IntVect    START
    using   SerialData
    longa   off
    longi   off
    php
    long    x                          ; widen X/Y to 16 bits
    bit     #Channel_Rx                ; Rx pending on our channel?
    beq     t_Tx_Int
    ...                                ; Rx path
t_Tx_Int   anop
    bit     #Channel_Tx                ; Tx empty on our channel?
    beq     statusInt
    ...                                ; Tx path
statusInt  anop
    ...                                ; External/Status (CTS, DCD)
gohome     anop
    plp
    clc
    rtl
notOurIntr anop                        ; (kept around but no path reaches it
    plp                                ;  — SIM dispatched on RR3 so by the
    sec                                ;  time you're here it WAS yours)
    rtl
    END
```

### Direct-page swap on entry

Each path begins:

```asm
    phb
    phk
    plb                                ; data bank = code bank
    phd
    long    m
    lda     SerialDP                   ; per-port driver DP base
    tcd
    short   m
```

This pattern (save bank, save DP, load *our* DP, switch to 16-bit A only
long enough to do the `tcd`, then back to 8) is repeated in the Rx, Tx,
and status paths. It's what lets the ring-buffer pointers
(`ibuf_head`, `obuf_tail`, `tx_in_progress`, …) live in fast direct-page
addresses. Restore on exit: `pld / plb`.

### Rx path

```asm
lp1   ldy   <ibuf_head
      lda   #1
      sta   >PortControl               ; WR0: select RR1
      lda   >PortControl               ; read RR1 (Rx error bits)
      pha                              ; save for post-decode

      lda   >PortData                  ; read the byte
      sta   <lastChar                  ; remember last char (post-processing)
      sta   [in_buf],y                 ; store in ring
      iny
      cpy   <ibuf_size
      bne   noWrap1
      ldy   #0
noWrap1  sty  <ibuf_head
      ldx   <ibuf_mark
      inx
      stx   <ibuf_mark
      cpx   #3072                      ; high-water? (buf is 4096)
      bcc   noFCON
      jsr   turn_flow_off              ; assert RTS=0 or send XOFF

noFCON  jsr  check_stuff               ; ^C/^Z/select wakeup/SIGHUP

      pla                              ; recover saved RR1
      and   #$60                       ; framing or overrun?
      beq   weepers
      lda   #0 / sta >PortControl      ; WR0: Error Reset
      lda   #$30 / sta >PortControl

weepers lda #0 / sta >PortControl      ; WR0: Reset Highest IUS
        lda #$38 / sta >PortControl

      lda   >PortControl               ; re-read RR0
      bit   #1                         ; Rx Char Available still set?
      bne   lp1                        ; yes → another byte arrived during ISR
      pld / plb
gohome  plp / clc / rtl
```

Three things make this exemplary:

- **High-water flow control inside the ISR.** Don't wait for userland to
  notice the buffer is full and react — when `ibuf_mark` hits 3072 (75%
  of 4096), assert RTS deasserted (WR5 manipulation) or send a software
  XOFF *immediately*. The matching `turn_flow_on` is called from
  `ReadBuffer` when `obuf_mark` drops below 1024.
- **Error Reset, then Reset Highest IUS, in that order.** Both are
  written to WR0. If you don't issue Reset Highest IUS (`$38` to WR0)
  the SCC won't re-assert /INT for the next priority. Many homebrew SCC
  drivers forget this; that's why their drivers "stop after one byte
  under load."
- **Re-check RR0 before exiting.** Bytes can arrive between when you
  read the previous one and when you'd return. Looping back to `lp1`
  closes that race.

### Tx path

```asm
t_Tx_Int   anop
    bit     #Channel_Tx
    beq     statusInt
    lda     <obuf_fcon                 ; flow-control hold?
    bne     turnOffTxInt               ; receiver said XOFF, stop sending

    ; DP swap (same idiom)
doTxChar  ldy   <obuf_mark
          beq   turnOffTxInt           ; ring empty → disarm Tx interrupt
          tya
          ldy   <obuf_tail
          lda   [out_buf],y
          sta   >PortData              ; write the byte
          iny
          cpy   <obuf_size
          bne   noWrap
          ldy   #0
noWrap    sty   <obuf_tail
          ldx   <obuf_mark
          dex
          stx   <obuf_mark

          lda   #0 / sta >PortControl  ; WR0: Reset Highest IUS
          lda   #$38 / sta >PortControl

          plb / pld
          bra   gohome

turnOffTxInt  lda  #%00101000          ; WR0: Reset Tx Pending
              sta  >PortControl
              lda  #0
              sta  <tx_in_progress     ; we're idle
              plb / pld
              bra  gohome
```

The `tx_in_progress` latch is the standard "edge-trigger Tx empty"
idiom. The SCC's Tx-empty interrupt re-asserts as long as Tx-empty is
true and the interrupt is enabled. If you don't disarm it when your
ring drains, you spin in the ISR forever. Conversely, when the ring
has been empty and userland queues a fresh byte, `WriteBuffer` writes
the first byte to PortData directly (priming the pump) and sets
`tx_in_progress = 1`. The subsequent Tx-empty interrupt finds bytes in
the ring and drains them.

### Status (External/Status) path

```asm
statusInt  anop
    ; DP swap idiom
    lda     >PortControl                ; read RR0
    bit     #%00100000                  ; CTS line?
    bne     turniton                    ; CTS asserted → can send
    lda     #1
    sta     <obuf_fcon                  ; CTS deasserted → hold output
reset
    lda     #0  / sta >PortControl      ; Reset Highest IUS
    lda     #$38 / sta >PortControl
    plb / pld
    jmp     gohome
turniton  lda  <obuf_fcon
          beq  reset                    ; already running
          stz  <obuf_fcon                ; release flow hold
          jmp  doTxChar                  ; kick Tx going again
```

Hardware flow control via CTS is implemented in this path. The driver
arms WR15 = `%00100000` (interrupt on CTS status change) but no other
External/Status sources — so this entry point only fires when CTS toggles.

---

## 7. The init register-write table

`InitSCC` (`sccf.asm:328-407`) walks `async_data`, a table of
{register, value} pairs terminated by `$FF`. This is the **cheat sheet
of what to write and in what order**, with helpful inline comments:

```asm
async_data
    dc i1'$04,$44'        X16 clock mode, 1 stop bit            ; WR4
    dc i1'$02,$00'        no interrupt vector                   ; WR2
    dc i1'$03,%11100000'  Rx 8 bits, Rx OFF, auto enables off   ; WR3
    dc i1'$05,$62'        DTR=0, Tx 8 bits, Tx OFF, RTS=1       ; WR5
    dc i1'$09,%0010'      no reset, all ints OFF                ; WR9
    dc i1'$0A,$00'        NRZ data encoding                     ; WR10
    dc i1'$0B,Reg11'      xtal source per channel               ; WR11
initBaudLo  ENTRY
    dc i1'$0C,$04'        BRG time constant low                 ; WR12
initBaudHi  ENTRY
    dc i1'$0D,$00'        BRG time constant high                ; WR13
    dc i1'$0E,$80'        source=BRG, BRG clk=xtal, BRG OFF     ; WR14
    dc i1'$0E,$01'        BRG ON, BRG clk=xtal                  ; WR14
    dc i1'$03,%11100001'  Rx 8 bits, Rx ON                      ; WR3
    dc i1'$05,DTR'        DTR=0, Tx 8 bits, Tx ON, RTS=1        ; WR5
    dc i1'$0F,%00101000'  interrupt on CTS status change ONLY   ; WR15
    dc i1'$FF'                                                  ; sentinel
```

Note how this maps onto TN18's prescribed init sequence:

| TN18 step | sccf.asm location | Notes |
|---|---|---|
| Read RR0 to sync | `InitSCC` first 3 lines (`lda PortControl`) | done before table walk |
| WR4: clock/stop bits | first table entry | `$44` = X16, 1 stop |
| WR3: Rx config (Rx off) | table entry 3 | Rx armed in step 11 |
| WR5: Tx config (Tx off) | table entry 4 | Tx armed in step 12 |
| WR11: clock source | table entry 7 | `Reg11` differs per channel |
| WR12/13: baud rate | runtime-patchable (`initBaudLo+1`, `initBaudHi+1`) | `ComInit` writes these from the termios `sg_ispeed`/baud table |
| WR14: BRG enable | two entries (off then on) | required by SCC manual |
| WR3: Rx on | table entry 11 | `%11100001` sets D0 |
| WR5: Tx on | table entry 12 | `DTR` literal pulls D1+D3 |
| WR15: ext/status | table entry 13 | only CTS-change armed for now |
| WR1: source enables | deferred to `InitSCC2` | done after SIM install |
| WR9: master enable | deferred to `InitSCC2` | last thing armed |

**Baud rate patching:** `initBaudLo` and `initBaudHi` are ENTRY-tagged
inside the table so the `SetWord` / `ComInit` routines can poke the new
baud rate constant into the table at runtime. The BRG time constant is
`(crystal / (2 * baud * clock_mode)) - 2` — sccf.asm uses a precomputed
lookup table (`baudTbl`) indexed by the termios speed code.

For a runtime baud change without re-running the whole init:

```asm
SetWord    START
    php / sei                          ; critical section
    ldy   #sg_ispeed
    lda   [dTermioPtr],y
    and   #$0F
    asl a / tax
    lda   >baudTbl,x
    tax
    short m
    lda   >PortControl
    lda   #$0C / sta >PortControl      ; select WR12
    txa     / sta >PortControl         ; write low byte
    lda   #$0D / sta >PortControl      ; select WR13
    txa / xba / sta >PortControl       ; write high byte
    long m
    plp / rts
    END
```

Two notes: the throwaway `lda >PortControl` at the top is the TN18 "sync"
read. The `sei`-bracketing is mandatory because each WR write is a
**two-step operation** (select register number, then write data) and the
other channel's interrupts could steal the `PortControl` register
between the two writes.

---

## 8. Critical sections in the user-facing API

`ReadBuffer` (`sccf.asm:241-275`) is called from kernel code that wants to
pull bytes out of the ring. It must be atomic against the Rx ISR:

```asm
ReadBuffer    START
    using   SerialData
    php
    short   m
    sei                                ; mask IRQ
    ldy     <ibuf_tail
    cpy     <ibuf_head
    beq     nodata                     ; ring empty
    lda     [in_buf],y                 ; pull one byte
    iny
    cpy     <ibuf_size
    bcc     noWrap
    ldy     #0
noWrap  sty   <ibuf_tail
    long    m
    ldx     <ibuf_mark
    dex
    stx     <ibuf_mark
    pha
    lda     <fcon_status
    bne     fc_is_off
    cpx     #1024                      ; low water
    bcs     fc_is_off
    short   m
    jsr     turn_flow_on               ; release RTS / send XON
    long    m
fc_is_off  pla
    and     #$FF
    plp                                ; restore I-flag
    sec                                ; data returned
    rts
nodata  long  m
    plp
    clc                                ; ring was empty
    rts
    END
```

`WriteBuffer` (`sccf.asm:280-326`) has a wrinkle:

```asm
WriteBuffer    START
    tay                                ; save char in Y
tryagain  php
          short m
          sei
          ldx   <obuf_mark
          beq   bufEmpty               ; ring was empty → prime the pump
          cpx   #BUF_SIZE-1
          beq   noRoom                 ; ring full → can't queue
addToBuffer  tya
             ldy  <obuf_head
             sta  [out_buf],y
             ...
             bra wasData
bufEmpty  lda  <tx_in_progress
          bne  addToBuffer             ; ISR already running, just queue
          tya
          sta  >PortData               ; write the kick-off byte directly
          lda  #1
          sta  <tx_in_progress
wasData   plp / sec / rts
noRoom    long m
          plp
          bra  tryagain                ; open a window for ISR to drain
```

The `noRoom → plp → bra tryagain` loop is subtle: `plp` momentarily
re-enables IRQs (because we entered with `php`/`sei`), letting the Tx
ISR drain a byte, then we loop back to `tryagain` which `php`/`sei` again
and re-checks `obuf_mark`. The driver does *not* sleep the caller; it
busy-waits with the IRQ window open. (Real GNO contexts that need to
sleep — like blocking reads when the ring is empty — handle that at a
higher layer; `check_stuff` flips the process state from `pBlocked` to
`pReady` when bytes arrive.)

---

## 9. The `SerialData` direct page

The driver's per-port state is a direct-page block defined in
`kern/gno/inc/tty.inc`. The fields used in sccf.asm:

| Field | Size | Role |
|---|---|---|
| `in_buf` | 4 | Long pointer to 4096-byte Rx ring |
| `out_buf` | 4 | Long pointer to 4096-byte Tx ring |
| `ibuf_head` / `ibuf_tail` / `ibuf_mark` / `ibuf_size` | 2 each | Rx ring producer/consumer/count/capacity |
| `obuf_head` / `obuf_tail` / `obuf_mark` / `obuf_size` | 2 each | Tx ring |
| `obuf_fcon` | 2 | Tx hold flag (set by CTS-low ISR / XOFF) |
| `fcon_status` | 2 | "Are we currently asserting receive-side flow"? |
| `fcon_type` | 2 | `FCON_RTS` or `FCON_XON` |
| `reg5Status` | 2 | Last WR5 written (for read-modify-write of RTS) |
| `tx_in_progress` | 2 | "Is the Tx ISR currently draining?" |
| `lastChar` | 2 | Last byte received (for post-decode like ^C / ^Z detection) |
| `lastInt` | 2 | (commented out) historical; kept for context |

The kernel maintains one such block per open tty (one for `.ttya`, one
for `.ttyb` if both are open). The Rx ISR enters with the global
`SerialDP` pointing at the right block — that's set up by `StartSerial`
when the kernel opens the device.

---

## 10. Known stubs and gotchas in this revision

If you're using sccf.asm as a template, fix these or know about them:

- **`BRKON` / `BRKOFF` are empty.** Source comment: `* we really need to
  do something here :)`. Break-signal generation/detect isn't wired.
- **`priorityWrite` is `brk $10 / rts`** — a debug trap. XON/XOFF flow
  control is therefore not functional in this snapshot (the ISR will
  call into BRK when it tries to send a software XOFF). Hardware
  RTS/CTS flow is the only working path. The XON/XOFF code paths in
  `turn_flow_off` / `turn_flow_on` exist but require a working
  priority-write to be useful.
- **Flow-control hi/lo watermarks are hard-coded** (3072 / 1024). If you
  change `ibuf_size` you must update both. There's no per-port
  configurability.
- **`WriteByteOld`** (the `flowCheck`/`txfull` polled-spin routine at
  `sccf.asm:298-326`) is leftover code, not part of the IRQ path.
  Ignore it for understanding the design.
- **No support for parity / stop-bit / word-length changes** —
  `SetWord` comment says `* we only support 8N1 right now!` and only
  reprograms the baud rate. Bit-rate-only.
- **Buffer-full handling drops data silently.** The Rx ISR doesn't
  check for `ibuf_head == ibuf_tail - 1` (ring full) before storing;
  it just bumps `ibuf_mark` past the buffer size. With working flow
  control upstream this shouldn't happen, but if you're porting to
  no-flow-control transports add an overrun check.

---

## 11. Direct comparisons

If you want to read counter-examples in the same MCP corpus, here's
what each one shows:

### Polled via IIgs serial firmware — MTERM

MTERM (Matt Ownby, 1991-2000; not committed in the MCP but the user
has a copy locally) drives the IIgs modem port through the Pascal
1.1 firmware protocol. The dispatcher is:

```asm
doit    sta   zslot                    ; A = Pascal command code
        lda   (zslot)                  ; load entry vector from $Cn00+1
        sta   zslot
        lda   dotemp
        ldx   zslot+1
        ldy   n0slot
        clc
do2     jmp   (zslot)                  ; firmware does the work
```

Status call (`$10`) → if carry set, read call (`$0e`); spin until ready,
then write call (`$0f`). Polling loop in MTERM.MODEM.S:308–327. No
hardware access, no IRQ, no SEI/CLI. Throughput-limited by the
firmware overhead per byte.

### "I don't touch serial at all" — SIS

Spectrum Internet Suite is a set of XCMDs that load into the Spectrum
terminal. SIS's `HTTPxcmd.asm` uses Marinetti tool calls (`_TCPIPPoll`,
`_TCPIPReadTCP`, `_TCPIPStatusTCP`). The serial-vs-IRQ question is
answered one layer down: Marinetti's Link Layer Module (Modem.SLIP /
PPP / Uthernet) is responsible for driving the wire. SIS itself is a
pure cooperative-polled consumer of Marinetti.

### IRQ-driven, no GS/OS — itty-bitty-vtty

`repo_id=itty_bitty_vtty` boots from disk, owns the hardware, and drives
the SCC directly without going through SIM (because it has no SIM —
there's no system below it). It hooks the native-mode IRQ vector
manually. Useful comparison if you ever need to do IRQ serial in a
context where SIM isn't available (boot-time tools, ROM-resident code).
Trade-off: it has to do everything SIM does — AppleTalk arbitration,
MIDI coexistence, etc. — itself.

---

## 12. Recipe summary — writing an IRQ serial driver on the IIgs

If you're starting from scratch, here's the playbook in order:

1. **Decide if you really need IRQ.** Below ~9600 baud with a foreground
   that doesn't do much else, polled via the IIgs Pascal firmware is
   fine and one tenth the work. (MTERM, the IIgs serial firmware
   sample code in the Firmware Reference page 88-89.)

2. **Check AppleTalk before you do anything.** TN IIGS #18 reference
   code for both ProDOS 8 and GS/OS. Don't proceed if your target port
   is taken.

3. **Choose your interrupt arbitration path.**
   - Under GS/OS or ProDOS 8: install via **SIM** if you're targeting
     GNO or any environment that has SIM. This is the friendliest path
     — it coexists with AppleTalk, MIDI, and the serial firmware.
   - Otherwise: use `ALLOC_INTERRUPT`. **Never** patch vector $0009
     or the SCC interrupt handler vector directly.

4. **Write your driver port-agnostically.** One `sccf.asm`, two equate
   files (modem / printer), built twice. Don't fork the source.

5. **Hold your per-port state in direct page.** Have an entry routine
   that does `phb / phk / plb / phd / lda PortDP / tcd` and an exit
   routine that does `pld / plb`.

6. **Init order:** SCC registers (Rx/Tx OFF) → install ISR via SIM/AI →
   arm WR1 source enables and WR9 master enable. Never reverse this.

7. **Rx ISR pattern:**
   - select RR1, save error bits
   - read PortData
   - store in ring, advance head with wrap
   - check hi-water; if reached, assert flow-off (RTS down or XOFF)
   - error reset (WR0 ← $30) if framing/overrun
   - Reset Highest IUS (WR0 ← $38) **unconditionally**
   - re-check RR0 bit 0; loop if more data

8. **Tx ISR pattern:**
   - check Tx hold flag; bail if held
   - if ring empty → disarm Tx pending (WR0 ← $28), clear
     `tx_in_progress`, return
   - else: write PortData from ring, advance tail with wrap,
     decrement mark, Reset Highest IUS, return

9. **External/Status ISR pattern:**
   - read RR0
   - test CTS bit → if low, set Tx hold; if high and was held, clear
     hold and kick Tx path
   - Reset Highest IUS

10. **Userland API `Read`/`Write`:**
    - `Read`: php / sei / dequeue / check lo-water → flow-on if needed
      / plp / rts
    - `Write`: php / sei / if ring empty AND `!tx_in_progress` then
      prime PortData + set flag; else enqueue / plp / rts. If ring
      full, plp / bra retry (opens IRQ window for ISR to drain).

11. **Shutdown order:** drain Tx (spin on `obuf_mark`) → master IE off
    (WR9 ← `%0010`) → all source enables off (WR1 ← 0) → read PortData
    to clear pending Rx → WR0 ← `%11010000` (clear Tx overrun + ext
    status) → WR0 ← `%00101000` (clear Tx pending) → `RemoveIntVect`.

---

## 13. References

- **Apple Technical Note IIGS #18 — Do-It-Yourself SCC Access.**
  `get_iigs_page doc_id=tn_iigs page=18`. The canonical Apple
  reference. Read it first.
- **Apple IIgs Hardware Reference, 2nd Edition** — Chapter on the SCC.
- **Zilog Z8530 SCC Technical Manual** (or AMD Z85C30 manual). Vendor
  reference for register-level details; TN18 notes which sections of
  the manual *don't* apply to the IIgs implementation.
- **Apple IIgs Firmware Reference** pp. 88–89 — Pascal 1.1 serial
  protocol commands (`$0c`–`$13`). Useful for understanding what the
  polled path looks like.
- **`sys/sim/sim.doc`** in the gno repo — full SIM API.
- **`kern/drivers/sccf.asm`** in the gno repo — 762-line worked
  reference implementation. Read in order: install hooks → IntVect
  (Rx, Tx, status) → InitSCC + async_data table → InitSCC2 +
  DeInitSCC → StartSerial / EndSerial → ReadBuffer / WriteBuffer →
  turn_flow_off / turn_flow_on → SetWord.
- **GS/OS Reference, Vol 2** — `ALLOC_INTERRUPT` / `BindInt` if you
  are *not* using SIM.

---

## 14. Reading order for a fresh Claude session

If you load this file and want to verify each claim by fetching code:

```
get_iigs_page doc_id=tn_iigs page=18                  # Apple's rules
get_example_file repo_id=gno path=sys/sim/sim.doc     # SIM contract
get_example_file repo_id=gno path=kern/drivers/md.equates
get_example_file repo_id=gno path=kern/drivers/pr.equates
get_example_file repo_id=gno path=kern/drivers/sccf.asm   # the main event
get_example_file repo_id=gno path=sys/sim/simlib.asm
get_example_file repo_id=gno path=kern/gno/inc/tty.inc    # SerialData layout
```

Then for the layer above the driver:

```
get_example_file repo_id=gno path=kern/gno/tty.asm        # line discipline
search_examples query="getty gettytab serial open"        # userland
```

And for the polled / non-IRQ counter-examples:

```
search_examples query="Pascal 1.1 protocol firmware status read" repo_filter=null
get_example_file repo_id=itty_bitty_vtty path=modem.s     # IRQ without SIM
```
