# VT100 console + stty(1) — design & scoping (2026-07-13)

**Direction (the maintainer, 2026-07-13):** make the FGX console a *real vt100 terminal*
so raw-mode Unix apps (vi/elvis, and future curses/readline) get the input they
expect, and add a real **stty(1)** to get/set tty chars. Emerged from two vi
command-mode bugs: DELETE echoes `^?` instead of erasing, and Ctrl-U "acts like
right arrow." Root-caused below.

Related: `TERM=vt100` is already exported in `/etc/profile`; the elvis port is
the first serious raw-mode consumer ([[project_fgx_elvis_vi_hang...]]).

---

## 1. The two bugs (root-caused)

Both surface in vi's `:`-line (`vgets`, tio.c), but they are on **different
axes**:

- **DELETE → `^?` (erase-char axis).** elvis runs the tty raw (CBREAK) and
  edits the line itself in `vgets`, taking its erase char from `sg_erase` via
  `ioctl(TIOCGETP)` (`ERASEKEY = oldsgttyb.sg_erase`, curses.c BSD path). The
  kernel already defaults `sg_erase=$7F` (main.s:193) and the sgttyb struct
  matches byte-for-byte, so ERASEKEY *should* be `$7F` — but the `ERASEKEY→'\b'`
  remap lives in `getabkey` (tio.c:761), and the `:`-line reads through the raw
  `getkey(0)` path in some modes, skipping it. So `$7F` reaches the switch as
  `$7F` → default → echoed `^?`.

- **Ctrl-U → "right arrow" (keycode-collision axis).** On the IIgs ADB, arrows
  and Ctrl+HJKU latch the SAME byte (`$08/$0A/$0B/$15`). The kernel heartbeat
  (toolbox.s:340-370) disambiguates by high-bitting the Ctrl form
  (`Ctrl-U→$95`, right-arrow→`$15`). But elvis-as-vt100 wants `Ctrl-U=$15` and
  arrows as ESC-sequences — so it gets `$95`, doesn't bind it, and echoes it
  (cursor advances = "right arrow"). `stty` cannot fix this; it is the
  terminal/keyboard model.

The kernel's `$95` disambiguation is the ENABLER: it means the byte stream
already distinguishes Ctrl-U from right-arrow, so a translation layer can map to
vt100 unambiguously.

---

## 2. Grounded current state

- **Kernel keyboard (toolbox.s:331-400).** Heartbeat reads `$E0C000`, `AND #$7F`,
  clears strobe, then the disambiguation: naked arrow → bare `$08/$0A/$0B/$15`;
  Ctrl+HJKU → `$88/$8A/$8B/$95`. Enqueues **one byte** into the 16-entry
  `_kKbdRing` (`@hb_kbdEnqueue`/`@hb_kbdRing`, single-byte push).
- **sgtty seam exists + round-trips.** `TIOCGETP/SETP` copy the 10-byte sgttyb
  image (2-byte slots; `sg_erase=$7F`, `sg_kill=$15` defaults, main.s:193-196);
  `TIOCGETC/SETC` the 12-byte tchars. `struct sgttyb` (sgtty.h) matches the
  kernel image. The **cooked** line reader honors erase (`$08`/sg_erase) and
  kill (`$95` = sg_kill|$80) — syscall.s:2160-2172.
- **No stty(1).** Portable from `examples/2.11BSD/usr/bin/stty/stty.c` (11 KB).
- **termcap** = a baked vt100 entry (libc `tc_getstr`, hand-asm in
  fcc_libc_shims.s/libc.s). Arrow caps (`ku/kd/kl/kr`) must be confirmed/aligned
  to whatever the console emits.
- **Bare-arrow consumers that will ripple:**
  - **jsh** line editor (jsh.c:396/419): `$15`/`^F`→cursor-right, `$0b`/`$0a`→
    history up/down. Reads bare arrow codes directly.
  - **ntpplay** (ntpplay_stubs.s:652-654): `$08`/`$15` = volume down/up.

---

## 3. Design

The organizing principle: **the FGX console IS the terminal.** A terminal emits
byte streams; a vt100 emits ESC-sequences for cursor/function keys and bare
control codes for Ctrl+letter. That responsibility belongs at the
console/keyboard layer (kernel heartbeat), so EVERY raw-mode reader sees a
consistent vt100 stream — not per-app translation.

### 3.1 Keyboard → vt100 byte stream (kernel, toolbox.s)
Replace the disambiguation block with a vt100 mapping:
- **Ctrl+HJKU** (currently `$88/$8A/$8B/$95`) → bare `$08/$0A/$0B/$15`. (vt100
  Ctrl+letter.)
- **Naked arrows** (currently `$08/$0A/$0B/$15`) → ESC-sequences: Up `ESC [ A`,
  Down `ESC [ B`, Right `ESC [ C`, Left `ESC [ D`. (Match the termcap; `ESC O x`
  "application cursor keys" is an alternative — pick one and align termcap.)
- **DELETE** already `$7F` — keep.
- The heartbeat must **enqueue multiple bytes** for one keypress (3 for an
  arrow). `_kKbdRing` push becomes a small loop over a 1–3 byte sequence; ensure
  ring capacity/overflow behavior is sane (16 entries is fine; an arrow burst is
  3). Con_PollKey/Con_GetKey consumers already dequeue byte-at-a-time — no change.

### 3.2 Cooked-mode line discipline (kernel syscall.s)
The cooked reader currently special-cases erase/kill on single bytes. With
arrows now ESC-sequences, cooked mode should NOT treat a stray `ESC [ C` as
editing (BSD sh has no arrow editing) — it either passes them through or ignores
them in canonical mode. Decide: pass-through (simplest) vs swallow. Erase/kill on
`$7F`/`$15`(=sg_kill, now bare) still work.

### 3.3 stty(1) (userland, port from 2.11BSD)
Port `examples/2.11BSD/usr/bin/stty/stty.c`. It uses `gtty/stty` (TIOCGETP/SETP)
+ TIOCGETC/SETC — all present. `stty` with no args prints settings; `stty erase
^?`, `stty kill ^U`, `stty raw/-raw/cbreak/echo/-echo` set them. This is where
erase/kill config lives (the maintainer's point: "you used to set this in shell init with
stty"). `/etc/profile` can `stty erase '^?' kill '^U'` if defaults ever need
overriding.

### 3.4 termcap alignment
Confirm the baked vt100 `ku/kd/kl/kr` equal the sequences §3.1 emits (`\E[A`
etc.). If missing, add them to the baked entry. elvis then maps arrows to
movement via its normal termcap path; ctrl commands work off the bare codes.

### 3.5 elvis erase path (DELETE)
With `sg_erase=$7F` and the vt100 stream, elvis's `ERASEKEY=$7F`. Ensure the
`:`-line honors it in BOTH read paths (getkey and getabkey) — either fix is in
`unix.c`/the port (tracked), not vendored elvis. Cleanest: the machine layer
guarantees the erase char reaches vgets as `$7F` (elvis maps ERASEKEY→`\b`), or
map `$7F`→`\b` at the seam. Verify which mode the `:`-line uses.

### 3.6 Ripple fixes (REQUIRED — do not silently break)
- **jsh line editor:** convert its arrow/history handling to parse vt100
  ESC-sequences (`ESC [ A/B/C/D`) instead of bare `$0b/$0a/$15`. (Or: jsh reads
  cooked and drops in-shell arrow editing — but history is a real feature; keep
  it, parse ESC.) `^F`/`^B`/`^P`/`^N` bare-ctrl bindings still work.
- **ntpplay:** its volume keys (`$08`/`$15`) now arrive as `ESC [ D`/`ESC [ C`.
  Update its key reader to parse the arrow ESC-sequences.

---

## 4. Phasing

- **P1 — stty(1)** (independent, low-risk): port from 2.11BSD + man page. Lets
  erase/kill be inspected/set. Ships value immediately, no behavior change.
- **P2 — vt100 keyboard emission** (kernel toolbox.s + ring multi-byte push):
  arrows→ESC, Ctrl+letter→bare. The core change.
- **P3 — ripple:** jsh ESC-sequence line editing; ntpplay volume keys; termcap
  ku/kd/kl/kr alignment; elvis erase-path verify.
- **P4 — validation:** headless. NOTE the test wrinkle — kbd-ring injection
  poke s POST-heartbeat bytes, so it tests §3.1's OUTPUT (inject `\E[C`, `$15`,
  `$7F`) against consumers, but NOT the heartbeat's ADB→vt100 translation itself.
  Testing the heartbeat needs poking `$E0C000`+strobe (an fgxdebug addition) or a
  hand-run ADB pass.

---

## 5. Open questions (for the maintainer)

1. **Cursor-key mode:** `ESC [ A` (normal) vs `ESC O A` (application). vt100
   apps toggle via DECCKM; elvis/termcap usually want `\EOA` in some entries.
   Pick to match the baked termcap (confirm what it has).
2. **Cooked-mode arrows:** pass-through vs swallow ESC-sequences in canonical
   mode? (Affects the shell prompt when not line-editing.)
3. **jsh history editing:** keep it (port to ESC parsing) or drop to plain cooked
   (BSD sh has none)? History is nice; ESC parsing is ~small.
4. **Function/Home/End/PageUp keys:** in scope now or later? (vt100 has
   sequences; low priority.)
5. **DEL vs BS as erase:** default `sg_erase=$7F` (DEL). Some prefer `^H`. Keep
   `$7F` (matches BSD + the Apple Delete key) and let `stty` override.

---

## 5a. Review corrections (Fable, 2026-07-13) — supersede §1/§3.2/§3.5/§3.6 where they conflict

- **DELETE is DECOUPLED from the vt100 project.** The doc's §1/§3.5 mechanism is
  WRONG: `getkey(when)` is a one-line wrapper for `getabkey(when,"",0)`
  (tio.c:694-698), so BOTH `vgets` read paths hit the `ERASEKEY→'\b'` remap
  (tio.c:762) — it is never skipped. The real cause: **`ERASEKEY != $7F` at
  runtime**, so `$7F` falls through `vgets`'s switch to the `else if (ch ==
  '\177')` arm (tio.c:179-185) which literally prints `^?`. `ERASEKEY` is set
  once in `resume_curses` from `sg_erase` (curses.c:395; FGX resolves to the
  sgttyb `#else` branch). So the fix is a **1-tap verification at the FGX seam**:
  confirm `ioctl(TIOCGETP)` hands elvis `sg_erase=$7F` at curses-init (else
  ERASEKEY stays 0). This needs NONE of the keyboard rework — do it first,
  independently.
- **Architecture is correct but not minimal.** Only elvis wants vt100; jsh +
  ntpplay want bare arrow bytes. The kernel already disambiguates ($15 vs $95),
  so **elvis's own `unix.c` `ttyread` has all the info to translate for elvis
  alone** (zero kernel change, zero ripple). Kernel-wide emission is the
  future-proof choice (consistent terminal for a future curses/readline
  consumer) but the ripple to jsh/ntpplay is **breaking rebinds, not additive**
  (see below). Decision point for the maintainer: kernel-wide (chosen) vs elvis-local.
- **If kernel-wide (P2), two MANDATORY edits the doc missed:**
  1. **Atomic 3-byte enqueue** (toolbox.s:394): test `count + seqlen ≤
     KBD_RING_SZ` up front, all-or-nothing. A per-byte full-check can push
     `ESC [` then drop `C` — a lone `ESC` means "leave insert / bell" in vi.
  2. **Delete `ORA #$0080` at syscall.s:2170.** Cooked-mode kill matches `$95`
     (sg_kill|$80); after P2 Ctrl-U arrives as bare `$15`, so kill silently
     breaks unless the match is on bare sg_kill.
- **jsh/ntpplay are INVERSIONS, not additions.** jsh.c:397 `key==0x15` today =
  cursor-right; post-P2 `$15` = Ctrl-U (opposite intent), and the `$95` kill
  branch (jsh.c:409) goes dead. ntpplay $08/$15 volume keys vanish into
  ESC-sequences and `$15` reappears as Ctrl-U. Both need ESC-sequence parsing
  AND removal of the old bare-code branches.
- **Cooked-mode arrows: pass-through is correct** (BSD canonical mode does not
  interpret arrows — inserts raw bytes). syscall.s:2178 already appends them;
  no strip needed.
- **Output symmetry:** the emitted input sequences (`\E[A`…) MUST byte-equal the
  baked termcap `ku/kd/kl/kr`, or elvis won't bind them. Confirm the baked vt100
  entry's arrow caps and align.

## 6. Bottom line

Two bugs, two axes: DELETE is the erase-char/stty axis (plumbing exists, wire it
through raw mode + ship stty); Ctrl-U is the keycode-model axis (make the console
emit vt100 so Ctrl+letter and arrows stop colliding). The clean home is the
kernel keyboard layer (one consistent terminal for all apps) + a real stty, with
required ripple fixes to jsh and ntpplay. Recommend building P1 (stty) first as
independent value, then P2/P3 together behind headless tests.
