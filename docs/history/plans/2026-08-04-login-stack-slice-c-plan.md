# Login stack (slice C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace FGX's `init` stub with a real 2.11BSD-shaped login chain --
`init` respawning `getty` per `/etc/ttys` line, `getty` exec'ing `login`,
`login` authenticating against `/etc/passwd` and exec'ing the user's shell --
plus `passwd(1)` and `halt(8)`.

**Architecture:** Four new userland programs and four libc additions.  Every
stage `exec`s rather than forks, so the whole chain costs no more bank-0 stack
arena than the shell alone.  The shipped `/etc/ttys` runs `/bin/sh` directly on
ttyv0 (`ty_getty` is just "the command init runs on this line"), so the existing
36 MAME tests keep booting to a bare prompt while ttyv1/ttyv2 exercise the real
login path.

**Tech Stack:** fcc (K&R C, 16-bit int), the checked-in `toolchain/lib/libc_c.s`
pile, ninja via `tools/ninja/manifest.json`, MAME test manifests under
`tools/mame_test/tests/*.json`.

Design: `docs/history/plans/2026-08-04-login-stack-vc-design.md`.
Scope/decomposition: `docs/history/plans/2026-07-31-bsd-login-stack-scope.md`.
Slice D (three alt-N virtual consoles) is a separate plan, written after this
one lands.

## Global Constraints

- **Toolchain-first.** If fcc or libc lacks something, fix it in
  `toolchain/`, add a regression fixture, and keep goldens green.  Never a
  per-tool asm stub, never a local reimplementation of a standard function,
  never a sed/codegen pass over generated output.
- **Port source is `vendor/2.11BSD/usr/`.**  `vendor/netbsd-0-9/` is advisory
  only.  `getty` is NOT vendored (2.11BSD keeps it in `libexec/`, which this
  tree does not carry) -- write it fresh and mark it
  `FGX-Provenance: none`.
- **Provenance.** Any `src/userland/**/*.c` containing `2.11BSD`, `Regents of
  the University`, `Berkeley`, `UCB`, or `Bill Joy` MUST have a row in
  `PROVENANCE.md` or `tools/check_provenance.py` fails the build.  Original
  files that merely cite 2.11BSD declare `FGX-Provenance: none`.
- **ASCII only** in every source file, comment, commit message, and doc: no
  em-dashes, no curly quotes, no Unicode.
- **K&R C.**  fcc is a K&R compiler with `int == 16 bits`.  Old-style function
  definitions (`char *f(a) int a; { }`) throughout, matching
  `toolchain/lib/libc_c/libc_c.c` and `src/userland/init/init.c`.
- **`spawnve` argv/envp ABI trap.**  `spawnve`/`spawnx` take NULL-terminated
  tables of 16-bit offsets into the caller's DATA bank, so their argv/envp
  arrays must be **`static int[]` at file scope**, never `char *x[]` locals
  (an fcc local aggregate lives on the bank-0 hardware stack and its entries
  are 4-byte far pointers -- wrong bank AND wrong stride).  `execve()` is
  different: libc stages the vectors for you (`libc_c.c:966`), so plain
  `char *argv[]` is correct there.
- **ProDOS filenames** are case-insensitive, cannot contain underscores, and
  are 15 characters max.  `/etc/ttys` and `/etc/issue` are fine.
- **`disk_src/etc` is block-sensitive.**  Stage 2's multi-block directory scan
  is fixed (slice A1), so new `/etc` files are safe now -- but if boot ever
  goes black with no diagnostic, probe `PRESTAGED_ABS` at `$00:1FE8`; all
  zeros means no module staged.
- **Every check must go red without the change it guards.**  A test that
  passes with the implementation stubbed out is not coverage.
- **Bugs found along the way go to GitLab** (`glab issue create`, project
  `apple/fgx`) with reproduction and evidence, not into this plan or
  `docs/ROADMAP.md`.

### Build and test commands

```bash
python3 tools/ninja/gen.py            # after editing tools/ninja/manifest.json
ninja -f build.ninja all              # build everything incl. disk/fgx.po
cd toolchain && make lib/libc_c.s     # REQUIRED after editing libc_c/*.c
python3 tools/mame_test/run.py --list
python3 tools/mame_test/run.py NAME   # run one test
python3 tools/mame_test/run.py --debug NAME   # visible MAME, stays up on fail
tools/gate.sh                         # boot smoke + memory/fork fixtures
python3 tools/check_stack_budget.py -v
python3 tools/check_provenance.py
```

`toolchain/lib/libc_c.s` is **checked in and generated**.  Editing
`libc_c/libc_c.c` without running `make lib/libc_c.s` silently assembles the old
pile -- the Makefile rule is file-based specifically to stop that.

---

## File Structure

**libc (toolchain, all K&R):**
- Create `toolchain/include/ttyent.h` -- `struct ttyent`, `TTY_*` flags,
  prototypes.
- Modify `toolchain/lib/libc_c/libc_c.c` -- append `getttyent`/`getttynam`/
  `setttyent`/`endttyent`, `crypt`, `getpass`.  Regenerates
  `toolchain/lib/libc_c.s` + `libc_c_data.s`.

**Programs (one directory each under `src/userland/`):**
- `getty/getty.c` -- original, `FGX-Provenance: none`.
- `login/login.c` -- derived from `vendor/2.11BSD/usr/bin/login/login.c`,
  needs a `PROVENANCE.md` row.
- `passwd/passwd.c` -- derived from `vendor/2.11BSD/usr/bin/passwd/passwd.c`,
  needs a `PROVENANCE.md` row.
- `halt/halt.c` -- original.
- `init/init.c` -- rewritten, derived from
  `vendor/2.11BSD/usr/sbin/init/init.c`, needs a `PROVENANCE.md` row.
- `logintest/logintest.c` -- test harness, original, modelled on
  `src/userland/ptyshell/ptyshell.c`.
- `ttysprobe/ttysprobe.c` -- test harness for the libc additions, original.

**Disk content:**
- Create `disk_src/etc/ttys`, `disk_src/etc/issue`.
- Modify `disk_src/etc/passwd` -- give root a real hashed password.

**Man pages** (preformatted, `src/userland/man/pages/catN/*.0`, wired through
the `manfmt` ninja edge): `cat1/login.0`, `cat1/passwd.0`, `cat5/ttys.0`,
`cat8/init.0`, `cat8/getty.0`, `cat8/halt.0`.

**Build/test wiring:**
- Modify `tools/ninja/manifest.json` -- `tools` entries and `staging` rows for
  every new binary and man page.
- Create `tools/mame_test/tests/ttysprobe.json`, `logintest.json`,
  `initrespawn.json`, `haltcmd.json`.
- Modify `tools/check_stack_budget.py` -- multi-console scenarios.

---

## Task 1: `/etc/ttys` and the ttyent parser

**Files:**
- Create: `toolchain/include/ttyent.h`
- Modify: `toolchain/lib/libc_c/libc_c.c` (append near the pwent block,
  `libc_c.c:2110+`)
- Create: `disk_src/etc/ttys`
- Create: `src/userland/ttysprobe/ttysprobe.c`
- Create: `tools/mame_test/tests/ttysprobe.json`
- Modify: `tools/ninja/manifest.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct ttyent *getttyent()`, `struct ttyent *getttynam(char *name)`,
  `int setttyent()`, `int endttyent()`.  Field names `ty_name`, `ty_getty`,
  `ty_type`, `ty_status`, `ty_window`, `ty_comment`.  Task 6 (`init`) iterates
  with `getttyent`; task 5 (`login`) reads `ty_type` via `getttynam`.

**File format.**  BSD's `/etc/ttys` is whitespace-separated, one line per tty:

```
# name  getty              type    status
ttyv0   /bin/sh            vt100   on secure
ttyv1   /bin/getty         vt100   on secure
ttyv2   /bin/getty         vt100   on secure
```

Blank lines and `#` lines are ignored, matching the pwent parser's FGX
tolerance.  `ty_getty` is simply the command `init` runs on the line -- pointing
ttyv0 at `/bin/sh` is what keeps the existing MAME tests booting to a bare
prompt.  Quoted getty strings (BSD allows `"getty std.9600"`) are NOT supported;
the field is a single path.  Document that in `ttys(5)`.

- [ ] **Step 1: Write the failing test**

Create `src/userland/ttysprobe/ttysprobe.c`.  It runs on FGX and prints one
line per assertion; the MAME manifest greps the screen.

```c
/* ttysprobe - closed-loop check for the libc ttyent + crypt additions.
 *
 * FGX-Provenance: none
 *
 * Prints TP<n> OK / TP<n> FAIL per assertion and a final verdict line.
 * Reads the SHIPPED /etc/ttys, so it fails if the file or the parser drifts.
 */
#include <stdio.h>
#include <ttyent.h>
#include <string.h>

int fails;

static void
chk(n, cond)
	int n;
	int cond;
{
	if (cond)
		printf("TP%d OK\n", n);
	else {
		printf("TP%d FAIL\n", n);
		fails++;
	}
}

int
main()
{
	struct ttyent *t;
	int n;

	/* 1: the file opens and yields the first line. */
	chk(1, setttyent() != 0);
	t = getttyent();
	chk(2, t != (struct ttyent *)0 && strcmp(t->ty_name, "ttyv0") == 0);

	/* 3: ty_getty is the whole command path, not a truncated token. */
	chk(3, t != (struct ttyent *)0 && strcmp(t->ty_getty, "/bin/sh") == 0);

	/* 4: exactly three lines, so comments and blanks are skipped. */
	n = 1;
	while (getttyent() != (struct ttyent *)0)
		n++;
	chk(4, n == 3);
	endttyent();

	/* 5: getttynam finds a middle line and reads its type. */
	t = getttynam("ttyv1");
	chk(5, t != (struct ttyent *)0 && strcmp(t->ty_type, "vt100") == 0);

	/* 6: a name that is not there returns NULL rather than the last line. */
	chk(6, getttynam("ttyzz") == (struct ttyent *)0);

	/* 7: status parses to a flag, not a string compare at every use site. */
	t = getttynam("ttyv2");
	chk(7, t != (struct ttyent *)0 && (t->ty_status & TTY_ON) != 0);

	printf(fails == 0 ? "TTYSPROBE PASS\n" : "TTYSPROBE FAIL\n");
	return fails != 0;
}
```

Create `disk_src/etc/ttys` with the three lines shown above (plus the `#`
comment header, which assertion 4 proves is skipped).

Create `tools/mame_test/tests/ttysprobe.json`:

```json
{
 "name": "ttysprobe",
 "description": "libc ttyent parser reads the shipped /etc/ttys",
 "command": "/testbin/ttysprobe",
 "timeout_s": 60,
 "expect": {
  "screen_contains": ["TTYSPROBE PASS"],
  "screen_not_contains": ["FAIL"]
 }
}
```

Add to `tools/ninja/manifest.json`: a `{"name": "ttysprobe"}` entry in `tools`,
and a staging row `{"src": "bin/ttysprobe.bin", "dst": "disk_src/testbin/ttysprobe"}`.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
```

Expected: the build FAILS at the fcc step with `ttyent.h: No such file or
directory`.  That is the correct first failure -- the header does not exist yet.

- [ ] **Step 3: Write the header**

Create `toolchain/include/ttyent.h`:

```c
/* ttyent.h - /etc/ttys database, 2.11BSD shape.
 *
 * FGX notes: there is no ty_window (no window system) and no quoted-getty
 * syntax; ty_getty is a single command path.  Both fields exist for API
 * compatibility, matching how pwd.h keeps pw_class/pw_change/pw_expire.
 */
#ifndef _TTYENT_H_
#define _TTYENT_H_

#define _PATH_TTYS "/etc/ttys"

#define TTY_ON     0x01    /* enable logins (init runs ty_getty) */
#define TTY_SECURE 0x02    /* root may log in on this line */

struct ttyent {
	char *ty_name;      /* line name, e.g. "ttyv0" */
	char *ty_getty;     /* command init runs on the line */
	char *ty_type;      /* terminal type -> TERM */
	int   ty_status;    /* TTY_ON | TTY_SECURE */
	char *ty_window;    /* always "" on FGX */
	char *ty_comment;   /* always "" on FGX */
};

struct ttyent *getttyent();
struct ttyent *getttynam();
int setttyent();
int endttyent();

#endif
```

- [ ] **Step 4: Write the parser**

Append to `toolchain/lib/libc_c/libc_c.c`, after the pwent block.  Add
`#include <ttyent.h>` to the include list at the top of the file.

```c
/* ---- /etc/ttys database ---------------------------------------------------
 * Same shape as the pwent block above: one static FILE, one line buffer, one
 * returned struct.  Whitespace-separated rather than colon-separated, and the
 * status column is a word list ("on secure") rather than a single token, so
 * the field splitter differs from _pw_field.
 */
#define _TTY_LINEMAX 128

static FILE         *_tty_fp;
static struct ttyent _tty_ent;
static char          _tty_line[_TTY_LINEMAX];

/* Split off the next whitespace-delimited token, NUL-terminate it in place,
 * and advance *bp past it.  Returns NULL at end of line. */
static char *_tty_field(bp)
	char **bp;
{
	char *s, *p;

	p = *bp;
	while (*p == ' ' || *p == '\t')
		p++;
	if (*p == '\0')
		return (char *)0;
	s = p;
	while (*p != '\0' && *p != ' ' && *p != '\t')
		p++;
	if (*p != '\0')
		*p++ = '\0';
	*bp = p;
	return s;
}

int setttyent()
{
	if (_tty_fp != (FILE *)0)
		rewind(_tty_fp);
	else
		_tty_fp = fopen(_PATH_TTYS, "r");
	return _tty_fp != (FILE *)0;
}

int endttyent()
{
	if (_tty_fp != (FILE *)0) {
		fclose(_tty_fp);
		_tty_fp = (FILE *)0;
	}
	return 1;
}

struct ttyent *getttyent()
{
	char *bp, *cp;

	if (_tty_fp == (FILE *)0 && !setttyent())
		return (struct ttyent *)0;
	for (;;) {
		if (fgets(_tty_line, _TTY_LINEMAX, _tty_fp) == (char *)0)
			return (struct ttyent *)0;
		cp = strchr(_tty_line, '\n');
		if (cp != (char *)0)
			*cp = '\0';
		bp = _tty_line;
		_tty_ent.ty_name = _tty_field(&bp);
		if (_tty_ent.ty_name == (char *)0
		 || _tty_ent.ty_name[0] == '#')
			continue;                  /* blank or comment */
		_tty_ent.ty_getty = _tty_field(&bp);
		if (_tty_ent.ty_getty == (char *)0)
			continue;                  /* short line: skip it */
		_tty_ent.ty_type = _tty_field(&bp);
		if (_tty_ent.ty_type == (char *)0)
			_tty_ent.ty_type = "";
		_tty_ent.ty_status = 0;
		while ((cp = _tty_field(&bp)) != (char *)0) {
			if (strcmp(cp, "on") == 0)
				_tty_ent.ty_status |= TTY_ON;
			else if (strcmp(cp, "secure") == 0)
				_tty_ent.ty_status |= TTY_SECURE;
			/* "off" and unknown words simply leave the bit clear */
		}
		_tty_ent.ty_window = "";
		_tty_ent.ty_comment = "";
		return &_tty_ent;
	}
}

struct ttyent *getttynam(nam)
	char *nam;
{
	struct ttyent *t;

	if (!setttyent())
		return (struct ttyent *)0;
	while ((t = getttyent()) != (struct ttyent *)0)
		if (strcmp(nam, t->ty_name) == 0)
			break;
	endttyent();              /* the line buffer outlives the close */
	return t;
}
```

- [ ] **Step 5: Rebuild the libc pile and the disk**

```bash
cd toolchain && make lib/libc_c.s && cd ..
python3 tools/ninja/gen.py && ninja -f build.ninja all
```

Expected: clean build.  If `libc_c.s` does not change timestamp, the Makefile
did not see your edit -- do not proceed, the next step would test the old pile.

- [ ] **Step 6: Run the test to verify it passes**

```bash
python3 tools/mame_test/run.py ttysprobe
```

Expected: PASS, with `TTYSPROBE PASS` on screen.

- [ ] **Step 7: Prove the test discriminates**

Temporarily make `_tty_field` return `(char *)0` unconditionally, rebuild the
pile and the disk, and re-run.  Expected: `TP1 FAIL` or `TTYSPROBE FAIL`.
Revert, rebuild, confirm PASS again.  A test that survives that mutation is not
coverage and must be strengthened before committing.

- [ ] **Step 8: Commit**

```bash
git add toolchain/include/ttyent.h toolchain/lib/libc_c/libc_c.c \
        toolchain/lib/libc_c.s toolchain/lib/libc_c_data.s \
        disk_src/etc/ttys src/userland/ttysprobe/ttysprobe.c \
        tools/mame_test/tests/ttysprobe.json tools/ninja/manifest.json \
        build.ninja
git commit -m "feat(libc): /etc/ttys database -- getttyent/getttynam

init needs a line table it can re-read on SIGHUP, and login needs ty_type
for TERM.  Parser mirrors the pwent block next to it: one static FILE, one
line buffer, one returned struct.  Two FGX narrowings, both documented in
ttys(5): no quoted-getty syntax (ty_getty is a single command path) and no
ty_window.

ttysprobe reads the SHIPPED /etc/ttys rather than a fixture, so the file and
the parser cannot drift apart silently."
```

---

## Task 2: `crypt(3)` -- tagged, cheap, forward-compatible

**Files:**
- Modify: `toolchain/lib/libc_c/libc_c.c`
- Modify: `src/userland/ttysprobe/ttysprobe.c` (extend with crypt vectors)
- Modify: `disk_src/etc/passwd`
- Modify: `tools/mame_test/tests/ttysprobe.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `char *crypt(char *key, char *salt)` returning a pointer to a static
  buffer holding `$f$<2-char-salt>$<8 hex digits>`.  Task 5 (`login`) and task 8
  (`passwd`) both call it.

**Why not DES.**  Classic 25-round DES `crypt` on a 2.8 MHz 65816 would make
login visibly pause, and the security value on a single-user IIgs is close to
decorative (the maintainer, 2026-07-31).  The `$`-prefixed tag is the whole point: a real
DES `crypt` can be added later and coexist, because `login` dispatches on the
tag and an untagged 13-character DES hash is unambiguously distinguishable from
`$f$...`.

- [ ] **Step 1: Write the failing test**

Append to `ttysprobe.c` inside `main()`, before the verdict line:

```c
	/* 8: crypt is deterministic and carries its tag. */
	strcpy(h1, crypt("swordfish", "ab"));
	chk(8, strncmp(h1, "$f$ab$", 6) == 0);
	chk(9, strcmp(h1, crypt("swordfish", "ab")) == 0);

	/* 10: a different password under the same salt differs. */
	chk(10, strcmp(h1, crypt("swordfisi", "ab")) != 0);

	/* 11: the same password under a different salt differs -- if this
	 * fails the salt is being ignored and every account shares a hash. */
	chk(11, strcmp(h1, crypt("swordfish", "cd")) != 0);

	/* 12: the returned buffer is static; a second call invalidates it,
	 * which is the BSD contract callers strcpy out of. */
	chk(12, crypt("x", "yz") == crypt("q", "yz"));
```

with `char h1[32];` declared at the top of `main()` and `#include <unistd.h>`
for the `crypt` prototype.

Update the manifest's `screen_contains` to keep `TTYSPROBE PASS`.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
```

Expected: link failure, `crypt` undefined.

- [ ] **Step 3: Implement crypt**

Append to `toolchain/lib/libc_c/libc_c.c`:

```c
/* ---- crypt(3) -------------------------------------------------------------
 * NOT DES.  A 25-round DES crypt at 2.8 MHz would make login visibly pause and
 * buys close to nothing on a single-user IIgs (the maintainer, 2026-07-31).  This is an
 * FNV-1a over salt+key, printed as "$f$<salt>$<8 hex>".
 *
 * The "$f$" TAG is the forward-compatibility seam: a real DES crypt can be
 * added later and coexist, because a 13-character untagged DES hash cannot be
 * confused with a tagged one.  Callers must dispatch on the tag, never assume
 * a length.
 *
 * Being explicit about the threat model: this stops a shoulder-surfer and a
 * casual reader of /etc/passwd.  It is not a defence against an attacker who
 * has the file and wants the password.  Say so in passwd(1) too.
 */
static char _crypt_buf[16];

static char _crypt_hexd(v)
	int v;
{
	return (char)(v < 10 ? '0' + v : 'a' + (v - 10));
}

char *crypt(key, salt)
	char *key;
	char *salt;
{
	unsigned long h;
	char *p;
	int i, nyb;

	/* FNV-1a, 32-bit.  fcc has real 32-bit longs; the multiply is the
	 * expensive part and runs 2 + strlen(key) times, which is nothing. */
	h = 2166136261L;
	for (p = salt; p != (char *)0 && *p != '\0' && p < salt + 2; p++) {
		h = h ^ (unsigned long)(unsigned char)*p;
		h = h * 16777619L;
	}
	for (p = key; p != (char *)0 && *p != '\0'; p++) {
		h = h ^ (unsigned long)(unsigned char)*p;
		h = h * 16777619L;
	}

	_crypt_buf[0] = '$';
	_crypt_buf[1] = 'f';
	_crypt_buf[2] = '$';
	_crypt_buf[3] = (salt != (char *)0 && salt[0] != '\0') ? salt[0] : '.';
	_crypt_buf[4] = (salt != (char *)0 && salt[0] != '\0'
	              && salt[1] != '\0') ? salt[1] : '.';
	_crypt_buf[5] = '$';
	for (i = 0; i < 8; i++) {
		nyb = (int)((h >> ((7 - i) * 4)) & 0x0FL);
		_crypt_buf[6 + i] = _crypt_hexd(nyb);
	}
	_crypt_buf[14] = '\0';
	return _crypt_buf;
}
```

Add `char *crypt();` to `toolchain/include/unistd.h` alongside the other
declarations.

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd toolchain && make lib/libc_c.s && cd ..
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/mame_test/run.py ttysprobe
```

Expected: PASS.  Assertion 11 is the one that matters -- it fails if the salt
loop is dropped.

- [ ] **Step 5: Give root a real password**

Compute the hash on FGX rather than guessing it: temporarily add
`printf("root hash: %s\n", crypt("fgx", "rt"));` to `ttysprobe`, run it, read the
value off the screen, then remove the line.  Do not hand-compute it -- a
host-side FNV that disagrees with fcc's `unsigned long` arithmetic would produce
a `/etc/passwd` nobody can log into, and the failure would look like a login
bug.

Update `disk_src/etc/passwd`:

```
# name:passwd:uid:gid:gecos:dir:shell
root:$f$rt$XXXXXXXX:0:0:Charlie Root:/root:/bin/sh
```

(with the real hash substituted for `XXXXXXXX`).

- [ ] **Step 6: Commit**

```bash
git add toolchain/lib/libc_c/libc_c.c toolchain/lib/libc_c.s \
        toolchain/lib/libc_c_data.s toolchain/include/unistd.h \
        src/userland/ttysprobe/ttysprobe.c disk_src/etc/passwd \
        tools/mame_test/tests/ttysprobe.json
git commit -m "feat(libc): crypt(3) -- tagged non-DES hash

25-round DES at 2.8 MHz would make login visibly pause for decorative
security on a single-user machine (the maintainer, 2026-07-31).  This is FNV-1a
printed as \$f\$<salt>\$<8 hex>.  The tag is the point: a real DES crypt can
land later and coexist, since an untagged 13-char DES hash is unambiguous.

ttysprobe asserts salt sensitivity specifically -- drop the salt loop and
every account in /etc/passwd would share one hash, which no other assertion
here would catch."
```

---

## Task 3: `getpass(3)`

**Files:**
- Modify: `toolchain/lib/libc_c/libc_c.c`
- Modify: `toolchain/include/unistd.h`

**Interfaces:**
- Consumes: nothing.
- Produces: `char *getpass(char *prompt)` -- prints the prompt, reads a line
  from fd 0 with echo disabled, restores the previous sgtty flags, returns a
  pointer to a static buffer.  Task 5 (`login`) and task 8 (`passwd`) call it.

**FGX divergence, deliberate.**  BSD's `getpass` opens `/dev/tty` so a
redirected stdin cannot capture the password.  FGX has no `/dev/tty`: the
registered chardevs are `console`, `ttyp0`, `ttyp1`, `ptyp0`, `ptyp1`
(`signal.s:1284`), and there is no controlling-terminal alias.  `getty` and
`login` always have the line on fd 0/1/2, so fd 0 is the same descriptor BSD
would have reached.  Document it in `getpass(3)`; revisit if something ever
needs a password prompt with stdin redirected.

There is no separate test here: task 5's pty harness drives a real password
prompt end to end, which is a stronger check than anything a standalone probe
could assert about echo suppression.

- [ ] **Step 1: Implement getpass**

Append to `toolchain/lib/libc_c/libc_c.c` (add `#include <sgtty.h>` to the
include list if not already present):

```c
/* ---- getpass(3) -----------------------------------------------------------
 * BSD opens /dev/tty so a redirected stdin cannot capture the password.  FGX
 * has no /dev/tty -- the chardev registry has console, ttyp0/1 and ptyp0/1,
 * with no controlling-terminal alias -- so this reads fd 0.  getty and login
 * always have the line on 0/1/2, which is the descriptor BSD would have
 * reached anyway.  Documented in getpass(3), not silently different.
 *
 * The sgtty flags are restored on every exit path including a read error;
 * leaving a terminal with ECHO off after a failed login would be a
 * user-visible wedge that looks like a dead keyboard.
 */
static char _getpass_buf[_PASSWORD_LEN + 1];

char *getpass(prompt)
	char *prompt;
{
	struct sgttyb ttyb;
	int have_tty, n, i;
	int oflags;
	char c;

	have_tty = ioctl(0, TIOCGETP, (char *)&ttyb) == 0;
	if (have_tty) {
		oflags = ttyb.sg_flags;
		ttyb.sg_flags = oflags & ~ECHO;
		ioctl(0, TIOCSETP, (char *)&ttyb);
	}

	if (prompt != (char *)0)
		write(2, prompt, strlen(prompt));

	i = 0;
	for (;;) {
		n = read(0, &c, 1);
		if (n != 1 || c == '\n' || c == '\r')
			break;
		if (i < _PASSWORD_LEN)
			_getpass_buf[i++] = c;
	}
	_getpass_buf[i] = '\0';

	if (have_tty) {
		ttyb.sg_flags = oflags;
		ioctl(0, TIOCSETP, (char *)&ttyb);
	}
	write(2, "\n", 1);           /* the newline the user could not see */
	return _getpass_buf;
}
```

Add to `toolchain/include/unistd.h`:

```c
#define _PASSWORD_LEN 32
char *getpass();
```

- [ ] **Step 2: Verify it builds**

```bash
cd toolchain && make lib/libc_c.s && cd ..
ninja -f build.ninja all
```

Expected: clean build.  Behaviour is proven in task 5.

- [ ] **Step 3: Commit**

```bash
git add toolchain/lib/libc_c/libc_c.c toolchain/lib/libc_c.s \
        toolchain/lib/libc_c_data.s toolchain/include/unistd.h
git commit -m "feat(libc): getpass(3), reading fd 0

BSD opens /dev/tty to dodge a redirected stdin.  FGX has no /dev/tty -- the
chardev registry is console, ttyp0/1, ptyp0/1, with no controlling-terminal
alias -- so this reads fd 0, which for getty and login is the same descriptor
BSD would have reached.  Divergence is documented, not silent.

Flags are restored on every exit path including read error: a terminal left
with ECHO off after a failed login reads as a dead keyboard."
```

---

## Task 4: `/bin/getty`

**Files:**
- Create: `src/userland/getty/getty.c`
- Create: `disk_src/etc/issue`
- Create: `src/userland/man/pages/cat8/getty.0`
- Modify: `tools/ninja/manifest.json`

**Interfaces:**
- Consumes: `getttynam` (task 1).
- Produces: the binary `/bin/getty`, invoked by `init` as
  `getty <ttyname>` with the line already open on fd 0/1/2.  It `execve`s
  `/bin/login <name>`.

**Why no vendored source.**  `vendor/2.11BSD/` carries only
`usr/{bin,old,sbin,ucb,usr.bin}`; getty lives in `libexec/` and is not in the
tree.  The job also collapses: no baud negotiation, no modem control, no parity
autodetect, no `gettytab`.  This file is FGX-original and declares
`FGX-Provenance: none`.

- [ ] **Step 1: Write getty**

```c
/* getty(8) - open a line, greet, read a login name, exec login.
 *
 * FGX-Provenance: none.  2.11BSD keeps getty in libexec/, which this tree does
 * not vendor, and the job collapses here anyway: no baud negotiation, no modem
 * control, no parity autodetect, no gettytab.
 *
 * init has already opened the line on fd 0/1/2 (see init.c's file_actions), so
 * getty does not open anything.  It sets cooked modes, prints /etc/issue and
 * the prompt, reads a name, and EXECS login -- exec, not spawn, so the chain
 * costs no extra bank-0 stack arena.
 */
#include <stdio.h>
#include <sgtty.h>
#include <string.h>
#include <unistd.h>

char name[64];

static void
catfile(path)
	char *path;
{
	FILE *f;
	int c;

	f = fopen(path, "r");
	if (f == (FILE *)0)
		return;                  /* no issue file is not an error */
	while ((c = getc(f)) != EOF)
		putchar(c);
	fclose(f);
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct sgttyb t;
	char *av[3];
	int i;

	/* Cooked line discipline with echo: the login name IS echoed (only the
	 * password is not).  Explicit rather than inherited, because init may
	 * respawn us after a session that left the line in raw mode. */
	if (ioctl(0, TIOCGETP, (char *)&t) == 0) {
		t.sg_flags = (t.sg_flags | ECHO | CRMOD) & ~CBREAK;
		ioctl(0, TIOCSETP, (char *)&t);
	}

	for (;;) {
		catfile("/etc/issue");
		printf("login: ");
		fflush(stdout);

		if (fgets(name, sizeof(name), stdin) == (char *)0)
			return 1;            /* EOF on the line: let init respawn */
		i = strlen(name);
		while (i > 0 && (name[i - 1] == '\n' || name[i - 1] == '\r'))
			name[--i] = '\0';
		if (name[0] == '\0')
			continue;            /* bare return: re-prompt */

		/* execve, not spawn: replaces this image, so getty's stack is
		 * freed before login's is allocated.  Plain char *argv[] is
		 * correct here -- libc's execve stages the vectors into the
		 * data bank itself (libc_c.c:966).  The spawnve int[] rule
		 * applies to init, not to us. */
		av[0] = "login";
		av[1] = name;
		av[2] = (char *)0;
		execve("/bin/login", av, environ);

		/* Only reached if exec failed. */
		perror("getty: /bin/login");
		return 1;
	}
}
```

Create `disk_src/etc/issue`:

```
FGX/gs
```

- [ ] **Step 2: Wire the build**

Add `{"name": "getty"}` to `tools/ninja/manifest.json` `tools`, and a staging
row `{"src": "bin/getty.bin", "dst": "disk_src/bin/getty"}`.

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
```

Expected: clean build, `disk_src/bin/getty` exists.

- [ ] **Step 3: Write getty(8)**

Create `src/userland/man/pages/cat8/getty.0` in the preformatted style of the
existing pages (see `src/userland/man/pages/cat1/sh.0`).  Cover: invoked by
init with the line on fd 0/1/2, prints `/etc/issue`, execs `/bin/login`, and the
FGX narrowings (no gettytab, no baud, no modem control).  Add the `GETTY.8`
output path and the `.0` input to the `manfmt` staging rows in
`tools/ninja/manifest.json`.

- [ ] **Step 4: Verify it builds and stages**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/check_provenance.py
ls -l disk_src/bin/getty disk_src/usr/man/cat8/GETTY.8
```

Expected: both files present, provenance check clean.  getty's behaviour is
proven in task 5 -- do not hand-test it on the console, where a wrong exec
would leave you with no way back to a prompt.

- [ ] **Step 5: Commit**

```bash
git add src/userland/getty/getty.c disk_src/etc/issue \
        src/userland/man/pages/cat8/getty.0 tools/ninja/manifest.json \
        build.ninja
git commit -m "feat(getty): open the line, greet, exec login

FGX-original: 2.11BSD keeps getty in libexec/, which this tree does not
vendor, and the job collapses without baud negotiation, modem control,
parity autodetect or gettytab.

Sets cooked+ECHO explicitly rather than inheriting, because init respawns
getty after sessions that may have left the line raw -- an inherited raw
line would swallow the login name with no echo and look like a dead tty."
```

---

## Task 5: `/bin/login` and the pty closed loop

**Files:**
- Create: `src/userland/login/login.c`
- Create: `src/userland/logintest/logintest.c`
- Create: `tools/mame_test/tests/logintest.json`
- Create: `src/userland/man/pages/cat1/login.0`
- Modify: `tools/ninja/manifest.json`, `PROVENANCE.md`

**Interfaces:**
- Consumes: `getpwnam` (existing), `getttynam`/`ty_type` (task 1), `crypt`
  (task 2), `getpass` (task 3), `ttyname` (slice A2).
- Produces: the binary `/bin/login`, invoked as `login [name]` with the line on
  fd 0/1/2.  Execs `pw_shell` with `argv[0]` = `-` + basename, or `/bin/sh` on
  ENOMEM.

**Port shape.**  Derived from `vendor/2.11BSD/usr/bin/login/login.c` (602
lines); the core flow is about 150 and lifts cleanly.  Deleted outright: quota,
`setpriority`, `initgroups`/`grp.h`, `setlogin`, `lastlog`, syslog, tzfile,
Kerberos, and the `-h` hostname/`netdb` path.  Needs a `PROVENANCE.md` row.

- [ ] **Step 1: Write the failing test**

`logintest` drives a real `login` over a pty, exactly as `ptyshell` drives
`jsh`.  Read `src/userland/ptyshell/ptyshell.c` first -- it has the verified
`spawnx` file-actions recipe (open slave -> child fd 3; dup2 3 onto 0,1,2;
close 3) and the non-blocking master poll idiom.  Copy that structure.

```c
/* logintest - closed-loop check for getty + login over a pty.
 *
 * FGX-Provenance: none
 *
 * Spawns /bin/login on the slave side of /dev/ptyp0 and drives it from the
 * master, the same shape ptyshell uses for jsh.  Three cases, in one run:
 *
 *   LT1  wrong password  -> "Login incorrect", no shell
 *   LT2  right password  -> a shell prompt appears
 *   LT3  the shell's environment carries HOME and TERM
 *
 * LT1 is the discriminating case.  A login that never checks the password
 * passes LT2 and LT3 with flying colours, so a suite without LT1 would go
 * green against an authentication bypass.
 *
 * Prints LT<n> OK / LT<n> FAIL and a verdict line.
 */
```

Implement it against the `ptyshell` skeleton: `acc[]` accumulator, `drain_until`
helper that polls the master for a substring with a frame budget, `wr` helper
that writes a string plus `\n` to the master.  The sequence:

1. spawn `login` with argv `{"login", "root", 0}` on the slave;
2. `drain_until("Password:")`, write `wrongpw`;
3. `drain_until("Login incorrect")` -> LT1;
4. the child has exited by now (login exits after a failed attempt), so spawn
   a second `login` the same way, `drain_until("Password:")`, write `fgx`;
5. `drain_until("$")` (the `sh` prompt) -> LT2;
6. write `printenv HOME`, `drain_until("/root")` -> LT3;
7. write `exit`, drain to EOF, print the verdict.

Create `tools/mame_test/tests/logintest.json`:

```json
{
 "name": "logintest",
 "description": "login authenticates over a pty; wrong password is rejected",
 "command": "/testbin/logintest",
 "timeout_s": 120,
 "expect": {
  "screen_contains": ["LOGINTEST PASS"],
  "screen_not_contains": ["FAIL"]
 }
}
```

Add `{"name": "logintest"}` and its staging row to the manifest.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/mame_test/run.py logintest
```

Expected: FAIL -- `/bin/login` does not exist, so the spawn fails and no
`Password:` ever arrives.

- [ ] **Step 3: Write login**

```c
/* login(1) - authenticate and exec the user's shell.
 *
 * Derived from vendor/2.11BSD/usr/bin/login/login.c (2.11BSD, Regents of the
 * University of California).  See PROVENANCE.md.
 *
 * Kept: getpwnam -> getpass -> crypt -> compare -> setgid/setuid -> chdir ->
 * build env -> exec the shell as "-sh".  Deleted: quota, setpriority,
 * initgroups, setlogin, lastlog, syslog, tzfile, Kerberos, and the -h
 * hostname path (which returns if telnetd ever wants it).
 *
 * EXEC, not spawn: the shell replaces this image, so the getty -> login ->
 * shell chain holds exactly one task's bank-0 stack, not three.
 */
#include <stdio.h>
#include <pwd.h>
#include <ttyent.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#define TRIES 3

char  nbuf[64];
char  envhome[80];
char  envshell[80];
char  envuser[80];
char  envterm[64];
char  arg0[32];

static char *
lastpart(p)
	char *p;
{
	char *s;

	s = strrchr(p, '/');
	return s != (char *)0 ? s + 1 : p;
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	struct passwd *pw;
	struct ttyent *ty;
	char *name, *tn, *shell;
	char *env[6], *av[2];
	int i, t;

	tn = ttyname(0);
	ty = tn != (struct ttyent *)0 ? getttynam(lastpart(tn)) : (struct ttyent *)0;

	for (t = 0; t < TRIES; t++) {
		if (t == 0 && argc > 1)
			name = argv[1];             /* handed over by getty */
		else {
			printf("login: ");
			fflush(stdout);
			if (fgets(nbuf, sizeof(nbuf), stdin) == (char *)0)
				return 1;
			i = strlen(nbuf);
			while (i > 0 && (nbuf[i-1] == '\n' || nbuf[i-1] == '\r'))
				nbuf[--i] = '\0';
			name = nbuf;
		}

		pw = getpwnam(name);

		/* Ask for a password even when the account does not exist:
		 * answering "no such user" immediately tells an attacker which
		 * names are real.  2.11BSD does the same. */
		{
			char *given, *want;

			given = getpass("Password:");
			want = pw != (struct passwd *)0 ? pw->pw_passwd : "*";
			if (pw != (struct passwd *)0
			 && strcmp(want, crypt(given, want)) == 0)
				break;                  /* authenticated */
		}

		/* TTY_SECURE gates root on this line (login.c:484 upstream). */
		printf("Login incorrect\n");
		pw = (struct passwd *)0;
	}

	if (pw == (struct passwd *)0)
		return 1;

	if (pw->pw_uid == 0 && ty != (struct ttyent *)0
	 && (ty->ty_status & TTY_SECURE) == 0) {
		printf("Login incorrect\n");    /* root on an insecure line */
		return 1;
	}

	setgid(pw->pw_gid);
	setuid(pw->pw_uid);

	if (pw->pw_dir != (char *)0 && pw->pw_dir[0] != '\0')
		chdir(pw->pw_dir);              /* failure is not fatal */

	shell = (pw->pw_shell != (char *)0 && pw->pw_shell[0] != '\0')
	      ? pw->pw_shell : "/bin/sh";

	sprintf(envhome,  "HOME=%s", pw->pw_dir);
	sprintf(envshell, "SHELL=%s", shell);
	sprintf(envuser,  "USER=%s", pw->pw_name);
	sprintf(envterm,  "TERM=%s",
	        ty != (struct ttyent *)0 && ty->ty_type[0] != '\0'
	        ? ty->ty_type : "vt100");
	env[0] = "PATH=:/bin:/usr/bin:/sbin";
	env[1] = envhome;
	env[2] = envshell;
	env[3] = envuser;
	env[4] = envterm;
	env[5] = (char *)0;

	/* argv[0] = "-sh": the leading dash is what makes it a login shell. */
	sprintf(arg0, "-%s", lastpart(shell));
	av[0] = arg0;
	av[1] = (char *)0;

	execve(shell, av, env);

	/* ENOMEM here means the bank-0 stack arena cannot fund this shell.
	 * Falling back to /bin/sh (12 pages against tcsh's 55) keeps the
	 * session rather than dropping the user back to a login prompt they
	 * cannot get past.  This ships WITH the feature, not after it: until
	 * the console-lane swap (slice B3) lands it is the only backstop
	 * against the arena ceiling. */
	if (errno == ENOMEM && strcmp(shell, "/bin/sh") != 0) {
		printf("login: %s: out of memory, falling back to /bin/sh\n",
		       shell);
		av[0] = "-sh";
		execve("/bin/sh", av, env);
	}
	perror("login: exec");
	return 1;
}
```

- [ ] **Step 4: Register provenance**

Add a row to `PROVENANCE.md` for `src/userland/login/login.c` citing
`vendor/2.11BSD/usr/bin/login/login.c`, in the format the existing rows use.

- [ ] **Step 5: Run the test to verify it passes**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/check_provenance.py
python3 tools/mame_test/run.py logintest
```

Expected: `LOGINTEST PASS`.  If it hangs at `Password:`, the likely cause is
`getpass` reading fd 0 when the pty slave is not on fd 0 -- check the `spawnx`
file-actions in `logintest`, not `getpass`.

- [ ] **Step 6: Prove the test discriminates**

Temporarily change the password comparison to `if (pw != (struct passwd *)0)`
(accept anything), rebuild, re-run.  Expected: **LT1 FAIL** -- the wrong
password now reaches a shell.  Revert, rebuild, confirm PASS.  If LT1 still
passes with authentication bypassed, the test is worthless; fix it before
committing.

- [ ] **Step 7: Write login(1) and commit**

Create `src/userland/man/pages/cat1/login.0` covering the flow, the environment
it sets, `TTY_SECURE`, the `$`-tagged hash and its explicitly limited threat
model, and the ENOMEM fallback.  Add its staging rows.

```bash
git add src/userland/login/login.c src/userland/logintest/logintest.c \
        src/userland/man/pages/cat1/login.0 \
        tools/mame_test/tests/logintest.json tools/ninja/manifest.json \
        PROVENANCE.md build.ninja
git commit -m "feat(login): authenticate against /etc/passwd and exec the shell

Hybrid port of 2.11BSD login.c: the ~150-line core lifts cleanly, the other
450 lines (quota, setpriority, initgroups, setlogin, lastlog, syslog,
tzfile, Kerberos, -h) are deleted.

EXEC, not spawn, so getty -> login -> shell holds one task's bank-0 stack
rather than three.  The ENOMEM fallback to /bin/sh ships with the feature:
3 x tcsh is 168 pages against a 149-page arena, and until slice B3 lands
this is the only thing between a user and a session they cannot start.

logintest drives the whole chain over a pty.  Its load-bearing case is the
WRONG password: a login that never checks would pass every other assertion."
```

---

## Task 6: `init` -- itab, respawn, throttle, SIGHUP, SIGTERM

**Files:**
- Modify: `src/userland/init/init.c` (rewrite)
- Create: `tools/mame_test/tests/initrespawn.json`
- Create: `src/userland/man/pages/cat8/init.0`
- Modify: `tools/ninja/manifest.json`, `PROVENANCE.md`

**Interfaces:**
- Consumes: `getttyent`/`setttyent`/`endttyent` (task 1), `/bin/getty` (task 4).
- Produces: PID 1 behaviour.  Task 7 (`halt`) relies on init exiting cleanly on
  SIGTERM.

**Do this task last among the programs.**  A broken PID 1 is an unbootable disk
with no diagnostic, and everything below it has already been exercised from a
shell.

**Kept from the current stub, all still load-bearing:**
- `chdir("/root")`.
- `sh /etc/rc` run to completion *before* any getty.  The vendored rc sources
  `/etc/netstart`, where dhclient leases; gettys must not prompt before the
  network is up.  A missing or failing rc is not fatal.
- The `waitpid` loop must tolerate reaping reparented orphans -- a blanket
  `wait()` that treats any reaped pid as "a line died" would respawn the wrong
  line.
- The `spawnve` argv/envp `static int[]`-at-file-scope ABI (see Global
  Constraints).  `execve`'s convenience does NOT apply to `spawnve`.

**New:**
- `itab[]`: for each `/etc/ttys` line with `TTY_ON`, the name, the getty
  command, the running pid, and a spawn-time ring for the throttle.
- Respawn on child exit, matched by pid to an itab slot.
- Throttle: more than `GETTYCNT` (5) spawns within `GETTYTIME` (60) seconds on
  one line disables that line and logs it, so a broken `ty_getty` cannot spin.
- SIGHUP: re-read `/etc/ttys`; new lines start, removed or `off` lines have
  their child killed, unchanged lines are left alone.
- SIGTERM: stop respawning, kill every child, `sync`, exit -- which halts the
  machine, since init has no parent.
- Environment seeding survives **only** for a `ty_getty` that is a bare shell:
  ttyv0 ships as `/bin/sh` with no `login` in between, so init still passes
  `PATH`/`HOME`/`TERM`.  Lines that run `/bin/getty` get their environment from
  `login` instead.

- [ ] **Step 1: Write the failing test**

`tools/mame_test/tests/initrespawn.json` -- proves respawn without needing a
second console.  `/bin/sh` on ttyv0 is init's child; killing it must produce a
fresh prompt rather than a halt.

```json
{
 "name": "initrespawn",
 "description": "init respawns a dead line instead of halting",
 "command": "echo MARK1 > /root/rs; kill -9 $$",
 "post_commands": ["echo MARK2"],
 "timeout_s": 120,
 "expect": {
  "screen_contains": ["MARK2"],
  "disk_files": [{"path": "/root/rs", "size": 6}]
 }
}
```

`MARK2` can only appear if a second shell reached a prompt after the first was
killed, which is exactly the respawn claim.  Confirm the runner's
`post_commands` timing against `tools/mame_test/run.py`'s docs before relying
on it; if the frame budget is too tight, raise `timeout_s` rather than weakening
the assertion.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/mame_test/run.py initrespawn
```

Expected: FAIL -- today's init waits on that one pid and exits when it dies, so
the machine halts and `MARK2` never appears.

- [ ] **Step 3: Rewrite init**

Keep the existing file's header comments about the `spawnve` ABI and the rc
ordering -- they document traps that cost real debugging time and are still
true.  Replace the single spawn/wait with:

```c
#define NITAB     8
#define GETTYCNT  5
#define GETTYTIME 60

struct itab {
	char name[16];
	char cmd[64];
	char type[16];
	int  pid;              /* 0 = not running */
	int  count;            /* spawns inside the current window */
	long window;           /* start of the current window, seconds */
	int  disabled;
};
static struct itab itab[NITAB];
static int nitab;
static int shutting_down;
```

with `readttys()` filling `itab` from `getttyent()` (skipping lines without
`TTY_ON`), `startline(i)` doing the spawn with the throttle check,
`sighup()` re-reading and reconciling, and `sigterm()` setting
`shutting_down` and killing children.  `main()` becomes: `chdir`, run rc,
`readttys`, start every line, then loop on `wait()` matching the reaped pid to
an itab slot and restarting it unless `shutting_down` or `disabled`.

The spawn itself keeps the existing `static int[]` file-scope tables. Each line
is opened onto the child's 0/1/2 via `spawnx` file actions, the same recipe
`ptyshell` uses -- getty does not open its own line.

- [ ] **Step 4: Run the test to verify it passes**

```bash
ninja -f build.ninja all
python3 tools/mame_test/run.py initrespawn
python3 tools/mame_test/run.py ttysprobe logintest
tools/gate.sh
```

Expected: all green.  `gate.sh` is the real check here -- it boots the disk and
runs `ls /`, which is precisely "kernel starts, init runs, a shell reaches a
prompt".

- [ ] **Step 5: Prove the throttle works**

Add a fourth line to a scratch copy of `/etc/ttys` pointing `ty_getty` at
`/bin/false`, boot, and confirm init disables it after 5 spawns and logs a
message rather than spinning.  Do NOT ship that line -- revert `/etc/ttys`
before committing.  Record what you observed in the commit message.

- [ ] **Step 6: Commit**

```bash
git add src/userland/init/init.c src/userland/man/pages/cat8/init.0 \
        tools/mame_test/tests/initrespawn.json tools/ninja/manifest.json \
        PROVENANCE.md build.ninja
git commit -m "feat(init): itab respawn engine driven by /etc/ttys

Workalike of 2.11BSD init keeping the part worth having -- the line table,
the respawn loop, the gettytime/gettycnt throttle, the SIGHUP re-read --
and dropping sysctl, reboot(2), syslog, autoconfig, securelevel, the
single-user transition and the window-system fork.

Two things carried forward from the stub because they are load-bearing:
sh /etc/rc runs to completion FIRST (netstart leases there; a getty that
prompts before the network is up races the MAME gates), and the wait loop
matches pids to lines rather than treating any reaped orphan as a dead
line.

Environment seeding survives only for a bare-shell ty_getty, which is what
ttyv0 ships as.  Lines running /bin/getty get their environment from login.

initrespawn is the discriminating test: MARK2 can only reach the screen if
a second shell reached a prompt after the first was killed."
```

---

## Task 7: `/sbin/halt`

**Files:**
- Create: `src/userland/halt/halt.c`
- Create: `tools/mame_test/tests/haltcmd.json`
- Create: `src/userland/man/pages/cat8/halt.0`
- Modify: `tools/ninja/manifest.json`

**Interfaces:**
- Consumes: init's SIGTERM handling (task 6).
- Produces: `/sbin/halt`.

Once init respawns, exiting a shell no longer halts the machine -- it gets you a
fresh one.  `halt` is the replacement path.

- [ ] **Step 1: Write the failing test**

```json
{
 "name": "haltcmd",
 "description": "halt signals init, which stops respawning and halts the machine",
 "command": "/sbin/halt",
 "timeout_s": 90,
 "expect": {
  "exit_clean": true
 }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/mame_test/run.py haltcmd
```

Expected: FAIL -- no `/sbin/halt`, so MAME is killed on timeout rather than
exiting cleanly.

- [ ] **Step 3: Write halt**

```c
/* halt(8) - stop the machine.
 *
 * FGX-Provenance: none.  2.11BSD's halt calls reboot(2) with RB_HALT; FGX has
 * no reboot(2).  Here the shutdown authority is init: it stops respawning,
 * kills its children, syncs, and exits -- and since init has no parent, the
 * kernel halts (see _Kern_Halt).  So halt is one signal.
 */
#include <stdio.h>
#include <signal.h>
#include <unistd.h>

int
main(argc, argv)
	int argc;
	char **argv;
{
	sync();
	if (kill(1, SIGTERM) < 0) {
		perror("halt: cannot signal init");
		return 1;
	}
	for (;;)
		pause();          /* init is tearing the system down */
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/mame_test/run.py haltcmd
```

Expected: PASS with `exit_clean`.

- [ ] **Step 5: Write halt(8) and commit**

```bash
git add src/userland/halt/halt.c src/userland/man/pages/cat8/halt.0 \
        tools/mame_test/tests/haltcmd.json tools/ninja/manifest.json \
        build.ninja
git commit -m "feat(halt): stop the machine by signalling init

Respawn removed the old shutdown path -- exiting the console shell now just
gets you a fresh one.  init is the shutdown authority, so halt is a single
SIGTERM to pid 1; init kills its children, syncs and exits, and with no
parent the kernel halts exactly as before.

No reboot(2) to call, unlike 2.11BSD's halt."
```

---

## Task 8: `/bin/passwd`

**Files:**
- Create: `src/userland/passwd/passwd.c`
- Create: `src/userland/man/pages/cat1/passwd.0`
- Modify: `tools/ninja/manifest.json`, `PROVENANCE.md`
- Modify: `src/userland/logintest/logintest.c` (add the change-password case)

**Interfaces:**
- Consumes: `getpwnam`/`getpwuid` (existing), `getpass` (task 3), `crypt`
  (task 2).
- Produces: `/bin/passwd`.

The vendored source (265 lines) is built around `ndbm`, `/etc/ptmp` locking and
`mkpasswd`.  FGX has none of those, so this is a flat-file rewrite: read
`/etc/passwd`, verify the old password (unless uid 0), prompt for the new one
twice, rewrite the file through a temp file, rename.  Needs a `PROVENANCE.md`
row.

- [ ] **Step 1: Write the failing test**

Add LT4 to `logintest`: run `/bin/passwd` over the pty as root, change the
password, then confirm a fresh `login` accepts the NEW password and rejects the
old one.  The rejection half is the discriminating assertion -- a `passwd` that
writes nothing passes the acceptance half if the old and new happen to match.

Restore the original password at the end of the case so the test is
re-runnable, and assert that restoration succeeded.

- [ ] **Step 2: Run it to verify it fails**

```bash
python3 tools/mame_test/run.py logintest
```

Expected: LT4 FAIL, no `/bin/passwd`.

- [ ] **Step 3: Write passwd**

Salt: derive two characters from the current time (`time(0)`), not a constant --
a fixed salt means two users with the same password get the same hash, which
`ttysprobe` assertion 11 exists to make visible.

Write through a temp file in the same directory and `rename` over
`/etc/passwd`; never truncate the live file, because a crash mid-write would
leave a machine nobody can log into.

- [ ] **Step 4: Run the test to verify it passes**

```bash
python3 tools/ninja/gen.py && ninja -f build.ninja all
python3 tools/check_provenance.py
python3 tools/mame_test/run.py logintest
```

Expected: `LOGINTEST PASS` with LT1-LT4.

- [ ] **Step 5: Commit**

```bash
git add src/userland/passwd/passwd.c src/userland/man/pages/cat1/passwd.0 \
        src/userland/logintest/logintest.c tools/ninja/manifest.json \
        PROVENANCE.md build.ninja
git commit -m "feat(passwd): change a password in /etc/passwd

Flat-file rewrite of 2.11BSD passwd: no ndbm, no /etc/ptmp, no mkpasswd.
Writes through a temp file and renames, so a crash mid-write cannot leave a
machine nobody can log into.

Salt comes from time(0), not a constant: a fixed salt would give two users
with the same password identical hashes.

LT4 asserts the OLD password stops working, not just that the new one
starts -- a passwd that writes nothing would pass the acceptance half."
```

---

## Task 9: Budget fence and documentation

**Files:**
- Modify: `tools/check_stack_budget.py`
- Modify: `docs/ROADMAP.md`, `docs/CHANGELOG.md`

**Interfaces:**
- Consumes: every binary from tasks 4-8.
- Produces: the regression fence that catches the arena arithmetic drifting.

- [ ] **Step 1: Add the multi-console scenarios**

In `SCENARIOS` (`tools/check_stack_budget.py:68`), add:

```python
    "three consoles idle at a login prompt":
        ["getty", "getty", "getty"],
    "one deep shell plus two light consoles":
        ["tcsh", "sh", "sh"],
    "deep shell plus tool, two light consoles":
        ["tcsh", "tar", "sh", "sh"],
    "login exec transient on a third console":
        # login EXECs the shell, so login's pages are freed -- but execve
        # allocates the new stack while the old allocation is still held
        # (process.s:1494), so (login + shell) IS momentarily co-resident.
        ["tcsh", "sh", "login", "sh"],
```

**`init` is deliberately NOT in any of these.**  The file's header explains why:
init keeps its static `$3100` page from `main.s`, outside the arena, so it costs
the arena nothing.  Adding it would silently inflate every sum.

The scenarios file is the point of the whole exercise -- add a scenario when a
co-residency becomes real, per its own header comment, which already anticipates
this slice.

- [ ] **Step 2: Run it**

```bash
python3 tools/check_stack_budget.py --self-test
python3 tools/check_stack_budget.py -v
```

Expected: green, with the new scenarios listed and their page sums shown.  If
"one deep shell plus two light consoles" exceeds 149, stop and report the numbers
rather than raising the arena -- that coupling produced the same production bug
twice in two days (2026-07-27 and 2026-07-28).

Note the checker silently skips a scenario naming a binary that does not exist
(`run.py` prints a NOTE) -- read the output and confirm `getty` is actually
being counted, not skipped.

- [ ] **Step 3: Update the roadmap and changelog**

`docs/ROADMAP.md`: replace the "once there is a real init/getty/login" note
around line 472 with what shipped, keeping it to a paragraph and pointing at
the design doc.  `docs/CHANGELOG.md`: an entry explaining the change in terms of
what a user sees -- the machine boots to a shell on console 1 as before, ttyv1
and ttyv2 want a login, and `exit` no longer halts the machine (`halt` does).

- [ ] **Step 4: Full verification**

```bash
tools/gate.sh
python3 tools/mame_test/run.py ttysprobe logintest initrespawn haltcmd
python3 tools/check_provenance.py
python3 tools/check_stack_budget.py
```

Expected: all green.  Report the actual output; do not summarize a run you did
not complete.

- [ ] **Step 5: Commit**

```bash
git add tools/check_stack_budget.py docs/ROADMAP.md docs/CHANGELOG.md
git commit -m "test(stack): budget scenarios for the login chain

Three idle gettys, and one deep shell alongside two light ones.  The
checker's own header says to add a scenario when a co-residency becomes
real -- three consoles is exactly that, and the sum is what the twice-
recurring arena bug (2026-07-27, 2026-07-28) came from getting wrong.

Roadmap and changelog record what shipped and what changed for a user:
exit no longer halts the machine, halt does."
```

---

## Self-Review

**Spec coverage.** Every section of the design maps to a task: libc additions ->
tasks 1-3; getty -> 4; login -> 5; init -> 6; halt -> 7; passwd -> 8; `/etc`
files -> tasks 1 (`ttys`), 2 (`passwd`), 4 (`issue`); testing table -> the test
steps in 1, 5, 6, 7 and the fence in 9; man pages -> the tasks that create each
tool.  Slice D is deliberately out of scope and gets its own plan.

**Deferred, carried from the design:** real DES `crypt`, `grp.h`/`/etc/group`/
`initgroups`, utmp/wtmp beyond `ut_line`.

**Known ceiling, not a gap:** 3 x tcsh is 168 pages against a 149-page arena.
Task 5's ENOMEM fallback is the mitigation; slice B3 is the fix, and neither is
in this plan.

**Open risk to check during task 6:** `run.py`'s `post_commands` frame timing
for `initrespawn`.  If it proves unreliable, express the same claim with an
`exit_marker` or a longer timeout -- do not weaken the assertion to something a
non-respawning init would also pass.
