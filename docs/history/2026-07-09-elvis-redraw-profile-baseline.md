# Elvis redraw profiler baseline (the Phase-0 measure, taken 2026-07-09)

The architecture-redesign's Phase-0 asked for a "profiler baseline on an
elvis redraw (attributes the slow-render pathology between
fcc-runtime/libc/kernel-console)".  It was never taken; this is it.

## Method

`tools/mame_test/tests/vi_profile_baseline.json` (+ `vi_profile_b90.json`):
boot the HELD `disk/vi.po` image (pre-P3 elvis + its kernel — the correct
baseline), `vi /etc/hostname`, `pc_sample: true` (fgxdebug histograms PC
once per frame while the command runs).  The initial render needs no
keystrokes (headless-safe); vi then sits interactive until timeout.

Two windows (45 s and 90 s) separate phases without timestamps: the extra
45 s of the long run is PURE idle, so per-PC differencing yields the idle
signature; dropping it from the 45 s run leaves the ACTIVE
(startup + first render) window.

## Results

- Idle = ONE PC: `7D:84CE` (65.7% @45 s → 82.8% @90 s — the kernel key-poll
  loop).  Everything below is the active window (928 samples).

| Where | Share | Reading |
|---|---|---|
| `$00:C9A5–C9BA` (bank-0 expansion-ROM space) | **41.2%** | slot **disk firmware** — vi's startup temp-file I/O (tmpstart) |
| kernel bank (`7D:BF79`, `7D:5466` hot) | 24.9% | FS/syscall work (no console-render cluster) |
| elvis code banks ($70/6F/61/6A/6E/6D) | **33.8%** | elvis-internal compute ($70:6DBx hottest) |

## Conclusions (vs the RESUME's held theories)

1. **"Slow-render is NOT console perf" — CONFIRMED.**  No console-render
   hotspot appears anywhere in the active window.
2. **Refinement: the startup stall is disk-I/O-heavy** — the single
   largest active cost is slot firmware block I/O, consistent with the
   RESUME's temp-file (tmpstart) story.  Elvis-internal compute is second
   (~34%), kernel FS/syscall third.
3. When vi work resumes: attack order = temp-file I/O volume (why does
   tmpstart hit the disk this hard — block size? sync-per-write from the
   task-#55 crash-safety work?), then the `$70:6DBx` elvis hot loop.

## Caveats

- `$00:C9xx = disk firmware` is inferred from the address space
  (peripheral-card expansion ROM), not symbol-verified.
- The old kernel's `$7D` offsets are unmapped (vi.po's build listing was
  not retained); `BF79`/`5466` are unidentified kernel routines.
- 60 Hz frame sampling is coarse (928 active samples); the window includes
  jsh spawn overhead.
- Numbers are for the HELD pre-P3 image; the post-P3 world (hardware
  stack, shared libc) will shift them — re-run after the release train.
