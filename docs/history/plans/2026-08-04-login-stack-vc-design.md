# init/getty/login + alt-N virtual consoles -- design (2026-08-04)

Implements slices C and D of
`docs/history/plans/2026-07-31-bsd-login-stack-scope.md`.  That doc scoped the
work and evaluated the ports; this one is the design decisions.  Slices A and B
are done and are not revisited here.

## 0. State this builds on (verified in-repo 2026-08-04, not from memory)

| Piece | State |
|---|---|
| Slice A1 stage 2 multi-block directory scan | done -- `/etc` can hold `passwd`, `ttys`, `issue` |
| Slice A2 real `ttyname(fd)` | done -- `FIODGNAME` ioctl + `_ttyNames`, `libc_c.c:2279` |
| Slice B bank-0 arena | done -- `FGX_STK_ARENA_PAGES EQU 149` |
| Measured stacks (incl. guard page) | `sh` 12, `tcsh` 55, `vi` 15, `tar` 17 |
| `tools/check_stack_budget.py` | green, worst case 87/149 |
| pwent suite | real 7-field `/etc/passwd` parser in `libc_c.c:2110+` |
| ptys | 2 pairs, `src/kernel/pty.s` |
| `NTTY` | 3 = console + 2 pty slaves |
| `init` | 116-line stub: `sh /etc/rc`, then `/bin/sh` as `-sh`, wait, halt |

**The ceiling, stated up front.** Three concurrent `tcsh` is 168 pages against a
149-page arena.  No configuration removes it.  `login`'s ENOMEM fallback to
`/bin/sh` is the backstop; slice B3 (console-lane address-preserving swap) is
what would lift it, and is not in this campaign.  Realistic mixes do fit:
1 tcsh + 2 sh = 82, with `tar` on top = 99.

---

## 1. Slice C -- the login chain

Everything `exec`s; nothing forks a shell.  `getty` execs `login` execs the
shell, so the chain costs zero extra arena over the shell alone.  This is a rule
across the whole chain, not a later optimization.

### 1.1 libc additions (`toolchain/lib/libc_c/`)

Toolchain-first: these are libc gaps, so they get fixed in libc, not
reimplemented per tool.

- **`getpass(3)`** -- sgtty echo off on **fd 0**, read a line, restore.  BSD
  opens `/dev/tty` to bypass redirection; FGX has no such device -- the
  registered chardevs are `console`, `ttyp0/1`, `ptyp0/1` (`signal.s:1284`), and
  there is no controlling-terminal alias.  `getty` and `login` always have the
  line on fd 0/1/2, so fd 0 is the same file descriptor BSD would have reached,
  without inventing a kernel concept.  Documented in `getpass(3)`, not silently
  different.  Revisit if something needs a password prompt while stdin is
  redirected.
- **`<ttyent.h>` + `getttyent`/`getttynam`/`setttyent`/`endttyent`** -- flat
  `/etc/ttys` parser.  `struct ttyent` carries `ty_name`, `ty_getty`, `ty_type`,
  `ty_status`, `ty_window`, `ty_comment`.  **There is no shell field** -- see
  section 4.
- **`crypt(key, salt)`** -- a cheap non-DES hash with a `$`-prefixed tag, so a
  real DES `crypt` can coexist later without invalidating existing entries
  (the maintainer, 2026-07-31).  Classic 25-round DES on a 2.8 MHz 65816 would make login
  visibly pause and the security value on a single-user IIgs is decorative.

Deferred, with reasons: real DES `crypt`; `grp.h`/`/etc/group`/`initgroups`
(`login` works without supplementary groups); utmp/wtmp beyond `ut_line`
(`who`/`w`/`last` want it, nothing on the critical path does).

### 1.2 `/bin/getty` (~150 lines, no vendored source)

`getty` is not vendored -- `vendor/2.11BSD/` carries only
`usr/{bin,old,sbin,ucb,usr.bin}` and getty lives in `libexec/`.  Its job also
collapses here: no baud negotiation, no modem, no parity autodetect, no
`gettytab`.

Open the line, apply sgtty modes, print `/etc/issue`, read a name, `exec
/bin/login <name>`.

### 1.3 `/bin/login` (~150 lines, hybrid port of `usr/bin/login/login.c`)

The core flow lifts cleanly: `getpwnam` -> `getpass` -> `crypt` -> compare ->
`setgid`/`setuid` -> `chdir(pw_dir)` -> build env -> exec `pw_shell` as `-sh`.

Environment: `HOME` from `pw_dir`, `SHELL` from `pw_shell`, `USER` from
`pw_name`, `TERM` from the line's `ty_type` (the one per-tty knob that survives),
`PATH=:/bin:/usr/bin:/sbin`.

**ENOMEM handling ships with the feature, not after it.**  On spawn failure,
report it and fall back to `/bin/sh` rather than dropping the session.  Until
B3 lands this is the only backstop against the arena ceiling.

Deleted from the port outright: quota, `setpriority`, `initgroups`,
`setlogin`, `lastlog`, syslog, tzfile, Kerberos, and the `-h` hostname/`netdb`
path (`-h` returns if telnetd ever wants it).

### 1.4 `init` rewrite (~250-300 lines, workalike of `usr/sbin/init/init.c`)

`init` is PID 1 at `/sbin/init`, spawned by the kernel (`main.s:619`).

**Kept from today's stub:**
- `chdir("/root")`.
- `sh /etc/rc` run **to completion first**.  The vendored BSD rc sources
  `/etc/netstart`, which is where dhclient leases.  Gettys must not print
  prompts before the network is up.  A missing or failing rc is not fatal.

**Replaced:** the single spawn-shell-and-wait becomes BSD's respawn engine --
the `itab` line table from `/etc/ttys`, fork+exec each enabled line's
`ty_getty`, respawn on child exit, the `gettytime`/`gettycnt` throttle that
stops a broken line spinning, and re-read of `/etc/ttys` on SIGHUP.

**Dropped from the vendored source:** `sysctl`, `reboot(2)`/`RB_*`, syslog,
`autoconfig()`, securelevel (`get/setsecuritylevel`), single-user/multi-user
transition, and the window-system `wcmd` fork.

**Mostly shed:** login-environment seeding.  `PATH`/`HOME`/`TERM` move to
`login`, which has the real sources.  **One exception:** the shipped ttyv0 line
runs `/bin/sh` directly with no `login` in between (section 1.6), so init still
seeds a default env for a `ty_getty` that is a bare shell.

**Changed:** shutdown.  Today shell-exit *is* the shutdown path -- init returns,
has no parent, and `_Kern_Halt` fires.  With respawn that path disappears.  See
1.5.

### 1.5 `/sbin/halt` (~30 lines) + SIGTERM in init

`halt` sends SIGTERM to pid 1.  init stops respawning, kills its gettys, syncs,
and exits -- no parent, so `_Kern_Halt` fires exactly as today.

Rejected: special-casing ttyv0's child exiting as the shutdown signal.  It is a
non-BSD special case and means you can never simply log out of console 1.

Low risk to the harness: all 36 tests in `tools/mame_test/tests/` end on screen
assertions or timeout, none on shell-exit-halts.  `halt` is additive.

### 1.6 New `/etc` files

- **`/etc/ttys`** -- shipped as:

  | line | `ty_getty` | `ty_type` | note |
  |---|---|---|---|
  | ttyv0 | `/bin/sh` | vt100 | auto-root, no login |
  | ttyv1 | `/bin/getty` | vt100 | |
  | ttyv2 | `/bin/getty` | vt100 | |

  `ty_getty` is simply "the command init runs on this line", so pointing it at
  `/bin/sh` gives an auto-login root shell with no new code and no non-BSD
  field.  Every existing MAME test keeps working unchanged, and the login path
  is exercised on ttyv1/ttyv2 plus a dedicated test that swaps in a `ttys` with
  `getty` on ttyv0.

- **`/etc/issue`** -- banner printed by getty.
- **`/etc/passwd`** -- already staged.

### 1.7 `/bin/passwd` (~120 lines, workalike of `usr/bin/passwd/passwd.c`)

The vendored source is built around `ndbm` + `/etc/ptmp` locking + `mkpasswd`.
FGX has no ndbm, so this is a flat-file rewrite: read `/etc/passwd`, prompt old
+ new, `crypt`, rewrite via a temp file and rename.

---

## 2. Slice D -- three virtual consoles

### 2.1 tty table

`NTTY` 3 -> 5: `tty[0..2]` = ttyv0/ttyv1/ttyv2, `tty[3..4]` = the two pty
slaves.  Each VC is its own tty table entry, so `TTY_FgPgrp`, `^C` and job
control are already per-VC with no new plumbing.  `/dev/ttyv0..2` register
through the existing dynamic chardev registry (`_Chardev_LookupSuffix`);
`/dev/console` aliases ttyv0; `_ttyNames` from slice A2 grows with `NTTY`.

### 2.2 Per-VC framebuffers: one bank per VC

Each VC owns a whole bank laid out identically to today's console bank -- the
four 8 KB buffers (`CON_CHARBUF`/`ATTRBUF`/`FGBUF`/`BGBUF`, 100 rows x 80) plus
the four 2 KB alt-screen snapshots, 40 KB of 64 KB.  Full 100-row scrollback per
VC, and alt-screen isolation comes free because each VC's snapshot buffers live
in its own bank.

The two extra banks are taken from the user pool via `Bank_Alloc` at `Con_Init`
and held permanently.  This avoids churning the `REST_*` region offsets
(`include/kernel.s:85-89`) and the loader's baked banks.  Cost: 2 of the 24
banks in `BANK_USER_FIRST..BANK_USER_LAST`.

Rejected alternatives: sharing bank `$03` with 25-row buffers for ttyv1/ttyv2
(asymmetric layout, two row-addressing paths, no scrollback on two consoles);
and MVN save/restore of 32 KB per switch (~50-80 ms at 2.8 MHz on top of the
repaint).

### 2.3 `Con_SwitchVC(n)`

The relocation mechanism already exists.  `Con_Init` walks `_ConBankPatchTbl`
(75 generated entries, `console_bankpatch.s`) rewriting every baked-`$03`
operand bank byte to `_kConsoleBank`.  A VC switch runs that same loop with a
different bank:

1. Save the live console globals into the outgoing VC's state block
   (`_conWritePtr`, `_conTopRow`, `_conCurRow`, `_conCurCol`, follow flag,
   `_conMode`, `CON_VT_STATE`, color state -- the same set
   `Con_EnterAltScreen` already saves, plus mode/color).
2. Rewrite the 75 bank bytes to the incoming VC's bank.
3. Load the incoming VC's state block.
4. `Con_RenderAll`.

The state block is a small struct per VC, kept in kernel-bank globals.  Nothing
in the per-access path changes, which is why this is cheaper than making every
site read a variable.

### 2.4 The alt-N hook

The IIgs has no keyboard IRQ; the kernel heartbeat (`toolbox.s::_HBTickTask`)
polls `$E0C000` at every VBL and enqueues into `_kKbdRing`.  That same code
already reads `$E0C025` for the Ctrl bit (`toolbox.s:375`), so the modifier is
in hand.  KEYMODREG bit assignments, verified against Firmware Reference p.298:
bit 7 Open-Apple, **bit 6 Closed-Apple (Option)**, bit 5 mod-no-key-press,
bit 4 keypad, bit 3 repeat, bit 2 caps lock, bit 1 Ctrl, bit 0 Shift.

Option+`1`/`2`/`3` is intercepted **at enqueue time** and
switches instead of enqueuing.  Enqueue time, not read time, so switching works
even when nothing is reading.

Keystrokes are delivered only to the active VC.  A reader blocked on an
inactive VC simply never receives input, which is the correct semantics and
falls out of routing at the single enqueue point.

### 2.5 Kernel output

Kernel log/boot messages always render into ttyv0's buffer -- `/dev/console` is
ttyv0.  A panic/`_Kern_Halt` force-switches focus to ttyv0 first, so the death
message is visible regardless of which VC was in focus.

Rejected: following the active VC (kernel chatter scribbles over a full-screen
app on whatever console you are using); and no force-switch (a panic on ttyv2
leaves a frozen machine with no visible reason).

---

## 3. Build order

C before D.  Within C:

1. libc (`getpass`, `ttyent`, `crypt`)
2. `getty` + `login` -- exercised from a shell on a pty, no boot involvement
3. `/sbin/halt`
4. `init` -- **last**; a broken PID 1 is an unbootable disk with no diagnostic
5. `passwd(1)`

Then D.  Nothing in D is worth building before there is something to put on a
second console.

---

## 4. Correction carried forward from the scope doc

An earlier draft claimed per-console shell policy via `/etc/ttys` (console 1
tcsh, ttyv1/ttyv2 sh).  **That is wrong and stays wrong.**  A tty does not
default to any shell.  `login` instantiates the shell only after
authentication, from that user's `pw_shell` in `/etc/passwd`.  The shell-cost
lever is **per-user, not per-tty**: nothing prevents one user logging into all
three consoles and getting three copies of their own shell.  That is what the
ENOMEM fallback in 1.3 exists for.

---

## 5. Testing

Each check below must go red without the change it guards -- a test that passes
either way is not coverage.

| What | How |
|---|---|
| `getty`/`login` | Headless on a pty pair (`src/userland/ptyshell` already provides one): scripted name + password, assert the exec'd shell and the environment.  **Negative control:** a wrong password must fail. |
| `init` respawn | MAME boot to a prompt on ttyv0; a second boot with a `/etc/ttys` that puts `getty` on ttyv0, proving the real path.  Kill a getty and assert it comes back; assert the throttle stops a line whose `ty_getty` exits immediately. |
| `/sbin/halt` | MAME run ending in `halt`, assert the machine halts. |
| VC switch | Write distinguishable text on ttyv1 and ttyv2, switch, assert each VC's CharBuf via fgxdebug.  Must go red with the switch stubbed out. |
| Arena | `tools/check_stack_budget.py` gains multi-console scenarios: three idle gettys; 1 tcsh + 2 sh + tar.  This is the fence that catches the arithmetic regressing. |
| Regression | Existing 36 MAME tests unchanged and green -- that is the point of ttyv0 running `/bin/sh`. |

Man pages ship with each tool: `init(8)`, `getty(8)`, `login(1)`, `passwd(1)`,
`halt(8)`, `ttys(5)`.
