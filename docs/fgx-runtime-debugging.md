# Debugging FGX runtime behavior (MAME) — the technique that cracked the vi pointer cluster

This documents the runtime-debugging method used to root-cause the vi multi-bank
crash + screen-corruption bugs (2026-06-01). It is **not** interactive MAME
single-stepping — it's the **headless test harness (`tools/mame_test/run.py` + the
`fgxdebug` Lua plugin) combined with in-program instrumentation**. In practice this beat
the interactive debugger for this class of bug because the runaway lands in the ROM
monitor (PC wanders `$FFxx`/`$00FDxx`), so the post-crash PC tells you little — you have
to instrument *forward* from known-good points.

## The harness in one paragraph
`python3 tools/mame_test/run.py [--headless] <test>` boots FGX in MAME, autoboots one
shell command (from `tools/mame_test/tests/<test>.json`), polls for the shell prompt to
return (clean exit) or times out, then dumps **CPU registers + named memory regions** to
`/tmp/fgx_test_<test>/dump.{json,txt}` via the `fgxdebug` plugin. The plugin dumps a
default region set (see `tools/mame_test/plugins/fgxdebug/init.lua`), including
`charbuf` (the live 80-col character buffer, found at run time through
`_kConsoleBank` rather than at a fixed bank) and `registers`
(`PB/PC/S/D/A/X/Y/P/DB/E`). `run.py`'s `load_dump` decodes `charbuf` into `screen_text`.

## Signals you get for free
- **Hang vs clean-exit:** `exit_status` = `clean` (shell prompt returned → exit-on-prompt
  fired) vs `timeout`. A program that completes returns to the shell; one that hangs/
  crashes times out.
- **Final PC + flags** (`dump.txt` top lines) — **read the caveat first.** Since
  2026-07-17 the fgxdebug plugin only snapshots registers on frames where the CPU is
  executing **in the kernel bank**, and reports the latest such snapshot (the
  `registers_in_kernel` flag). So a post-crash ROM runaway does **not** show up as a
  `$FF`/emulation-mode final PC — you see the last in-kernel PC instead, and the
  old two-timeout sampling trick cannot tell a crash from an input-wait.
  - To hunt a runaway PC, opt into **`pc_sample`** in the test manifest; the run
    writes `pc_samples.json` alongside the dump.
- **`screen_contains` / charbuf grep:** assert on rendered text. CAVEAT below.

## In-program instrumentation (the part that actually localizes bugs)

### 1. Marker bisection (find WHERE it crashes)
Inject visible markers at suspect points and see which is the LAST to appear:
```c
outstr("\033[1;60HMA"); flushbuf();   /* row 1, col 60 — clear of col-0 content */
```
Put each marker at a distinct fixed top-row column (so they persist and don't scroll),
then read them back from the charbuf dump. `MA..MD present, ME absent` ⇒ crash is
between MD and ME. Recurse (add markers between) until you've pinned it to one call.
This is how the vi crash was narrowed: `edit() → cursupdate() → s_refresh(VALID) →
buf1line()` in a handful of rebuilds.

### 2. Reading runtime VALUES (the decisive step)
To see actual pointer/struct bytes, write them as hex to a fixed screen position and
read them from the charbuf. **Two hard-won gotchas:**
- **Do NOT use `char *hx = "0123456789ABCDEF"; hx[i]`** in diagnostic code — a local
  pointer to a string literal is *itself* miscompiled in multi-bank (it was one of the
  bugs). Use a **no-array-index hex emitter** instead:
  ```c
  void emit_nib(int n){ n&=15; outchar((char)(n<10?'0'+n:'A'+n-10)); }
  void emit_byte(int b){ emit_nib((b>>4)&15); emit_nib(b&15); }
  ```
- Read raw bytes via a `char*` to the object: `char *q=(char*)&g; emit_byte(q[2]);` gives
  byte 2 (the bank of a 24-bit pointer). `q=(char*)gptr;` then `q[0..2]` reads the bytes
  the pointer points at (an in-struct field's stored value).

This produced the smoking gun for the vi crash:
```
n1=$71AB56  n2=$8CAB71  P1=$9BAB8C   <- banks $71/$8C/$9B are INVALID (>8 MB RAM = banks
                                        $00..$7F); each bank == the NEXT alloc's offset-
                                        low ($71==n2.lo, $8C==P1.lo) = adjacent-global
                                        overflow because struct-ptr globals were DS 2.
```

### 3. Isolating a codegen bug without the full program
Pointer-codegen bugs that only show in the multi-bank LINK are invisible in single-TU
codegen review. To bisect: compile a tiny `.c` with `fcc <in.c> -o <out.s>` and read the generated
assembly (no MAME needed). There is no flag to toggle — `--far-calls` retired with the
P3-2.6 mode collapse, far-call lowering is the only lowering, and the data segment is
always emitted, so there is no single-bank build to diff against. Instead compare a
GLOBAL vs LOCAL vs param version of the same expression to localize which storage class
triggers it. (The vi bug only reproduced for *global* + *multi-level* + *heap* pointers;
locals were fine — that comparison is what pointed at the global-declaration size.)

## Charbuf decode is unreliable on a SCROLLED screen
`charbuf` is a ring buffer; once the editor scrolls, `_conTopRow` rotates and `run.py`'s
linear 80-col decode splits content across the wrap point. Symptoms: a sentinel that IS
present in the raw hex shows as "missing" in `screen_contains`; "Empty Buffer" appears at
the wrong row; counts (tildes) look off. For scrolled/editor screens, **trust the raw
charbuf substring search over the row-split decode, and ultimately trust a HUMAN windowed
run** (`./mame-hd.sh disk/fgxufs.po`). Headless **can** deliver keystrokes (the boot
command paste and `post_commands`), but MAME drops injected keystrokes in long flows —
so a long interactive sequence, and interactive *feel*, still need a human.

## When you DO want the interactive debugger
For a true single-step you'd run MAME with the debugger and break at a runtime address —
but multi-bank user code is loaded at loader-assigned banks, so you must first get the
runtime load address (from the link map / a `Kern_Log`), which is fiddly. For the
pointer-sizing class of bug, the instrumentation method above was faster and more
reliable. Reserve interactive single-stepping for cases where you must watch a specific
instruction's effect (e.g. an MX/DBR state transition) that instrumentation can't expose.

## Related
- `feedback_mame_debug` (screencapture + fgxdebug), `feedback_run_headless_mame_harness_yourself`.
- `feedback_recognize_fgx_crash_vs_error` (crash vs error screen recognition).
- `project_fgx_vi_multibank_pointer_blocker` (the bug this method solved).
