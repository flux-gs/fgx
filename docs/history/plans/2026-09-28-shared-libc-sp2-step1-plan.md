# Shared libc SP2 step 1: libc's hand-written parts -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shrink libc's hand-written code and fixed data prefix to what 2.11BSD
would have in assembly plus the true per-process core, under today's piles,
so every program's fixed data prefix loses roughly 2 KB.

**Architecture:** Six independent landings on `feat/shared-libc`: delete what
nothing references (proved by a new checker), port `strerror` from 2.11BSD C
behind a `syserrlst()` table, move the termcap tables to termlib, move three
syscall argument blocks and `sys_envp` to the C code that owns them, port the
real 2.11BSD `cal`, then measure and gate.

**Tech Stack:** Merlin32 65816 assembly (`toolchain/lib/*.s`), fcc K&R C
(`toolchain/lib/libc_c/*.c`), Python 3 build tools (`tools/`, `tools/ninja/gen.py`),
ninja, the MAME harness (`tools/mame_test/run.py`), `tools/gate.sh`.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`, sections 5
and 7 item 1.  Umbrella: `docs/history/plans/2026-09-28-shared-libc-design.md`.

## Global Constraints

- ASCII only in every FGX file (no em-dashes, no curly quotes).
- Source comments describe the current state only: no "this used to be", no
  dated measurements, no tombstones for deleted code.
- Commit bodies are informational, name the BSD file a change follows, carry
  no names/CI/follow-ups, and end with the two trailer lines:
- Read the 2.11BSD counterpart before changing a libc function; name it in
  the commit.  Vendored sources stay verbatim.
- Toolchain-first: if fcc rejects 2.11BSD source, fix fcc, never the source.
- MAME runs headless via `python3 tools/mame_test/run.py --fresh <names>`
  (never a raw `mame64`).  A verdict marked "(1 cached)" did not run.
- Never `git checkout` a generated file (`src/modules/klog/kernel_exports.s`);
  never `ninja -t clean`.
- Announce every rebuild of the tree; the branch stays `feat/shared-libc`,
  not pushed.
- Nothing is added to the gate; new manifests are probes run by name.
- `libc_data.s` label order is not ABI (every binary relinks), but
  `_libc_lstrBufA/B`, the FILE table, `errno`, the signal and vfork cells,
  `args_data.s` and `fcc_runtime_data.s` stay (spec section 5: core).

## Review Focus

1. A label the checker calls dead but that an assembler `PUT` chain or a
   fixture reaches by name -- the build must still assemble every fixture
   (`toolchain/tests/M*/`) and `tools/fas`; Task 1's gate run covers it.
2. `strerror` for an errno with no message (e.g. 0, 99, -1) -- upstream
   prints `Unknown error: <n>`; Task 2's probe asserts it.
3. A tool that links termlib but whose seg1 no longer carries the tables
   (elvis, tcsh, bsh build their own link files) -- Task 3 builds all three
   and runs `tctest` and `vi`'s smoke.
4. `select(2)`/`sysctl(2)`/socket calls from a tool whose argument block now
   lives in the member's data, not the fixed prefix -- the kernel reads it
   through the caller's DBR, so it must still be in the data bank; Task 4
   runs `ptysrsel`, `securelevel` and `telnet_loopback`.
5. `cal` with no arguments now prints upstream's usage instead of a
   calendar -- a behaviour change users will see; Task 5's commit and
   manifest state it.

---

### Task 1: Delete what nothing references

**Files:**
- Create: `tools/check_libc_data.py`
- Modify: `toolchain/lib/libc_data.s` (delete dead labels),
  `toolchain/lib/fcc_runtime_data.s` (delete `_fcc_long_mods_dvr_lo/hi`,
  `_fcc_long_mods_q_lo/hi`), `toolchain/lib/libc.s` (delete
  `_libc_alloc_FILE`, `_libc_FILE_to_fd`; rewrite the header comment),
  `toolchain/Makefile` (`test-archives` runs the checker)
- Delete: `src/userland/tput/tput.s` (a stale fcc output from July; tput
  builds from `tput.c`)

**Interfaces:**
- Produces: `python3 tools/check_libc_data.py` (exit 0 = no dead label;
  prints each dead label and its file otherwise) and
  `python3 tools/check_libc_data.py --self-test`.  Tasks 2-5 run it after
  their own deletions.

- [ ] **Step 1: Write the checker with its self-test**

```python
#!/usr/bin/env python3
"""check_libc_data.py - every label libc's hand-written data defines is used.

The fixed data prefix (toolchain/lib/libc_data.s, args_data.s,
fcc_runtime_data.s) is PUT into every program's data segment, so a label
nothing references still costs every process its bytes.  A label is live if
code outside the three files names it, or if a live label's own definition
names it (a table of pointers keeps its strings alive).  Comments do not
count: `;' to end of line and `*' in column 1 in assembly, /* */ and // in C.

Run: python3 tools/check_libc_data.py [--self-test]
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = ["toolchain/lib/libc_data.s", "toolchain/lib/args_data.s",
        "toolchain/lib/fcc_runtime_data.s"]
LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")
DIRECTIVE = re.compile(r"\b(EQU|MAC|ENT)\b")
SKIP = re.compile(r"^(docs|vendor|examples)/|^tools/[a-z0-9_]+-fgx2/")


def strip_asm(text):
    out = []
    for line in text.splitlines():
        if line.startswith("*"):
            continue
        out.append(line.split(";", 1)[0])
    return "\n".join(out)


def strip_c(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    return re.sub(r"//[^\n]*", " ", text)


def strip(path, text):
    return strip_asm(text) if path.endswith(".s") else strip_c(text)


def definitions(files):
    """{label: (file, body text)} for every storage label in `files`."""
    defs = {}
    for path, text in files.items():
        cur = None
        for line in text.splitlines():
            m = LABEL.match(line)
            if m and not DIRECTIVE.search(line):
                cur = m.group(1)
                defs[cur] = (path, [])
            if cur:
                defs[cur][1].append(line.split(";", 1)[0])
    return {k: (f, "\n".join(b)) for k, (f, b) in defs.items()}


def dead_labels(data_files, other_files):
    defs = definitions(data_files)
    others = {p: strip(p, t) for p, t in other_files.items()}

    def named_in(label, text):
        return re.search(r"(?<![A-Za-z0-9_])" + re.escape(label)
                         + r"(?![A-Za-z0-9_])", text) is not None

    live = {n for n in defs if any(named_in(n, t) for t in others.values())}
    grew = True
    while grew:
        grew = False
        for n in defs:
            if n not in live and any(named_in(n, defs[m][1]) for m in live):
                live.add(n)
                grew = True
    return sorted((defs[n][0], n) for n in defs if n not in live)


def repo_files():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True,
                         text=True, check=True).stdout.split()
    files = {}
    for p in out:
        if SKIP.search(p) or not re.search(r"\.(s|c|h|in|py)$", p):
            continue
        if p in DATA or p == "tools/check_libc_data.py":
            continue
        with open(os.path.join(ROOT, p), errors="ignore") as f:
            files[p] = f.read()
    return files


def self_test():
    data = {"d.s": "used    DS 2\ntable   DA used_str\nused_str ASC 'x'\n"
                   "orphan  DS 2\nstr2    ASC 'y'\n"}
    other = {"a.s": " LDA used\n LDA table ; orphan in a comment\n",
             "b.c": "/* orphan */ int x;\n"}
    got = [n for _, n in dead_labels(data, other)]
    assert got == ["orphan", "str2"], got
    print("check_libc_data: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    data = {}
    for p in DATA:
        with open(os.path.join(ROOT, p)) as f:
            data[p] = f.read()
    dead = dead_labels(data, repo_files())
    for path, n in dead:
        print("check_libc_data: %s: %s is referenced by nothing" % (path, n))
    if dead:
        print("check_libc_data: %d dead label(s)" % len(dead), file=sys.stderr)
        return 1
    print("check_libc_data: clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the self-test, then the real check, and watch it go red**

Run: `python3 tools/check_libc_data.py --self-test && python3 tools/check_libc_data.py | tail -3; echo rc=$?`
Expected: `check_libc_data: self-test OK`, then about 90 `is referenced by
nothing` lines (the `pf_*`, `atoi_*`, `atol_*`, `itoa_*`, `fopen_*`,
`freopen_*`, `fio_*`, `fseek_off_*`, `sys_pathSh`, `sys_argv*`,
`sys_status`, `libc_args_hi`, `sys_envp_off`, `_libc_perror_*` cells in
`libc_data.s` and the four `_fcc_long_mods_dvr/q` cells), and a non-zero
exit.  Save the list:
`python3 tools/check_libc_data.py > $SCRATCH/dead1.txt` (use the session
scratchpad).

- [ ] **Step 3: Delete each listed label's definition line and its comment block**

For every label in `$SCRATCH/dead1.txt`, delete its line in the named file,
and any comment block that describes only deleted labels.  Keep `fopen_fp`,
`fseek_whence`, `_se_want` and any label the checker did not list.  Also
delete `_libc_alloc_FILE` and `_libc_FILE_to_fd` from `toolchain/lib/libc.s`
(no callers: `grep -rn "_libc_alloc_FILE\|_libc_FILE_to_fd" toolchain src`
shows only their definitions), then re-run the checker: those routines were
the last users of `fopen_fp` and `fseek_whence`, which it will now list; delete
them too.  `git rm src/userland/tput/tput.s`.

- [ ] **Step 4: Rewrite `libc.s`'s header comment to what the file holds**

Replace lines 1-~100 of `toolchain/lib/libc.s` (the header describing
retired string/ctype/printf routines, up to the first `MAC`) with:

```
;==============================================================================
; libc.s - the parts of FGX's libc that 2.11BSD also writes in assembly.
;
;   getpid          syscall stub (2.11BSD lib/libc/pdp/sys, generated)
;   vfork           frameless by necessity (2.11BSD lib/libc/pdp/sys/vfork.s)
;   setjmp/longjmp  save and restore the machine state
;                   (2.11BSD lib/libc/pdp/gen/setjmp.s)
;
; Everything else in libc is C, in toolchain/lib/libc_c.  Each routine is
; entered by JSL and returns by RTL with DBR = the caller's data bank, where
; its cells in libc_data.s live.
;==============================================================================
```

Keep every `EQU`/`MAC` definition that follows it; delete retired-routine
tombstone comments ("RETIRED (T5-C orphan sweep)", "(Retired) vi-port slice
4") -- comments describe the current state only.  `_libc_strerr` and
`today_init` stay until Tasks 2 and 5.

- [ ] **Step 5: Wire the checker into `make test-archives`**

In `toolchain/Makefile`, under `test-archives:`, add after the
`test_lib_boundary.py` line:

```
	python3 ../tools/check_libc_data.py --self-test
	python3 ../tools/check_libc_data.py
```

- [ ] **Step 6: Rebuild and check green**

Announce: "rebuilding the tree on feat/shared-libc".
Run: `python3 tools/ninja/gen.py >/dev/null && ninja > $SCRATCH/t1.log 2>&1; echo rc=$?; grep -E "^FAILED|rror" $SCRATCH/t1.log | head; (cd toolchain && make -s test-archives 2>&1 | tail -4)`
Expected: `rc=0`, no FAILED lines, `check_libc_data: clean`.

- [ ] **Step 7: Machine smoke**

Run: `python3 tools/mame_test/run.py --fresh statenoent catsmoke killprobe`
Expected: `3 passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
git add tools/check_libc_data.py toolchain/lib/libc_data.s toolchain/lib/fcc_runtime_data.s toolchain/lib/libc.s toolchain/Makefile
git rm -q --cached src/userland/tput/tput.s 2>/dev/null; git add -A src/userland/tput
git commit -F - <<'EOF'
chore(libc): delete the hand-written cells and routines nothing uses

The fixed data prefix every program carries held the state of the
hand-written printf, atoi/atol/itoa, fopen/freopen/fseek and system()
that C members replaced long ago; nothing names those cells, and the
FILE-table helpers _libc_alloc_FILE and _libc_FILE_to_fd had no callers.
tools/check_libc_data.py, in `make test-archives', fails on any label in
libc_data.s, args_data.s or fcc_runtime_data.s that code does not name.
libc.s now says what it holds: getpid, vfork and setjmp/longjmp, the
routines 2.11BSD also writes in assembly (lib/libc/pdp).  The stale
src/userland/tput/tput.s goes; tput builds from tput.c.

EOF
```

### Task 2: strerror from 2.11BSD C, with `syserrlst()`

**Files:**
- Modify: `toolchain/lib/libc_c/strerror.c` (2.11BSD
  `lib/libc/string/strerror.c` body), `toolchain/lib/libc.s` (delete
  `_libc_strerr`), `toolchain/lib/libc_data.s` (delete `_se_want`,
  `_libc_strerr_tab`, `_se_*`), `toolchain/lib/libc_c/libc_c.c` (include the
  new member before `strerror.c`), `docs/PROVENANCE.md` (rows)
- Create: `toolchain/lib/libc_c/syserrlst.c`,
  `tools/mame_test/tests/strerrprobe.json`,
  `src/userland/strerrprobe/strerrprobe.c` + its manifest entry

**Interfaces:**
- Produces: `char *syserrlst(int err)` -- the message for `err`, or
  `(char *)0` when there is none (2.11BSD `gen/syserrlst.c`'s contract).

- [ ] **Step 1: Read the sources**

Read `examples/2.11BSD/usr/lib/libc/string/strerror.c` and
`examples/2.11BSD/usr/lib/libc/gen/syserrlst.c` in full, and
`toolchain/include/errno.h`.  Note upstream's `UPREFIX` "Unknown error: " and
that `syserrlst` returns NULL for an unknown number.

- [ ] **Step 2: Write the probe that must go red**

`src/userland/strerrprobe/strerrprobe.c`:

```c
/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* strerrprobe - strerror(3) for a known errno, errno 0 and two numbers with
 * no message.  2.11BSD string/strerror.c answers an unknown number with
 * "Unknown error: <n>" built by hand, unsigned. */
#include <stdio.h>
#include <string.h>
#include <errno.h>

int main()
{
    printf("A[%s]\n", strerror(ENOENT));
    printf("B[%s]\n", strerror(EACCES));
    printf("C[%s]\n", strerror(99));
    printf("D[%s]\n", strerror(1234));
    printf("SEDONE\n");
    return 0;
}
```

Add `{ "name": "strerrprobe" }` to `tools/ninja/manifest.json` beside the
other probes, and its staging entry (`"src": "bin/strerrprobe.bin", "dst":
"disk_src/testbin/strerrprobe"`) beside `tctest`'s.

`tools/mame_test/tests/strerrprobe.json`:

```json
{
 "name": "strerrprobe",
 "description": "strerror(3) is 2.11BSD string/strerror.c over syserrlst(): a known errno gets its message, a number with none gets upstream's hand-built `Unknown error: <n>'.",
 "command": "/testbin/strerrprobe",
 "boot_s": 45,
 "timeout_s": 60,
 "exit_on_prompt": {"sentinel": "fgx#", "count_delta": 1},
 "expect": {
  "screen_contains": ["A[No such file or directory]", "B[Permission denied]",
                      "C[Unknown error: 99]", "D[Unknown error: 1234]", "SEDONE"],
  "screen_lacks": ["PANIC", "BRK"]
 }
}
```

- [ ] **Step 3: Build and run it red**

Announce the rebuild.  Run: `python3 tools/ninja/gen.py >/dev/null && ninja >$SCRATCH/t2a.log 2>&1; python3 tools/mame_test/run.py --fresh strerrprobe`
Expected: FAIL on `C[Unknown error: 99]` and `D[...]` (today's table answers
the bare `Unknown error`), A and B pass.

- [ ] **Step 4: Write `syserrlst.c`**

Messages are the current `_se_*` strings from `libc_data.s` (Reno wording,
kept), indexed by errno value from `toolchain/include/errno.h`; unlisted
numbers are `(char *)0`.  Generate the table rather than retyping it:

```bash
python3 - <<'EOF'
import re
data = open("toolchain/lib/libc_data.s").read()
msgs = dict(re.findall(r"^_se_([a-z0-9]+)\s+ASC\s+'([^']*)'", data, re.M))
errno = dict((n.lower(), int(v)) for n, v in
             re.findall(r"#define\s+(E[A-Z0-9]+)\s+(\d+)", open("toolchain/include/errno.h").read()))
rows = sorted((errno[k], k, v) for k, v in msgs.items() if k in errno)
print("\n".join("    /* %3d E%s */ \"%s\"," % (n, k.upper(), v) for n, k, v in rows))
EOF
```

Check the generated rows against `libc_data.s` by eye (the `_se_*` strings
may use `ASC` with a `DFB 0` terminator or `STR`; adjust the regex to what
the file uses, and confirm every `_se_*` label except `_se_unknown` appears
exactly once).  Then write:

```c
/* ---- syserrlst(3): the message for an error number, or NULL -----------
 * 2.11BSD gen/syserrlst.c reads the messages from /etc/syserrlst to save
 * PDP-11 memory.  FGX keeps the interface and holds the table in libc:
 * the messages are read-only strings, so a shared libc costs no process
 * anything for them.  Wording is 4.3BSD-Reno sys/errno.h's.
 */
static char *_sys_errmsg[] = {
    (char *)0,                          /*   0 */
    /* the generated rows, in errno order, with (char *)0 in every gap */
};
#define _SYS_NERR (sizeof(_sys_errmsg) / sizeof(_sys_errmsg[0]))

char *syserrlst(err)
    int err;
{
    if ((unsigned)err >= _SYS_NERR)
        return (char *)0;
    return _sys_errmsg[err];
}
```

Fill every gap between consecutive errno values with `(char *)0,` so the
array index equals the errno value; the generator's output is sorted, so
insert gap rows while pasting.

- [ ] **Step 5: Replace `strerror.c` with 2.11BSD's body**

```c
/* ---- strerror(3) -----------------------------------------------------
 * 2.11BSD lib/libc/string/strerror.c (8.1.1, 1996/3/15), verbatim body.
 */
char *
strerror(num)
	int num;
{
#define	UPREFIX	"Unknown error: "
	static char ebuf[30] = UPREFIX;		/* 32-bit number + slop */
	register unsigned int errnum;
	register char *p, *t;
	char tmp[20];

	errnum = num;				/* convert to unsigned */
	if (p = syserrlst(errnum))
		return(p);

	/* Do this by hand, so we don't include stdio(3). */
	t = tmp;
	do {
		*t++ = '0' + (errnum % 10);
	} while (errnum /= 10);
	for (p = ebuf + sizeof(UPREFIX) - 1;;) {
		*p++ = *--t;
		if (t <= tmp)
			break;
	}
	return(ebuf);
}
```

In `toolchain/lib/libc_c/libc_c.c`, add `#include "syserrlst.c"` on the line
before `#include "strerror.c"`.  Delete `_libc_strerr` from `libc.s` and
`_se_want`, `_libc_strerr_tab` and every `_se_*` from `libc_data.s`.  If
fcc rejects anything in the verbatim body, fix fcc (toolchain-first),
with a fixture, rather than edit the body.

- [ ] **Step 6: Build, check, run green**

Announce the rebuild.  Run: `(cd toolchain && make -s libc_c lib/libc.fgxa/index.json) && python3 tools/ninja/gen.py >/dev/null && ninja >$SCRATCH/t2b.log 2>&1; echo rc=$?; python3 tools/check_libc_data.py; python3 tools/mame_test/run.py --fresh strerrprobe statenoent`
Expected: `rc=0`, `check_libc_data: clean`, `2 passed, 0 failed`.

- [ ] **Step 7: Positive control**

Temporarily make `syserrlst` return `(char *)0` always; rebuild; run
`strerrprobe`.  Expected: FAIL on `A[No such file or directory]`.  Restore
the function; rebuild.

- [ ] **Step 8: PROVENANCE and commit**

Add rows to `docs/PROVENANCE.md` for `toolchain/lib/libc_c/strerror.c`
(2.11BSD `examples/2.11BSD/usr/lib/libc/string/strerror.c`, verbatim body)
and `toolchain/lib/libc_c/syserrlst.c` (2.11BSD `gen/syserrlst.c` interface;
table in memory, stated divergence).  If `tools/check_provenance.py` needs a
header marker the two files lack, add it.  Run `python3 tools/check_provenance.py`.

```bash
git add toolchain/lib/libc_c/strerror.c toolchain/lib/libc_c/syserrlst.c toolchain/lib/libc_c/libc_c.c toolchain/lib/libc.s toolchain/lib/libc_data.s docs/PROVENANCE.md src/userland/strerrprobe tools/mame_test/tests/strerrprobe.json tools/ninja/manifest.json
git commit -F - <<'EOF'
feat(libc): strerror is 2.11BSD's, over syserrlst()

strerror(3) is 2.11BSD lib/libc/string/strerror.c: the message comes from
syserrlst(), and a number with none gets `Unknown error: <n>' built by
hand, where the assembly table answered a bare `Unknown error'.
syserrlst() keeps 2.11BSD gen/syserrlst.c's interface but holds the
messages in libc rather than reading /etc/syserrlst; the wording is
4.3BSD-Reno's, as before.  The assembly lookup and its table leave the
data prefix every program carries, and only programs that call strerror
link the messages.  strerrprobe covers a known number and two unknown
ones.

EOF
```

### Task 3: The termcap tables move to termlib

**Files:**
- Create: `toolchain/lib/libtermlib_helpers_data.s` (the `tc_*` tables,
  `tc_ansi_*` tables, `_tcStrTbl/_tcNumTbl/_tcFlagTbl`, the `tc_cl`...
  strings, and `pf_tmpByte`, moved verbatim with their comments from
  `libc_data.s`)
- Modify: `toolchain/lib/libc_data.s` (remove them), `tools/ninja/gen.py`
  (`materialize_links`: PUT the helpers in seg3 and their data in seg1 only
  when `termlib` is in `libs`), `tools/fgx2/seg3libs.link.s.in` (helpers PUT
  becomes a substitution), the elvis and tcsh generators and data link files
  (`tools/elvis-fgx2/gen_elvis_link.py`, `tools/elvis-fgx2/dataseg.link.s`,
  `tools/tcsh-fgx2/gen_tcsh_link.py`, `tools/tcsh-fgx2/dataseg.link.s`),
  `tools/sh-fgx2/dataseg.link.s` only if bsh references a moved label
- Create: `tools/mame_test/tests/tcdata.json`

**Interfaces:**
- Produces: `toolchain/lib/libtermlib_helpers_data.s`, PUT into seg1 of
  every link that PUTs `libtermlib_helpers.s`.

- [ ] **Step 1: Pin today's termcap output**

Create `tools/mame_test/tests/tcdata.json` running `/testbin/tctest` with
`"expect": {"screen_contains": ["TCDONE"]}`, run it
(`python3 tools/mame_test/run.py --fresh tcdata`), then copy the `UP = ...`,
`CM = ...` and the five `r c -> ...` lines from the run's screen dump
(`/tmp/fgx_test_tcdata/`) into `screen_contains`.  Re-run: `1 passed`.

- [ ] **Step 2: Find every consumer of the moved labels**

Run: `git grep -nwE "tc_[a-zA-Z_]+|_tc(Str|Num|Flag)Tbl|pf_tmpByte" -- ':!toolchain/lib/libc_data.s' ':!docs' | grep -v "^tools/[a-z0-9]*-fgx2/seg"`
Expected: `toolchain/lib/libtermlib_helpers.s`, `src/userland/more/more.c`
(`tc_cl`), elvis/tcsh link generators.  Every tool in the list must link
termlib (`more` does: `"libs": "termlib"`); a consumer that does not is a
finding -- stop and record it before moving on.

- [ ] **Step 3: Move the data**

Cut the block from `libc_data.s` into `toolchain/lib/libtermlib_helpers_data.s`
with a header:

```
;==============================================================================
; libtermlib_helpers_data.s - the baked termcap entries libtermlib_helpers.s
; reads DBR-relative: the IIgs SHR console ("fgx") and a remote ANSI/vt102
; terminal.  termlib's (2.11BSD libtermlib: tgetent), PUT into the data
; segment of every program that links termlib.
;==============================================================================
```

- [ ] **Step 4: PUT it where the helpers go, and only for termlib users**

In `tools/fgx2/seg3libs.link.s.in` replace the
`PUT ../../toolchain/lib/libtermlib_helpers.s` line with `* @TERMLIB_HELPERS@`.
In `tools/ninja/gen.py` `materialize_links`, where `segs["seg3"]` is built:

```python
        helpers = ("                PUT    ../../toolchain/lib/libtermlib_helpers.s\n"
                   if "termlib" in libs else "")
        segs["seg3"] = segs["seg3"].replace("* @TERMLIB_HELPERS@\n", helpers)
        if "termlib" in libs:
            segs["seg1"] += ("                PUT    "
                             "../../toolchain/lib/libtermlib_helpers_data.s\n")
```

Apply the same `@TERMLIB_HELPERS@` substitution where `seg4` is built from
the same template.  In the elvis and tcsh generators and their
`dataseg.link.s`, add the `libtermlib_helpers_data.s` PUT next to where
`libc_data.s` is PUT (both link termlib).

- [ ] **Step 5: Build, check, run green**

Announce the rebuild.  Run: `python3 tools/ninja/gen.py >/dev/null && ninja >$SCRATCH/t3.log 2>&1; echo rc=$?; grep -E "^FAILED|rror" $SCRATCH/t3.log | head; python3 tools/check_libc_data.py; python3 tools/mame_test/run.py --fresh tcdata manrender`
Expected: `rc=0`; `check_libc_data: clean`; `2 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add toolchain/lib/libtermlib_helpers_data.s toolchain/lib/libc_data.s tools/ninja/gen.py tools/fgx2/seg3libs.link.s.in tools/elvis-fgx2 tools/tcsh-fgx2 tools/mame_test/tests/tcdata.json
git commit -F - <<'EOF'
refactor(libc): the baked termcap entries belong to termlib

The console and remote-ANSI termcap tables are what 2.11BSD's
libtermlib (tgetent) reads, not libc.  They leave the data prefix every
program carries for libtermlib_helpers_data.s, PUT into the data segment
of programs that link termlib; the helpers that read them are PUT into
code only for those programs too.  tcdata pins tctest's output.

EOF
```

### Task 4: Argument blocks and `sys_envp` go to their owners

**Files:**
- Modify: `toolchain/lib/libc_c/socket.c` (define `int _sock_argblk[13];`),
  `socket_srv.c`, `sockopt.c` (declare `extern int _sock_argblk[];`),
  `toolchain/lib/libc_c/select.c` (define `int _sel_argblk[10];`, drop its
  `extern`), `toolchain/lib/libc_c/sysctl.c` (define `int _sysctl_argblk[10];`),
  `toolchain/lib/libfgx_c/libfgx.c` (define `char sys_envp[68];` -- match the
  element type of its current `extern`), `toolchain/lib/libc_data.s`
  (remove the four), `tools/check_sock_argblk.py` (read the block size from
  socket.c's definition), `toolchain/tests/M37/sockops.c` if it declares
  the block differently

**Interfaces:**
- Consumes: `tools/check_libc_data.py` (Task 1).
- Produces: the four blocks as C globals with external linkage; the kernel
  still reads them through the caller's DBR (they stay in the data bank).

- [ ] **Step 1: Point the socket checker at C and watch it go red**

In `tools/check_sock_argblk.py` replace the `DATA` path with
`toolchain/lib/libc_c/socket.c` and `DS_SIZE` with a C definition pattern,
counting words not bytes:

```python
DATA = os.path.join(ROOT, "toolchain/lib/libc_c/socket.c")
DS_SIZE = re.compile(r"^int\s+_sock_argblk\s*\[\s*(\d+)\s*\]\s*;", re.M)
```

and where it compares the size, compare `2 * int(m.group(1))` bytes.  Update
its self-test's `data` strings to `"int _sock_argblk[6];\n"` (12 bytes) and
the too-small case to `"int _sock_argblk[2];\n"`, keeping the asserted
message text in step with the new wording ("_sock_argblk is %d bytes").
Run: `python3 tools/check_sock_argblk.py --self-test && python3 tools/check_sock_argblk.py`
Expected: self-test OK; the real run FAILS (socket.c has no definition yet).

- [ ] **Step 2: Move the definitions**

Add the four definitions above; delete their `DS` lines and comment blocks
from `libc_data.s`, moving each comment (the layout description) to sit
above its C definition.  `26 DS` = 13 words, `20 DS` = 10 words.

- [ ] **Step 3: Build, check, run green**

Announce the rebuild.  Run: `(cd toolchain && make -s libc_c libfgx lib/libc.fgxa/index.json) && python3 tools/ninja/gen.py >/dev/null && ninja >$SCRATCH/t4.log 2>&1; echo rc=$?; python3 tools/check_sock_argblk.py; python3 tools/check_libc_data.py; python3 tools/mame_test/run.py --fresh ptysrsel securelevel telnet_loopback inetdboot`
Expected: `rc=0`; `check_sock_argblk: clean`; `check_libc_data: clean`;
`4 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add toolchain/lib/libc_c/socket.c toolchain/lib/libc_c/socket_srv.c toolchain/lib/libc_c/sockopt.c toolchain/lib/libc_c/select.c toolchain/lib/libc_c/sysctl.c toolchain/lib/libfgx_c/libfgx.c toolchain/lib/libc_data.s tools/check_sock_argblk.py toolchain/tests/M37
git commit -F - <<'EOF'
refactor(libc): syscall argument blocks live with the code that fills them

The socket, select and sysctl argument blocks, and libfgx's envp staging,
move out of the data prefix every program carries into the C members
that fill them, so only programs that make those calls carry them.  They
stay in the data bank, where the kernel reads them through the caller's
DBR.  check_sock_argblk.py now reads the block's size from socket.c.

EOF
```

### Task 5: The real 2.11BSD `cal`; `today_init` leaves libc

**Files:**
- Modify: `src/userland/cal/cal.c` (replaced by the vendored source plus the
  provenance header), `toolchain/lib/libc.s` (delete `today_init`),
  `toolchain/lib/libc_data.s` (delete `today_year/month/day/rtc`),
  `docs/PROVENANCE.md` (the cal row), cal's man page if it documents the
  no-argument default (`find . -path ./examples -prune -o -name "cal.1*" -print`)
- Create: `tools/mame_test/tests/calprobe.json`

- [ ] **Step 1: Write the probe against upstream's behaviour and watch it go red**

`tools/mame_test/tests/calprobe.json`:

```json
{
 "name": "calprobe",
 "description": "cal(1) is 2.11BSD usr.bin/cal.c: with no argument it prints upstream's usage line (it never reads the clock); `cal 9 2026' prints September 2026, which starts on a Tuesday.",
 "command": "cal; cal 9 2026",
 "boot_s": 45,
 "timeout_s": 60,
 "exit_on_prompt": {"sentinel": "fgx#", "count_delta": 1},
 "expect": {
  "screen_contains": ["usage: cal [month] year", "September 2026",
                      " S  M Tu  W Th  F  S", "       1  2  3  4  5"],
  "screen_lacks": ["PANIC", "BRK"]
 }
}
```

Run: `python3 tools/mame_test/run.py --fresh calprobe`
Expected: FAIL on `usage: cal [month] year` (today's cal prints the current
month).

- [ ] **Step 2: Port the upstream source**

```bash
{ cat <<'EOF'
/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD usr.bin/cal.c (4.3 (Berkeley) 83/08/11), vendored
 *   at vendor/2.11BSD/usr/usr.bin/cal.c.  Copyright (c) 1980 Regents of the
 *   University of California.  All rights reserved.  UCB notice retained
 *   per the BSD license; FGX changes are BSD-2-Clause (see LICENSE /
 *   docs/PROVENANCE.md).  Verbatim below this header.
 */
EOF
cat vendor/2.11BSD/usr/usr.bin/cal.c; } > src/userland/cal/cal.c
```

Check `tools/check_provenance.py`'s required markers against the header
(run it); adjust the header, never the body.

- [ ] **Step 3: Delete `today_init` and its cells**

Remove `today_init` (and its `LIBC_EXPORT`) from `libc.s`, and
`today_year`, `today_month`, `today_day`, `today_rtc` from `libc_data.s`.
Update the `docs/PROVENANCE.md` row for `src/userland/cal/cal.c` to say
"verbatim".  If cal's man page describes the no-argument default, make it
match upstream's usage.

- [ ] **Step 4: Build, check, run green**

Announce the rebuild.  Run: `python3 tools/ninja/gen.py >/dev/null && ninja >$SCRATCH/t5.log 2>&1; echo rc=$?; grep -E "^FAILED|rror" $SCRATCH/t5.log | head; python3 tools/check_libc_data.py; python3 tools/check_provenance.py | tail -1; python3 tools/mame_test/run.py --fresh calprobe`
Expected: `rc=0`; `check_libc_data: clean`; provenance OK; `1 passed`.
If fcc rejects the verbatim source, fix fcc with a fixture and say so in the
commit, quoting the K&R sentence that governs.

- [ ] **Step 5: Commit**

```bash
git add src/userland/cal/cal.c toolchain/lib/libc.s toolchain/lib/libc_data.s docs/PROVENANCE.md tools/mame_test/tests/calprobe.json
git commit -F - <<'EOF'
feat(cal): cal is 2.11BSD's usr.bin/cal.c

cal(1) is the vendored 2.11BSD source, verbatim.  With no argument it
prints upstream's `usage: cal [month] year' rather than the current
month: 2.11BSD's cal never reads the clock.  libc's today_init and its
cells, which only the rewrite used, leave the data prefix every program
carries.  calprobe covers the usage line and a month.

EOF
```

### Task 6: Measure, gate, record

**Files:**
- Modify: `docs/history/plans/2026-09-28-shared-libc-sp2-design.md` (section
  10: the label-by-label list is done; the measured prefix size),
  `docs/ROADMAP.md` item 6 (one line: step 1 landed)

- [ ] **Step 1: Measure the fixed prefix**

The prefix is everything the three hand-written data files put in a tool's
data segment, from `$0100` up to the first label they do not define.  On the
base commit (8e5e59b00) it was `$0100`-`$0EC8`, 3,528 bytes.

```bash
python3 - <<'EOF2'
import re
own = set()
for f in ("toolchain/lib/libc_data.s", "toolchain/lib/args_data.s",
          "toolchain/lib/fcc_runtime_data.s"):
    own |= {m.group(1) for m in re.finditer(r"^([A-Za-z_]\w*)\s", open(f).read(), re.M)}
lay = {m.group(1): int(m.group(2), 16) for m in re.finditer(
    r"^(\S+)\s+EQU\s+\$([0-9A-Fa-f]+)", open("tools/cat-fgx2/seg1_layout.s").read(), re.M)}
end = min(a for n, a in lay.items() if n not in own and a >= 0x100)
print("fixed prefix: $0100-$%04X = %d bytes" % (end, end - 0x100))
EOF2
```

Expected: well under 3,528 (the spec estimates ~1.25 KB).

- [ ] **Step 2: Full gate**

Run: `tools/gate.sh > $SCRATCH/gate.log 2>&1; tail -20 $SCRATCH/gate.log`
Expected: `GATE GREEN`.  If a fixture fails, read which stage failed first
(the gate stops at its first red stage).

- [ ] **Step 3: Record and commit**

Write the measured prefix size into the spec's section 10 and one line into
ROADMAP item 6; commit as `docs(plans): shared libc SP2 step 1 landed`.
Record the result in the project notes (group `fgx`) as one `add_triplet`:
"Shared libc SP2 step 1 -- shrank the fixed data prefix from 3,528 B to N B".
