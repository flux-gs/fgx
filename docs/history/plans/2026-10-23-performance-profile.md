# The whole-system profile of 2026-10-23, and what it changed

Companion to `2026-09-09-performance-dive-results.md`.  That dive profiled
short, exec-heavy jobs and closed with "the seams are exhausted".  This one
profiled one tool at a time on a 93 KB input, attributed every sampled bank,
and found the time where the earlier workloads could not show it: in the C
library and in the compiler's output, and in the write path the earlier
workloads barely touched.

## 1. Method

* MAME, headless, `FGX_MAME_PRIMARY=inject`, 7 MHz (a stock IIgs is about
  2.5x slower on CPU-bound work).  `pc_sample` at a prime 1,009 us period,
  decoupled from the frame.
* One tool per workload.  Input `/usr/man/cat1/tcsh.1` (93,361 bytes); output
  redirected to `/tmp` except the console workload.
* Every bank attributed: kernel, far and tty by the dump's `kernel_bank`; the
  loaded modules through `_modBankTab`; `libc.so`'s four banks from the boot
  log's `ldload: libc.so.1.0: banks` line; a tool's packed text by
  byte-matching the dumped bank at its hottest offsets against every
  `tools/*/*.ld/seg0` image.
* Frame counts below have the command's length subtracted: inject types one
  character per frame and the sampler arms before the typing.  The exit check
  polls every 12 frames.

## 2. The baseline, main cc6f2a5 (v2.2.0)

| workload | seconds | tool | libc | kernel | fs modules | disk (card ROM) |
|---|---:|---:|---:|---:|---:|---:|
| `compress -c` | 74.5 | 57% | 31% | 6% | 2% | 2% |
| `tr a-z A-Z` | 55.1 | 8% | 76% | 7% | 4% | 5% |
| `sed s/the/THE/g` | 39.8 | 36% | 42% | 9% | 5% | 7% |
| `head -200` to the console | 34.9 | 2% | 0% | 80% | 15% | 1% |
| `wc` | 30.6 | 11% | 74% | 8% | 3% | 3% |
| `grep -c the` | 29.1 | 24% | 60% | 9% | 3% | 3% |
| `od -c /bin/cat` | 13.6 | 21% | 54% | 13% | 5% | 6% |
| `tcsh -c true` x3 | 12.9 | 6% | 6% | 28% | 28% | 30% |
| `ls -l /bin` | 9.7 | 4% | 43% | 19% | 28% | 5% |
| `cp` / `cat` to a file | 5.7 | 2% | 0% | 31% | 27% | 39% |
| `true` x10 | 2.1 | 11% | 3% | 68% | 13% | 4% |

## 3. What it found, largest first

1. **stdio is not 2.11BSD's.**  `getc` and `putc` are chains of four or five
   calls (`fgetc` -> `__lc_fent`/`__lc_slot`/`__lc_bufidx`/`__lc_getcb`/
   `__lc_bptr`; `__lc_wputc`/`__lc_wslot`) where 2.11BSD has a macro on
   `struct _iobuf`'s `_cnt` and `_ptr`.  The chain is 56% of `grep`, 70% of
   `wc`, 28% of `compress`.  Next campaign.
2. **`head` and `cat` wrote a byte per `write(2)`.**  Both were hand rewrites.
3. **No saved text.**  2.11BSD's `vm_text.c`: "all text under 2.10 is sticky
   in an LRU cache".  FGX reads every binary again on every exec;
   `tcsh.bin` is 490,607 bytes.
4. **Every block a file grew by was written twice.**  `ufs_bmapx` zeroed each
   new data block on the disk before `ufs_write` wrote it; 2.11BSD's `bmap`
   does that for indirect blocks and directories only.
5. **`ls -l` spent 22% converting dates.**  `timesub` walks every year since
   1970 through `isleap`, whose `y % 4` fcc sent to `_fcc_mods16`, a
   sixteen-step division in memory.
6. **fcc's output.**  Across the tree: 23,813 `Bxx *+5 / BRL` pairs, 4,876
   redundant `CMP #0`, constants passed through `_fcc_tmp_b` (45,574
   references), 2,531 `_fcc_long_from_int` of a constant.

Two findings were not performance: `fstat` on an unused pipe crashed the
machine (found because 2.11BSD `cat` fstats its stdin), and the runtime
fixture `M37/miscops` never reports (flux-gs/fgx#31, pre-existing).

## 4. What landed, on perf/quick-wins

| change | measured (frames) |
|---|---|
| `head`, `cat`: the 2.11BSD sources | console `head -200`: 2,137 -> 589 |
| ufs: a plain file's new data block is not zeroed on the disk first | `cp`: 385 -> 313 |
| fcc: signed `% 2^k` inline | `ls -l`: 613 -> 565 |
| runtime: one division core per width, short paths for small numbers | `od`: 901 -> 733 (larger input); `ls -l` -> 529 |
| peephole: constants used directly, not through `_fcc_tmp_b` | `cmp` 289 -> 265, `sed` 2,449 -> 2,353, `grep` 1,801 -> 1,753 |

The peephole work cut the tree's fcc output by 2.4% and gave the far and tty
kernel banks 1,322 and 1,805 bytes of room.

## 5. What is next

* **The 2.11BSD stdio port.**  The single largest lever for every text tool.
  `getc` compiled by fcc from 2.11BSD's macro is about 93 instructions today;
  much of that is fcc failing to fold `&_iob[0]`, comparing `--cnt >= 0` by
  a signed subtract with an overflow fix-up, and rebuilding the FILE pointer
  for each field.  Those are compiler items to take with the port.
* **Saved text** (2.11BSD `vm_text.c`), for exec and boot.
* **fcc**: branch relaxation (`Bxx *+5 / BRL`), the redundant `CMP #0`,
  constant long operands.
