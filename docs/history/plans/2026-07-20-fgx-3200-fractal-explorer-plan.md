# FGX 3200-color SHR layer + Mandelbrot/Julia explorer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOTE: 65816 asm islands and the scanline-IRQ handler must be authored INLINE by the lead session, not delegated to subagents (FGX policy: subagents are unreliable on 65816 asm).

**Goal:** Build a reusable `libfgx` Super Hi-Res graphics layer and a fixed-point Mandelbrot/Julia explorer that renders in true 3200-color mode.

**Architecture:** `gfx_*` primitives live in the default-linked libfgx pile (C with `__asm` islands; one hand-asm scanline-IRQ handler). The `fractal` userland tool is a thin client: fixed-point compute → 64000-byte iteration buffer → range-fit colorize → `gfx_*` display. Delivered in two milestones — tier 2 (per-8-row SCB palettes, `H=8`) first, then tier 3 (scanline-IRQ per-line palettes, `H=1`) additively behind the same API.

**Tech Stack:** fcc (K&R C, int=16, long=32, no `long long`), 65816 `__asm` islands, libfgx pile (`toolchain/lib/libfgx_c/libfgx.c`), MAME headless pixel-hash tests (`tools/mame_test/`), host `cc`/`clang` reference oracle.

**Design spec:** `docs/history/plans/2026-07-20-fgx-3200-fractal-explorer.md`

## Global Constraints

- **ASCII only** in all on-disk/source/console text — no em-dash/curly/arrows.
- **fcc has no `long long`** — the 32×32→64 fixed-point product uses an asm/partial-product helper on FGX; `int64_t` is allowed only in host reference code.
- **Iteration buffer ≤ 64000 bytes, single bank** — 1 byte/pixel, 255-iteration cap. Never a 2-byte/pixel buffer (would cross a bank → fcc ptr-arith-past-64KB gap).
- **New code in C/fcc**; the ONLY hand-asm is the tier-3 scanline-IRQ handler.
- **Fixed-point format: 8.24 signed 32-bit**, byte-aligned descale (`>>24`).
- **3200-color = 320/4bpp only** — the graphics layer switches to 320 and restores the console on exit.
- **libfgx pile rules:** near calls only within the pile; syscalls via the standard trap; DBR-relative data reads live in the `_data.s` half (`libfgx_data.s`).
- **Man page required** when shipping a userland tool (`man/manN/fractal.N`-style, per repo layout).
- **Land discipline:** feature branch `feat/fgx-3200-fractal` → merge to main → `./release.sh`. NEVER push the feature branch.
- **Test cadence:** per-task = the task's own fixture(s); pre-merge = full gate.

---

### Task 1: Host reference oracle (fix-point mul + reference fractal)

Independent host program that (a) validates the 8.24 fixed-point multiply against `double`, and (b) generates the golden iteration-buffer SHA-256 for known views, so on-device goldens are oracle-derived, not self-recorded.

**Files:**
- Create: `tools/fractal-ref/fractal_ref.c`
- Create: `tools/fractal-ref/Makefile`
- Create: `tools/fractal-ref/README.md`

**Interfaces:**
- Produces: `fix_mul(int32_t a, int32_t b) -> int32_t` (8.24 semantics), `mandel_iter(int32_t cr, int32_t ci, int max) -> int` — the exact algorithm the FGX code mirrors. Emits `--hash <cr0> <ci0> <step> <w> <h> <maxit>` → prints the SHA-256 of the 1-byte-per-pixel iteration buffer.

- [ ] **Step 1: Write the failing test (fix_mul vs double)**

```c
/* tools/fractal-ref/fractal_ref.c */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#define FBITS 24
static int32_t fix_mul(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * (int64_t)b) >> FBITS);
}
static int32_t dtofix(double d) { return (int32_t)(d * (double)(1<<FBITS)); }

static int selftest(void) {
    struct { double a, b; } cases[] = {
        {1.5,2.0},{-1.5,2.0},{0.25,0.25},{-0.1,-0.1},{1.999,1.999},{0.0,3.0}
    };
    int fails = 0;
    for (int i=0;i<(int)(sizeof(cases)/sizeof(cases[0]));i++) {
        int32_t got = fix_mul(dtofix(cases[i].a), dtofix(cases[i].b));
        double want = cases[i].a * cases[i].b;
        double err = fabs((double)got/(double)(1<<FBITS) - want);
        if (err > 1.0/(double)(1<<20)) {
            printf("FAIL %g*%g got %g want %g\n", cases[i].a, cases[i].b,
                   (double)got/(double)(1<<FBITS), want);
            fails++;
        }
    }
    return fails;
}

int main(int argc, char **argv) {
    if (argc==2 && !strcmp(argv[1],"--selftest")) return selftest();
    return 0;
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd tools/fractal-ref && cc -O2 -o fractal_ref fractal_ref.c -lm && ./fractal_ref --selftest; echo rc=$?`
Expected: builds; `rc=0` (selftest passes immediately — this routine is the spec). If any FAIL line prints, the fixed-point rounding is wrong; fix `fix_mul` before proceeding.

- [ ] **Step 3: Add the reference iterator + hash mode**

```c
/* append to fractal_ref.c, before main(); add #include for SHA */
static int mandel_iter(int32_t cr, int32_t ci, int maxit) {
    int32_t zr=0, zi=0; int n=0;
    for (; n<maxit; n++) {
        int32_t zr2=fix_mul(zr,zr), zi2=fix_mul(zi,zi);
        if ((int64_t)zr2 + (int64_t)zi2 > ((int64_t)4<<FBITS)) break; /* |z|^2>4 */
        int32_t nzr = zr2 - zi2 + cr;
        zi = fix_mul(zr,zi)*2 + ci;
        zr = nzr;
    }
    return n>255?255:n;
}
/* --hash cr0 ci0 step w h maxit : print sha256 of the WxH iteration buffer.
   Uses a vendored tiny sha256 (add tools/fractal-ref/sha256.[ch]) OR shells to
   `shasum -a 256` by writing the buffer to stdout when argv[1]=="--raw". */
```

Implement `--raw cr0 ci0 step w h maxit` (write raw buffer bytes to stdout) and hash via `shasum` in the Makefile — avoids vendoring SHA. `cr0/ci0/step` are 8.24 fixed-point integers passed as decimal.

- [ ] **Step 4: Emit and record the milestone view hash**

```bash
cd tools/fractal-ref && cc -O2 -o fractal_ref fractal_ref.c -lm
# Full-set view: cr in [-2.5,1.0], ci in [-1.5,1.5], 320x200, 255 iters.
# cr0 = -2.5*2^24 = -41943040 ; step = 3.5/320 * 2^24 = 183500 ; ci0 = -1.5*2^24 = -25165824
./fractal_ref --raw -41943040 -25165824 183500 320 200 255 | shasum -a 256
```
Record the printed hash in `tools/fractal-ref/README.md` as `GOLDEN_FULLSET`. This value is consumed by Task 5.

- [ ] **Step 5: Commit**

```bash
git add tools/fractal-ref/
git commit -m "test(fractal): host C reference oracle for 8.24 fixmul + iteration buffer"
```

---

### Task 2: libfgx `gfx_enter` / `gfx_exit` — mode switch

Save console SCB+palette state, switch to SHR 320, restore console (repaint) on exit.

**Files:**
- Modify: `toolchain/include/fgx.h` (add `gfx_*` prototypes)
- Modify: `toolchain/lib/libfgx_c/libfgx.c` (add `gfx_enter`/`gfx_exit`)
- Create: `src/userland/gfxprobe/gfxprobe.c` (fixture client)
- Create: `tools/mame_test/tests/gfxprobe_enter.json`

**Interfaces:**
- Produces: `void gfx_enter(void);` `void gfx_exit(void);`. `gfx_enter` sets all 200 SCBs to 320-mode (bit7=0), leaves SHR enabled, and snapshots the 16 palettes + 200 SCBs into a libfgx-owned save area. `gfx_exit` restores them and forces a console repaint.

- [ ] **Step 1: Add prototypes**

```c
/* toolchain/include/fgx.h  (FGX-specific graphics layer) */
void gfx_enter(void);
void gfx_exit(void);
void gfx_plot(int x, int y, int color);              /* Task 3 */
void gfx_fill_row(int y, const unsigned char *px160); /* Task 3: 160 packed bytes */
void gfx_set_line_palette(int line, const unsigned int *colors16); /* Task 4 */
void gfx_show(void);                                  /* Task 9 (tier 3) */
void gfx_hide(void);                                  /* Task 9 (tier 3) */
```

- [ ] **Step 2: Write the fixture + failing test**

```c
/* src/userland/gfxprobe/gfxprobe.c */
#include <fgx.h>
int main(int argc, char **argv) {
    gfx_enter();
    /* paint scanline 0 palette-index 1 across, leave rest 0, so the SHR hash
       is deterministic and independent of palette contents. */
    int x; for (x=0;x<320;x++) gfx_plot(x,0,1);
    /* park so the harness can dump SHR before we exit */
    if (argc>1) return 0;    /* exit path exercises gfx_exit via crt0 atexit? no: call explicitly */
    gfx_exit();
    return 0;
}
```

```json
// tools/mame_test/tests/gfxprobe_enter.json
{
  "binary": "gfxprobe",
  "args": ["hold"],
  "memory_regions": [{"name":"shr","addr_hex":"E12000","len":32000}],
  "expect": { "memory": [{"name":"shr","sha256":"RECORD_ME"}] }
}
```

- [ ] **Step 3: Implement `gfx_enter`/`gfx_exit`**

In `libfgx.c`, using `__asm` islands for the SHR/SCB/palette hardware (regs from `include/hardware.s`: `SHR_SCB=$E19D00`, `SHR_PALETTES=$E19E00`, `SHR_SCREEN=$E12000`; new-video `$C029`). `gfx_enter`: snapshot 200 SCBs + 32-byte×16 palettes into a static save buffer in `libfgx_data.s`, then write 320-mode SCBs. `gfx_exit`: copy the save buffer back, then call the console repaint entry (reuse the console's full-repaint path — locate via `Con_` symbols in `src/drivers/console/`). Author the asm island inline.

- [ ] **Step 4: Build, record golden, verify**

```bash
# add `build_userbin_fgx2_c gfxprobe` to build.sh (test section), then:
./build.sh disk
cd tools/mame_test && python3 run.py gfxprobe_enter --update-goldens
python3 run.py gfxprobe_enter    # Expected: PASS (mem.shr sha256 matches, 32000 B)
```

- [ ] **Step 5: Commit**

```bash
git add toolchain/include/fgx.h toolchain/lib/libfgx_c/libfgx.c \
        src/userland/gfxprobe/ tools/mame_test/tests/gfxprobe_enter.json build.sh
git commit -m "feat(gfx): gfx_enter/gfx_exit SHR 320 mode switch + console save/restore"
```

---

### Task 3: libfgx `gfx_plot` + `gfx_fill_row` (framebuffer writes)

**Files:**
- Modify: `toolchain/lib/libfgx_c/libfgx.c`
- Modify: `tools/mame_test/tests/gfxprobe_enter.json` (extend pattern)

**Interfaces:**
- Consumes: `gfx_enter` (mode is set).
- Produces: `gfx_plot(x,y,color)` writes one 4bpp pixel at `$E12000 + y*160 + (x>>1)`, high nibble = even x. `gfx_fill_row(y, px160)` copies 160 packed bytes to scanline `y`.

- [ ] **Step 1: Failing test** — extend `gfxprobe.c` to draw a known 2-row pattern (row 0 = index 1, row 1 = index 15 via `gfx_fill_row`), reset golden to `RECORD_ME`.
- [ ] **Step 2: Run, expect FAIL** — `python3 run.py gfxprobe_enter` fails (sha mismatch: pixels not yet written correctly / fill_row absent).
- [ ] **Step 3: Implement** `gfx_plot` (nibble pack, banked `STA [ptr],y` island — banked 24-bit store into `$E1`) and `gfx_fill_row` (word-loop copy island). Author asm inline.
- [ ] **Step 4: Record + verify**

```bash
./build.sh disk && cd tools/mame_test && python3 run.py gfxprobe_enter --update-goldens && python3 run.py gfxprobe_enter
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add toolchain/lib/libfgx_c/libfgx.c tools/mame_test/tests/gfxprobe_enter.json src/userland/gfxprobe/gfxprobe.c
git commit -m "feat(gfx): gfx_plot + gfx_fill_row banked 4bpp framebuffer writes"
```

---

### Task 4: libfgx `gfx_set_line_palette` (tier 2 — SCB band palette)

**Files:**
- Modify: `toolchain/lib/libfgx_c/libfgx.c`
- Create: `tools/mame_test/tests/gfxprobe_pal.json`

**Interfaces:**
- Consumes: `gfx_enter`.
- Produces: `gfx_set_line_palette(line, colors16)`. Tier-2 semantics (this task): `band = line>>3`; writes the 16 `colors16` values (12-bit `0RGB`) into hardware palette slot `band & 15`, and sets SCB bytes `line..line+7` to select that palette. (Tier-3 override comes in Task 9.)

- [ ] **Step 1: Failing test** — `gfxprobe.c` "pal" mode: `gfx_enter`; for band 0 set palette to a known 16-color ramp; `gfx_fill_row` rows 0..7 with indices 0..15 repeating; dump both `shr` and the palette region.

```json
// tools/mame_test/tests/gfxprobe_pal.json
{
  "binary": "gfxprobe", "args": ["pal"],
  "memory_regions": [
    {"name":"shr","addr_hex":"E12000","len":32000},
    {"name":"pal","addr_hex":"E19E00","len":512},
    {"name":"scb","addr_hex":"E19D00","len":200}
  ],
  "expect": { "memory": [
    {"name":"pal","sha256":"RECORD_ME"},
    {"name":"scb","sha256":"RECORD_ME"}
  ]}
}
```

- [ ] **Step 2: Run, expect FAIL** (function absent).
- [ ] **Step 3: Implement** the SCB + palette-RAM writes (banked stores to `$E19D00`/`$E19E00`).
- [ ] **Step 4: Record + verify**

```bash
./build.sh disk && cd tools/mame_test && python3 run.py gfxprobe_pal --update-goldens && python3 run.py gfxprobe_pal
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add toolchain/lib/libfgx_c/libfgx.c src/userland/gfxprobe/gfxprobe.c tools/mame_test/tests/gfxprobe_pal.json
git commit -m "feat(gfx): gfx_set_line_palette tier-2 (per-8-row SCB band palette)"
```

---

### Task 5: `fractal` compute pass — oracle-tied

The core: fixed-point iterate into the 64000-byte buffer, matching the host reference bit-for-bit.

**Files:**
- Create: `src/userland/fractal/fractal.c`
- Create: `tools/mame_test/tests/fractal_compute.json`

**Interfaces:**
- Consumes: nothing (pure compute; no graphics yet).
- Produces: `fix_mul(long,long)->long`, `mandel_iter(long cr,long ci,int maxit)->int`, and a `compute(long cr0,long ci0,long step,int maxit)` that fills a 64000-byte static buffer `itbuf`. Byte-identical to `tools/fractal-ref` for the same params.

- [ ] **Step 1: Write `fractal.c` compute (no display)**

```c
/* src/userland/fractal/fractal.c  -- K&R C for fcc; long = 32-bit */
#include <fgx.h>
#define W 320
#define H 200
#define FBITS 24
static unsigned char itbuf[W*H];   /* 64000 B, single bank */

/* 32x32->descaled-32 signed fixed-point multiply. fcc has no long long, so
   this calls an asm helper in libfgx (fixmul32). Prototype in fgx.h. */
long fixmul32(long a, long b);     /* returns (a*b)>>24, signed */

static int mandel_iter(long cr, long ci, int maxit) {
    long zr=0, zi=0; int n;
    for (n=0; n<maxit; n++) {
        long zr2=fixmul32(zr,zr), zi2=fixmul32(zi,zi);
        if (fixmul32(zr,zr) + zi2 > (4L<<FBITS)) break; /* |z|^2>4 (see note) */
        long nzr = zr2 - zi2 + cr;
        zi = (fixmul32(zr,zi)<<1) + ci;
        zr = nzr;
    }
    return n>255?255:n;
}
static void compute(long cr0, long ci0, long step, int maxit) {
    int px,py; long cr,ci=ci0;
    for (py=0; py<H; py++, ci+=step) {
        cr=cr0;
        for (px=0; px<W; px++, cr+=step)
            itbuf[py*W+px] = (unsigned char)mandel_iter(cr,ci,maxit);
    }
}
int main() {
    compute(-41943040L, -25165824L, 183500L, 255); /* GOLDEN_FULLSET params */
    return 0;   /* fixture dumps itbuf via its symbol address */
}
```

NOTE on the escape test: `zr2+zi2` can overflow 32-bit `long` near escape. Guard by testing `zr2 > (4L<<FBITS)` early, or compute the sum in the asm helper returning a saturating compare. Mirror whatever the host `fractal_ref.c` does EXACTLY — if you change the reference, re-record `GOLDEN_FULLSET`.

- [ ] **Step 2: Add `fixmul32` asm helper to libfgx**

Add `long fixmul32(long,long)` to `fgx.h` and implement in `libfgx.c` as an `__asm` island: signed 32×32→64 partial-product, then take bytes 3..6 (the `>>24`). Author inline.

- [ ] **Step 3: Write the failing test (oracle-tied golden)**

```json
// tools/mame_test/tests/fractal_compute.json
{
  "binary": "fractal", "args": ["--compute-only"],
  "memory_regions": [{"name":"itbuf","symbol":"itbuf","len":64000}],
  "expect": { "memory": [{"name":"itbuf","sha256":"GOLDEN_FULLSET_FROM_TASK1"}] }
}
```

Put the Task-1 `GOLDEN_FULLSET` hash here VERBATIM (not `--update-goldens`). If `run.py` addresses regions by hex not symbol, resolve `itbuf`'s address from the tool's `.sym`/map (document the exact address in the test).

- [ ] **Step 4: Build, run, verify against the host oracle**

```bash
# build.sh: build_userbin_fgx2_c fractal
./build.sh disk && cd tools/mame_test && python3 run.py fractal_compute
```
Expected: PASS (`mem.itbuf sha256 matches, 64000 B`) — proving the FGX fixed-point compute equals the host C reference. If FAIL: the asm `fixmul32` diverges from the reference; debug the multiply, do NOT re-record the golden.

- [ ] **Step 5: Commit**

```bash
git add src/userland/fractal/fractal.c toolchain/include/fgx.h toolchain/lib/libfgx_c/libfgx.c \
        tools/mame_test/tests/fractal_compute.json build.sh
git commit -m "feat(fractal): oracle-tied fixed-point compute pass (matches host C ref)"
```

---

### Task 6: `fractal` colorize + display (tier 2, `H=8`)

**Files:**
- Modify: `src/userland/fractal/fractal.c`
- Create: `tools/mame_test/tests/fractal_render8.json`

**Interfaces:**
- Consumes: `compute` (itbuf filled), `gfx_enter/plot/fill_row/set_line_palette`.
- Produces: `colorize(int bandh)` — range-fit per band of height `bandh`; `grad(int t /*0..255*/) -> unsigned int` 12-bit RGB gradient.

- [ ] **Step 1: Add `grad` + `colorize(bandh)`**

```c
/* gradient: t in 0..255 -> 0RGB (4/4/4). Simple blue->white->orange sweep. */
static unsigned int grad(int t) {
    int r,g,b;
    if (t>=255) return 0x000;                 /* interior = black */
    if (t<128){ r=t>>3; g=t>>3; b=8+(t>>5);} else { r=15; g=15-((t-128)>>4); b=(255-t)>>5; }
    return ((r&15)<<8)|((g&15)<<4)|(b&15);
}
static void colorize(int bandh) {
    int y0, y, x;
    unsigned int pal[16]; unsigned char row[160];
    gfx_enter();
    for (y0=0; y0<H; y0+=bandh) {
        int lo=255, hi=0;
        for (y=y0; y<y0+bandh; y++) for (x=0;x<W;x++){
            int v=itbuf[y*W+x]; if(v<lo)lo=v; if(v>hi)hi=v; }
        if (hi<=lo) hi=lo+1;
        { int i; for(i=0;i<16;i++) pal[i]=grad(lo + (hi-lo)*i/15); }
        gfx_set_line_palette(y0, pal);
        for (y=y0; y<y0+bandh; y++) {
            for (x=0;x<W;x++){
                int v=itbuf[y*W+x];
                int idx=(v-lo)*15/(hi-lo); if(idx<0)idx=0; if(idx>15)idx=15;
                if (x&1) row[x>>1]=(row[x>>1]&0xF0)|idx; else row[x>>1]=(idx<<4);
            }
            gfx_fill_row(y,row);
        }
    }
}
```

Wire `main()` to `compute(...)` then `colorize(8)` when run with `--render8`.

- [ ] **Step 2: Failing test**

```json
// tools/mame_test/tests/fractal_render8.json
{
  "binary": "fractal", "args": ["--render8"],
  "memory_regions": [
    {"name":"shr","addr_hex":"E12000","len":32000},
    {"name":"pal","addr_hex":"E19E00","len":512}
  ],
  "expect": { "memory": [
    {"name":"shr","sha256":"RECORD_ME"},
    {"name":"pal","sha256":"RECORD_ME"}
  ]}
}
```

- [ ] **Step 3: Run, expect FAIL** (goldens unset).
- [ ] **Step 4: Sanity-check visually, THEN record**

Before recording goldens, dump the SHR to a PNG once and eyeball it (recognizable Mandelbrot, smooth-ish bands). Only then:
```bash
./build.sh disk && cd tools/mame_test && python3 run.py fractal_render8 --update-goldens && python3 run.py fractal_render8
```
Expected: PASS. (Golden is self-recorded here because colorize output has no independent host oracle yet; the compute pass it builds on IS oracle-tied via Task 5, and the visual check gates correctness.)

- [ ] **Step 5: Commit**

```bash
git add src/userland/fractal/fractal.c tools/mame_test/tests/fractal_render8.json
git commit -m "feat(fractal): range-fit colorize + tier-2 (H=8) SHR display"
```

---

### Task 7: `fractal` controls (pan/zoom/Julia/quit, row-reveal)

**Files:**
- Modify: `src/userland/fractal/fractal.c`
- Create: `tools/mame_test/tests/fractal_zoom.json`

**Interfaces:**
- Consumes: `compute`, `colorize`, `getkey`/`pollkey` (libfgx), raw tty (`sgtty`).
- Produces: interactive loop; state `cr0/ci0/step/julia/jcr/jci`.

- [ ] **Step 1: Add the control loop** — raw tty; keys: arrows/`hjkl` move a crosshair (XOR pixels), `+`/`-` halve/double `step`, Space recompute+colorize (row-by-row reveal is inherent to the compute+fill order), `j` toggle Julia (set `jcr/jci`=center), `q` → `gfx_exit()` + restore tty + exit. For Julia, `mandel_iter` uses fixed `jcr/jci` as `c` and the pixel coordinate as `z0`.
- [ ] **Step 2: Failing test (scripted keystrokes → oracle-tied zoom)** — inject `+` then Space (one zoom step centered), then dump `itbuf`; golden = host reference for the zoomed params (compute the zoomed `cr0/ci0/step` and hash via `tools/fractal-ref`). Keystroke injection is headless per FGX kernel support.

```json
// tools/mame_test/tests/fractal_zoom.json
{
  "binary": "fractal", "args": [],
  "keys": ["+", " "],
  "memory_regions": [{"name":"itbuf","symbol":"itbuf","len":64000}],
  "expect": { "memory": [{"name":"itbuf","sha256":"HOST_REF_ZOOM1"}] }
}
```

Generate `HOST_REF_ZOOM1` from `tools/fractal-ref` with the post-zoom params and paste it in.

- [ ] **Step 3: Run, expect FAIL**, then debug until the on-device zoom matches the host oracle.
- [ ] **Step 4: Verify**

```bash
./build.sh disk && cd tools/mame_test && python3 run.py fractal_zoom
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/userland/fractal/fractal.c tools/mame_test/tests/fractal_zoom.json
git commit -m "feat(fractal): interactive pan/zoom/Julia controls (oracle-tied zoom test)"
```

---

### Task 8: Ship tier-2 — man page, build wiring, gate

**Files:**
- Create: `man/man1/fractal.1` (or repo's man layout — match `man/` convention)
- Modify: `build.sh` (move `fractal` from test-only to the shipped userland list; keep `gfxprobe` in the test-only section)
- Modify: the gate test battery list to include `fractal_compute`, `fractal_render8`, `fractal_zoom`

**Interfaces:** none new.

- [ ] **Step 1: Write `fractal.1`** — synopsis, key bindings, the fixed-point/255-iter/8.24 limits, "3200-color in tier-3" note. ASCII only.
- [ ] **Step 2: Wire build + gate** — ensure `./build.sh disk` stages `fractal`; add the three tests to the fast/gate group.
- [ ] **Step 3: Run the fast group**

```bash
cd tools/mame_test && python3 run.py --group fast
```
Expected: existing count + 3 new, all green.

- [ ] **Step 4: Commit**

```bash
git add man/ build.sh tools/mame_test/
git commit -m "feat(fractal): tier-2 ship - man page, build wiring, gate coverage"
```

---

### Task 9: Tier-3 scanline-IRQ palette engine (`gfx_show`/`gfx_hide`)

The one hand-asm piece. 200 per-line palettes reloaded via VGC scanline interrupt.

**Files:**
- Create: `toolchain/lib/libfgx_scanirq.s` (hand-asm IRQ handler + install/remove) OR add to `libfgx.s` build list in `build.sh:312`
- Modify: `toolchain/lib/libfgx_c/libfgx.c` (`gfx_show`/`gfx_hide` install/remove + per-line table), `toolchain/lib/libfgx_data.s` (200×16×2 palette table)
- Modify: `gfx_set_line_palette` — add tier-3 path (write into the per-line table instead of SCB band)
- Create: `tools/mame_test/tests/gfxprobe_3200.json`

**Interfaces:**
- Consumes: `gfx_enter`.
- Produces: `gfx_show()` installs the scanline-IRQ handler (VGC int via `$C023`/`$C032`/`$C034`) that, each scanline, copies that line's 16-color palette from the table into palette slot 0; `gfx_hide()` removes it. When shown, `gfx_set_line_palette(line, ...)` targets `table[line]` (H=1).

- [ ] **Step 1: Author the IRQ handler inline** — enable VGC scanline interrupt, per-line handler reloads 32 bytes into `$E19E00` (palette 0), ack `$C034`, chain/RTI. All SCBs select palette 0. Handle the top-of-frame reset (line 0 palette) via VBL or line-0 int.
- [ ] **Step 2: Failing test** — `gfxprobe.c` "p3200" mode: `gfx_enter`; `gfx_show`; set a distinct 16-color palette per line (e.g. `table[line]=grad ramp shifted by line`); `gfx_fill_row` a vertical index ramp; dump `shr` + the per-line `paltab` region. Golden `RECORD_ME`.

```json
// tools/mame_test/tests/gfxprobe_3200.json
{
  "binary": "gfxprobe", "args": ["p3200"],
  "memory_regions": [
    {"name":"shr","addr_hex":"E12000","len":32000},
    {"name":"paltab","symbol":"gfx_paltab","len":6400}
  ],
  "expect": { "memory": [
    {"name":"shr","sha256":"RECORD_ME"},
    {"name":"paltab","sha256":"RECORD_ME"}
  ]}
}
```

- [ ] **Step 3: Run, expect FAIL**; implement until the palette table + framebuffer are correct. Because 3200-color renders correctly in MAME, the SHR-region hash reflects the true per-line display.
- [ ] **Step 4: Visual check, then record**

Dump to PNG, confirm 200 visibly distinct per-line palettes, then:
```bash
./build.sh disk && cd tools/mame_test && python3 run.py gfxprobe_3200 --update-goldens && python3 run.py gfxprobe_3200
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add toolchain/lib/ toolchain/include/fgx.h src/userland/gfxprobe/gfxprobe.c tools/mame_test/tests/gfxprobe_3200.json build.sh
git commit -m "feat(gfx): tier-3 scanline-IRQ palette engine (true 3200-color)"
```

---

### Task 10: `fractal` tier-3 render + final gate

**Files:**
- Modify: `src/userland/fractal/fractal.c` (add `--render3200`; interactive display uses `gfx_show`+`colorize(1)`)
- Create: `tools/mame_test/tests/fractal_render3200.json`

**Interfaces:**
- Consumes: `gfx_show`, `colorize(1)`.
- Produces: tier-3 display path; default interactive mode uses it.

- [ ] **Step 1: Wire `colorize(1)` + `gfx_show`** into the display path (H=1 → 200 per-line palettes). Interactive `q` calls `gfx_hide()` before `gfx_exit()`.
- [ ] **Step 2: Failing test** — `--render3200` full-set view; dump `shr` + `paltab`; golden `RECORD_ME`.

```json
// tools/mame_test/tests/fractal_render3200.json
{
  "binary": "fractal", "args": ["--render3200"],
  "memory_regions": [
    {"name":"shr","addr_hex":"E12000","len":32000},
    {"name":"paltab","symbol":"gfx_paltab","len":6400}
  ],
  "expect": { "memory": [
    {"name":"shr","sha256":"RECORD_ME"},
    {"name":"paltab","sha256":"RECORD_ME"}
  ]}
}
```

- [ ] **Step 3: Run FAIL → visual check → record goldens** (as Task 6/9).
- [ ] **Step 4: Full gate**

```bash
cd tools/mame_test && python3 run.py --group fast
```
Expected: all green including `fractal_render3200`.

- [ ] **Step 5: Commit**

```bash
git add src/userland/fractal/fractal.c tools/mame_test/tests/fractal_render3200.json man/
git commit -m "feat(fractal): tier-3 true 3200-color render + final gate coverage"
```

---

## Self-review notes

- **Spec coverage:** gfx layer (T2-4,9), fixed-point compute 8.24 + single-bank buffer (T5), range-fit `H`-parameterized colorize (T6 H=8, T10 H=1), mode switch (T2), controls incl. Julia + row-reveal (T7), mode-switch/testing incl. host oracle (T1,5) and MAME 3200 hash (T9,10), man page + ship (T8). NCR + smooth-coloring correctly ABSENT (deferred in spec).
- **Type consistency:** `gfx_*` signatures defined once in fgx.h (T2 Step 1) and used unchanged; `fixmul32(long,long)->long` on FGX vs host `fix_mul(int32_t,int32_t)` reference (intentional: fcc has no int64) — both implement `(a*b)>>24` and are cross-checked in T5.
- **Open confirmations for the implementer (resolve in-task, not blockers):** (a) exact console full-repaint entry symbol in `src/drivers/console/` for `gfx_exit`; (b) whether `run.py` memory_regions accept a `symbol` key or need a resolved `addr_hex` (T5/T9/T10 — resolve from the tool map if symbol unsupported); (c) exact `--group`/gate-list mechanism name in `tools/mame_test/`.
