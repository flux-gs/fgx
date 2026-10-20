/* system.c - FGX machine layer for elvis: shell-escape / filter seam.
 *
 * elvis's vendored system.c (vendor/netbsd-0-9/usr.bin/elvis/system.c) is the
 * UNIX version: it defines its own system() and implements rpipe()/filter() with
 * fork()/pipe()/exec, none of which FGX has.  Its system() also collides with
 * libc's system (which already does the right thing: posix_spawn "/bin/sh" -c
 * cmd, then wait).  FGX therefore supplies this replacement TU and the elvis
 * build compiles it in place of the vendored system.c (kept pristine), exactly
 * as it does for unix.c (the ttyread seam).
 *
 * FIRST-BOOT STUBS (task #28, machine-layer seam).  `system(cmd)` itself is NOT
 * defined here -- elvis's system() calls resolve to libc's system() (spawn+wait).
 * The remaining shell-escape primitives are stubbed so the editor links and
 * boots; `:!cmd` filtering, `:r !cmd`, and `!motion` are wired up in a later
 * pass:
 *   rpipe/rpclose  - run cmd with its stdout on a pipe (`:r !cmd`)      -> later
 *   filter         - filter a line range through cmd (`:!` / `!motion`) -> later
 *   wildcard       - filename glob expansion; passthrough is correct for
 *                    literal (unglobbed) filenames, which is all first boot needs
 */

typedef long MARK;   /* elvis vi.h: a buffer position (matches the callers) */

/* errno is REAL now (quick-wins 2026-07-06: libc_data.s owns the cell and the
 * syscall shims store into it) — elvis just declares it.  The old `int errno;`
 * definition here now collides with libc_data.s at link time. */
extern int errno;

/* :r !cmd  -- run cmd and read its output.  Stub: no input pipe yet. */
int rpipe(cmd, in)
	char	*cmd;	/* the command to run */
	int	in;	/* fd to use as the command's stdin */
{
	return -1;	/* "couldn't start" -- elvis reports the failure */
}

int rpclose(fd)
	int	fd;
{
	return 0;
}

/* Filename glob expansion.  Passthrough: return the names unchanged so elvis
 * opens them literally (no globbing at first boot). */
char *wildcard(names)
	char	*names;
{
	return names;
}

/* :!cmd / !motion  -- filter a line range through a shell command.  Stub. */
int filter(from, to, cmd, back)
	MARK	from, to;	/* the range of lines to filter */
	char	*cmd;		/* the filter command */
	int	back;		/* nonzero: read the output back in */
{
	return -1;	/* filtering not available yet */
}

/* access(): THE PROBE IS GONE -- it issues the real SYS_ACCESS (33) now, which
 * landed with UFS 2.6 (apple/fgx#320).  It used to open(O_RDONLY) and call that
 * existence, because FGX had no access(2) and the even older `return 0' made
 * tmpstart's temp-name loop -- `do { sprintf(tmpname,...) } while
 * (access(tmpname,0) == 0)' -- spin forever, since no generated name ever
 * looked free.
 *
 * IT STILL SHADOWS libc's access, AND ONLY FOR THE KEYMAP HOOK.  apple/fgx#324
 * asks for this definition to be deleted so libc's is used, and that is right
 * except for one thing: `fgx_elvis_keymaps' has exactly ONE caller and this is
 * it.  The hook is written to be called repeatedly and do nothing until
 * initscr() has set KU, so access() was chosen because elvis calls it often --
 * delete this and the arrow-key and Delete maps are never installed, silently.
 * WHAT WOULD REMOVE THE DUPLICATION is a call to fgx_elvis_keymaps() after
 * initscr() in elvis proper; until then the body is a one-line delegation and
 * not a second implementation of the semantics. */
void fgx_elvis_keymaps();	/* defined below; one-shot, safe to call often */

int access(path, mode)
	char	*path;
	int	mode;
{
	int	r;

	fgx_elvis_keymaps();		/* one-shot; see the keymap block below */

	r = (int)__syscall(33, (unsigned)(unsigned long)path,
			   (unsigned)mode, 0);
	if (__syscall_c() == 0)
	{
		errno = r;
		return -1;
	}
	return 0;
}

/*----------------------------------------------------------------------------
 * termlib client cells.
 *
 * termlib declares `extern char *UP, *BC;` and expects its CLIENT to define
 * them (toolchain/lib/libtermlib_c/libtermlib.c).  elvis's vendored curses.c
 * defines UP but guards BC under `#if OSK`, so BC has no definition and the
 * link fails without one here.  Null leaves tgoto's `(BC ? BC : "\b")` at the
 * backspace fallback, exactly as when elvis never set it.
 *
 * In BSD termlib OWNS both cells; that this seam has to supply one is an FGX
 * divergence, tracked with the rest of them on apple/fgx#151.
 *--------------------------------------------------------------------------*/
char *BC;

/*----------------------------------------------------------------------------
 * FGX-installed elvis key maps.
 *
 * Two additive maps FGX needs that vendored main.c doesn't install.  Both use
 * elvis's OWN keymap, which routes by `when`.  mapkey() lives in tio.c;
 * KU/KD/KL/KR are the termcap ku/kd/kl/kr sequences (curses.c), non-null once
 * initscr() has run.
 *
 * WHY THE HOOK IS HERE, AND LAZY.  main.c installs its own arrow maps right
 * after initscr() (main.c:129-150), which is exactly the right moment -- but
 * main.c is vendored, and between initscr() and the input loop elvis calls
 * nothing else FGX owns.  This used to be installed from the first ttyread(),
 * back when FGX replaced elvis's unix.c; that replacement is gone (#151), so
 * the hook moved to the first access(), which tmpstart() issues unconditionally
 * in its temp-name loop (tmp.c:200) and therefore always runs, once, after
 * initscr().  The KU test doubles as the ordering guard: if a caller ever gets
 * here before initscr(), nothing is installed and the next call retries.
 *
 * (1) ex ':'-line arrow no-ops (WHEN_EX = 8).
 * The FGX console emits cursor arrows KERNEL-WIDE as vt100 escape sequences.
 * In vi command mode main.c maps those to h/j/k/l motions (WHEN_VICMD|INMV),
 * but the ex ':' command line (vgets) has NO arrow maps: the interactive ':'
 * reads via getabkey(WHEN_EX), so a naked arrow arrives as a bare ESC which
 * vgets treats as "submit the line" (case ctrl('[')) -- firing the half-typed
 * command and spilling '[x' as garbage.  vi's ex line is append/erase only, so
 * the vi-authentic behavior is a no-op: map each arrow, under WHEN_EX, to
 * " \b" (append a space, erase it), which leaves the buffer intact.  mapkey()'s
 * dedup keys on rawin AND overlapping mode bits, so these coexist with the
 * WHEN_VICMD motion maps for the same sequence.
 *   Corner: at a full ex line (len == bsize-1) the space hits vgets' beep()
 *   branch without appending, but the '\b' still decrements len -- so an arrow
 *   on a ~150-char ex command beeps AND drops its last char.  Inherent to the
 *   append-then-erase idiom, needs a near-max line, negligible.
 *
 * (2) command-mode Delete = destructive backspace (WHEN_VICMD = 1).
 * The IIgs Delete key sends $7F, which elvis (ERASEKEY = kernel sg_erase = $7F)
 * remaps to '\b' (tio.c) -- making Delete identical to ^H (a non-destructive
 * left motion in command mode).  Delete should be a DESTRUCTIVE backspace while
 * ^H/Left stay non-destructive.  Mapping $7F -> "X" (vi's delete-char-to-left)
 * in WHEN_VICMD does this: execmap rewrites keybuf[next] to 'X' BEFORE tio.c's
 * `== ERASEKEY` remap check, so the map preempts the '\b' collapse.  Insert
 * mode keeps vi-native (non-destructive) '\b' -- making it destructive would
 * need a vendored input.c edit.  At column 0 vi's `X` is a no-op.
 *--------------------------------------------------------------------------*/
extern char	*KU, *KD, *KL, *KR;	/* curses.c: arrow key sequences */
void mapkey();				/* tio.c                        */

void fgx_elvis_keymaps()
{
	static int	inited;

	if (inited || !KU)
	{
		return;			/* done, or initscr() has not run yet */
	}
	inited = 1;

	/* (1) ex-line arrow no-ops */
	mapkey(KU, " \b", 8 /*WHEN_EX*/, "<exUp>");
	if (KD) mapkey(KD, " \b", 8 /*WHEN_EX*/, "<exDown>");
	if (KL) mapkey(KL, " \b", 8 /*WHEN_EX*/, "<exLeft>");
	if (KR) mapkey(KR, " \b", 8 /*WHEN_EX*/, "<exRight>");

	/* (2) command-mode Delete -> destructive delete-left */
	mapkey("\177", "X", 1 /*WHEN_VICMD*/, "<Del>");

	/* (3) ex ':'-line Delete -> DESTRUCTIVE backspace.  On the visual ':' line
	 * (vgets, MODE_VI) plain erase removes the char from the buffer but skips
	 * clrtoeol, so the glyph stays on screen ("cursor moves back, char stays").
	 * Map $7F, under WHEN_EX, to "\b \b" -- back up, overwrite the char with a
	 * space, back up again -- which clears the glyph AND drops one char from the
	 * buffer (net len-1).  Coexists with the WHEN_VICMD "<Del>" map above (same
	 * rawin, disjoint mode bits).  At column 0 the leading '\b' cancels the ':'
	 * line (vgets returns -1), matching backspace-past-prompt. */
	mapkey("\177", "\b \b", 8 /*WHEN_EX*/, "<exDel>");
}

/* NOTE: ioctl(), kill(), signal(), geteuid(), sleep(), sync(), getwd() and
 * index() are NOT defined here -- libc provides them, and a C definition would
 * shadow libc's for elvis's own calls.  ioctl in particular MUST resolve to
 * libc: a `return 0` stub made TIOCGETP silently no-op, so curses.c's
 * oldsgttyb (hence ERASEKEY) stayed garbage and DELETE echoed ^? in the ':'
 * line instead of erasing. */
