# 2.11BSD stdio: the design

The 2026-10-23 profile (`2026-10-23-performance-profile.md`) found FGX's stdio
to be the largest single cost in every text tool: `getc` and `putc` are chains
of four or five calls through a slot table (`stdio_core.c`), where 2.11BSD has
a macro on `struct _iobuf`.  The chain is 56% of `grep`, 70% of `wc` and 76%
of `tr`.  This campaign replaces it with 2.11BSD's stdio.

## 1. The source

| piece | upstream |
|---|---|
| `<stdio.h>` | `examples/2.11BSD/usr/include/stdio.h` (5.3, 3/15/86) |
| `_filbuf`, `_flsbuf`, `fflush`, `fclose` | `usr/lib/libc/stdio/filbuf.c`, `flsbuf.c` |
| `_iob`, `_findiop`, `_f_morefiles`, `_fwalk`, `_cleanup` | `findiop.c` |
| `fopen`, `fdopen`, `freopen`, `fread`, `fwrite`, `fgets`, `fputs`, `gets`, `puts`, `getw`, `putw`, `fgetc`, `fputc`, `getchar`, `putchar`, `ungetc`, `fseek`, `ftell`, `rewind`, `clearerr`, `setbuf`, `setbuffer`, `setlinebuf`, `setvbuf` | the same directory, one file each |
| `printf`, `fprintf`, `sprintf`, `vfprintf`, `vprintf`, `vsprintf` | the same directory; they call `_doprnt(fmt, args, iop)` |
| `_doprnt` | 2.11BSD's is `pdp/stdio/doprnt.s`.  FGX's `printf.c` engine is already a transcription of it (its header says so); it becomes `_doprnt`, emitting through `putc` into the FILE |
| `scanf`, `fscanf`, `sscanf`, `_doscan` | `scanf.c`, `doscan.c` |
| `exit` | `exit.c`: `_cleanup(); _exit(code);` |
| `popen`, `pclose` | `usr/lib/libc/gen/popen.c` |
| `getpass` | `usr/lib/libc/gen/getpass.c`, which makes its stream unbuffered with `setbuf(fi, NULL)` |

## 2. Where the table lives

libc's per-process cells are absolute addresses in each program's own data
bank (`core_layout.s`: `stdin EQU $F773`, `errno EQU $F80D`), so `_iob` in the
core is addressed directly by tool code: `getchar()` is a decrement and a
load on a DBR-relative cell, with no call.  `_iob[]` replaces
`_libc_FILE_table` and the three far-pointer cells `stdin`/`stdout`/`stderr`;
those become 2.11BSD's macros `(&_iob[0])` and so on.

`NSTATIC` is 2.11BSD's 20; `_f_morefiles` grows the table past it as
upstream does.  At 15 bytes an entry the table is about the size of the
cells it replaces (`_lc_buf`, `_lc_bpos`, ..., `_lc_wbuf`, printf's 64-byte
staging buffer).

## 3. Behavior that changes, and why it is upstream's

* **A terminal read is buffered.**  `_filbuf` buffers any read stream; the
  FGX rewrite kept terminals at one byte per `read(2)` for `getpass`.
  2.11BSD's `getpass` unbuffers its own stream with `setbuf(fi, NULL)`.
* **stdout is line-buffered on a terminal, fully buffered otherwise; stderr
  is unbuffered**, with `fprintf`/`fputs`/`vfprintf` borrowing a stack
  `localbuf` and flushing once, as upstream does.
* **`exit` flushes every open stream** through `_cleanup`.

## 4. What landed, and how it differs from the plan

Increments 1 and 2 of the plan were one change: every function that touches
a FILE moves with the table, so nothing could be split off.

* **Every stdio member is 2.11BSD's file** (`toolchain/lib/libc_c/`, one per
  upstream file, `docs/PROVENANCE.md` rows), most verbatim in the body.
* **`_doprnt` is FGX's transcription of `doprnt.s`**; it stages its output
  64 bytes at a time and hands it to the FILE with `fwrite`.
* **An unbuffered stream borrows BUFSIZ on the stack**, in `fprintf`,
  `vfprintf` and `fputs`, as upstream does; the linker's stack measure
  holds it.
* **`printf` returns the count**, as 2.11BSD's own `vfprintf` does and as
  2.11BSD's `more.c` and finger's `lprint.c` use it.
* **`sscanf` builds upstream's `_IOSTRG` FILE**, and `doscan.c` loses the
  delta that stood in for it.
* **`exit` is upstream's** (`_cleanup(); _exit(code);`) and crt0 calls it
  with main's value.  The flush hook that kept stdio out of programs that
  never print is gone: with per-function linking, a static binary that
  never prints grows 145 bytes (`sh` 1,929), and one that prints shrinks
  70 to 154.
* **`sprintf`, `vsprintf` and `popen` are upstream's**; `snprintf` and
  `vsnprintf` keep the engine's buffer mode (netbsd-0-9's interface).
* `sbuf` is pinned in the core: `_smallbuf`'s initialiser takes its address.

The port found a compiler defect: `*(q)->p = c` stored into `q->p`
(fixed separately, M37/derefparen).  2.11BSD's `putc` line-buffered arm is
that shape, and every character written to a terminal was lost.

## 5. Measured

| workload | before (frames) | after | |
|---|---:|---:|---:|
| `tr a-z A-Z` | 3,229 | 925 | 3.5x |
| `wc` | 1,849 | 601 | 3.1x |
| `grep -c the` | 1,753 | 817 | 2.1x |
| `sed s/the/THE/g` | 2,353 | 1,453 | 1.6x |
| `compress -c` | 4,465 | 3,253 | 1.4x |
| `od -c /bin/cat` | 709 | 769 | 0.92x |
| `ls -l /bin` | 517 | 529 | 0.98x |

`od` and `ls` print through `fputs`/`fputc`, which are `putc` per character
on a far FILE pointer, and fcc rebuilds that pointer for every field it
touches.  That is the next item.

## 6. The compiler work that followed

| change | od | wc | tr | grep | ls |
|---|---:|---:|---:|---:|---:|
| after the port | 781 | 601 | 925 | 817 | 529 |
| a member of `_iob[k]` read and written at its address (ebfc6de) | 697 | 601 | 637 | 697 | 553 |
| a big frame's parameters copied near S; `++`/`--` through the register (7dd9e39) | 649 | 565 | 625 | 685 | 541 |
| a pointer already in its register not loaded again; `x >= 0` as `CMP #0` (77c0d19) | 625 | 541 | 613 | 685 | 529 |

Holding a FILE pointer in a direct-page pair for a whole function is still
open: any call other than a runtime helper reuses the pair, and getc and putc
call `_filbuf`/`_flsbuf` on their slow arms.  With the reloads above gone, it
would save the first load in each block.

## 7. 4.3BSD-Reno's doprnt.c (cba4071)

`_doprnt` is Reno's doprnt.c (5.39), writing into the FILE's buffer; its
deltas are in the file's header.  `ls -l /bin` 529 -> 505 frames.  libc.so
grew 4,940 bytes, most of it fourteen expansions of the putc macro, which
fcc compiles to about 700 bytes each.  The port found two compiler defects
(db33004): type specifiers out of order, and an index that calls a function
losing its base pointer's bank.

## 8. The putc expansion (758ec75, a7ff800, ad0fb31)

One putc on a FILE parameter measured 337 bytes.  Three passes over fcc's
output took it to 314, and took 188.6 KB out of the staged system, with no
file larger than before:

- far branches whose target is in reach become short ones (36,000 pairs;
  144 KB; libc.so -8,755 bytes);
- the allocator's `TAX ; TXA' keeps the TAX, and `CMP #0' after an op that
  set N and Z from A goes when the carry is dead on every path (44.6 KB).

Reading the expansion found a defect: the value of an assignment to a char
was A's whole word, so putc returned its argument rather than the byte it
wrote (K&R A.7.17).  A used char store now masks A, which gives back 1.2 KB.

What is left in the expansion is codegen, not peephole: the FILE pointer is
reloaded from the frame on each arm of the ternaries (six loads, 48 bytes),
because the fpr hold record clears at every label; `(p)->_ptr++' copies the
pointer through _fcc_tmp_b and _fcc_ptr+2 where a second fpr would hold it;
and the `&&' in the line-buffered test is materialized as 0/1 and then
tested.

## 9. Next

The putc codegen above -- a hold record that survives a label every branch
to which it has seen, the post-increment through a second fpr, and `&&' as
branches in a condition -- then a profile of ls and printf for inline asm on
what it finds.
