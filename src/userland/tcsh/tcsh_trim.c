/*
 * tcsh_trim.c -- FGX P1 build: replacements for the SIX translation units
 * dropped to fit the kernel's 7-code-bank ceiling.
 *
 * WHY THIS FILE EXISTS.  Measured tcsh code is 466,002 B; seven banks hold
 * 425,634 B (TCB_BankList is 8 entries and one is the DATA bank), so the build
 * is 40,368 B over.  config_f.h is not a lever -- it is already minimal and
 * tcsh 6.00 has no EDIT switch.  Six optional TUs are dropped:
 * tc.bind, tc.who, sh.time, tc.sched, tw.spell, tw.help =
 * 44,882 B.  The drop set was picked by measuring, for every TU, how many of
 * its globals other TUs reference -- these six are the largest with the fewest
 * external hooks.  sh.dir looked attractive at 23,398 B and IS config-gated
 * (CSHDIRS), but it owes dcanon/dnormalize/dtilde/getstakd to core cd, tilde
 * and glob handling, so dropping it would have broken ordinary path handling.
 *
 * WHAT IS LOST, stated plainly rather than silently: the bindkey and bind
 * builtins, watch/log reporting, the time and nice builtins, sched, spelling
 * correction, run-help, and PROMPT % ESCAPE EXPANSION (%m, %n, %/, %h, time,
 * attributes...).  The prompt itself still works and still honours prompt,
 * prompt2 and prompt3 -- the string is just printed literally.  Everything
 * else -- the editor, completion, history, job control, the directory stack,
 * globbing, expression evaluation -- is untouched.
 *
 * The no-op hooks below are called from loops and startup paths in TUs that
 * were KEPT, so they must exist and must be harmless.  The two functions at
 * the bottom are different: they are lifted VERBATIM from the pristine
 * tc.bind.c because non-optional code needs them -- tc.prompt calls
 * parseescape for prompt escapes and ed.xmap calls u_p_string to display key
 * bindings.  Neither is part of what was dropped, so stubbing them would have
 * quietly degraded the prompt and the keymap display.  They are copied, not
 * reimplemented, so they stay behaviourally identical; if tc.bind is ever
 * linked again, delete this file rather than reconciling two copies.
 */
/* config.h FIRST, then sh.h -- exactly as every tcsh TU does.  sh.h does NOT
 * include config.h itself, and without it BSDTIMES is undefined, which exposes
 * sh.h's `#ifndef BSDTIMES` arm and its `struct tms shtimes;` tentative
 * definition against an incomplete struct tms. */
#include "config.h"
#include "sh.h"

static void
trim_unavail(what)
    char *what;
{
    xprintf("%s: not available in this build (dropped for code size)\n", what);
}

/* ---- dropped builtins: reachable from the sh.init builtin table ---------- */
void dobind(v)    Char **v; { trim_unavail("bind"); }
void dobindkey(v) Char **v; { trim_unavail("bindkey"); }
void dolog(v)     Char **v; { trim_unavail("log"); }
void donice(v)    Char **v; { trim_unavail("nice"); }
void dosched(v)   Char **v; { trim_unavail("sched"); }
void dotime()               { trim_unavail("time"); }

/* ---- watch (tc.who): hooks on the main-loop / startup paths -------------- */
void initwatch()   { }
void resetwatch()  { }
void watch_login() { }

/* ---- sched (tc.sched): main-loop hooks ---------------------------------- */
void sched_run()   { }

/* sched_next returns the next scheduled event time; "never" is 0 so the main
 * loop's timeout comparison treats it as nothing pending. */
long
sched_next()
{
    return 0L;
}

/* ---- time/nice (sh.time): job-timing helpers ---------------------------- */
/* settimes records process start times at startup; with the time builtin gone
 * nothing reads them.  prusage prints a usage line for `time`.  ruadd/tvsub
 * are timeval arithmetic used only by that reporting path. */
void settimes() { }
void prusage(r0, r1, e, b)
    struct rusage *r0, *r1;
    tmval_t *e, *b;
{ }
void ruadd(ru, ru2)
    struct rusage *ru, *ru2;
{ }
void tvsub(tdiff, t1, t0)
    tmval_t *tdiff, *t1, *t0;
{ }

/* ---- spelling correction (tw.spell) ------------------------------------- */
/* spell_me returns non-zero when it CHANGED the name; always report "no
 * correction" so callers use the name the user typed. */
int spell_me(oldname, oldsize, look_cmd)
    Char *oldname;
    int   oldsize, look_cmd;
{
    return 0;
}

/* spdist is an edit distance; -1 means "too far to suggest". */
int spdist(s, t)
    Char *s, *t;
{
    return -1;
}

int spdir(extended_name, tilded_dir, entry, name)
    Char *extended_name, *tilded_dir, *entry, *name;
{
    return 0;
}

/* ---- the `alloc` builtin (showall) -------------------------------------- */
/* showall() dumps the allocator's per-bucket statistics.  It is defined TWICE
 * upstream: in alloc11.c, which FGX does not link because it also defines
 * malloc/free/realloc and would collide with the shared libc pile; and in
 * tc.alloc.c inside `#ifndef SYSMALLOC`, which config_f.h defines -- so both
 * copies are gone and the sh.init builtin table still names it.  FGX uses libc's
 * MM-native allocator, which keeps no per-bucket histogram, so there is nothing
 * truthful to print. */
/* `void showall(void)`, not K&R `showall()`: tc.decls.h declares it
 * `extern void showall __P((void))` and fcc treats the empty-paren definition as
 * a conflicting redefinition of that prototype. */
void
showall(void)
{
    trim_unavail("alloc");
}

/* ---- prompt: RESTORED (2026-07-27) -------------------------------------- */
/* The minimal literal-print printprompt that lived here is GONE: the real
 * tc.prompt.c is linked again (% escape expansion was a user-visible loss,
 * and the two reasons for dropping it no longer hold -- the segment cap rose
 * from 7 to 9 code banks on 2026-07-26, and libc grew localtime/struct tm).
 * The six size-trimmed TUs above are still out. */

/* ---- run-help (tw.help) ------------------------------------------------- */
void do_help(command)
    Char *command;
{
    trim_unavail("run-help");
}

/* ---- VERBATIM from the pristine tc.bind.c (see header note) ------------- */
int
parseescape(ptr)
    Char  **ptr;
{
    Char   *p, c;

    p = *ptr;

    if ((p[1] & CHAR) == 0) {
	xprintf("Something must follow: %c\\n", *p);
	return 0;
    }
    if ((*p & CHAR) == '\\') {
	p++;
	switch (*p & CHAR) {
	case 'a':
	    c = '\007';		/* Bell */
	    break;
	case 'b':
	    c = '\010';		/* Backspace */
	    break;
	case 't':
	    c = '\011';		/* Horizontal Tab */
	    break;
	case 'n':
	    c = '\012';		/* New Line */
	    break;
	case 'v':
	    c = '\013';		/* Vertical Tab */
	    break;
	case 'f':
	    c = '\014';		/* Form Feed */
	    break;
	case 'r':
	    c = '\015';		/* Carriage Return */
	    break;
	case 'e':
	    c = '\033';		/* Escape */
	    break;
	case '0':
	case '1':
	case '2':
	case '3':
	case '4':
	case '5':
	case '6':
	case '7':
	    {
		register int cnt, val, ch;

		for (cnt = 0, val = 0; cnt < 3; cnt++) {
		    ch = *p++ & CHAR;
		    if (ch < '0' || ch > '7') {
			p--;
			break;
		    }
		    val = (val << 3) | (ch - '0');
		}
		if ((val & 0xffffff00) != 0) {
		    xprintf("Octal constant does not fit in a char.\n");
		    return 0;
		}
		c = val;
		--p;
	    }
	    break;
	default:
	    c = *p;
	    break;
	}
    }
    else if ((*p & CHAR) == '^') {
	p++;
	c = (*p == '?') ? '\177' : ((*p & CHAR) & 0237);
    }
    else
	c = *p;
    *ptr = p;
    return (c);
}

unsigned char *
u_p_string(str, buf)
    Char   *str;
    unsigned char *buf;
{
    unsigned char *b;
    Char   *p;

    b = buf;
    *b++ = '"';
    if (*str == 0) {
	*b++ = '^';
	*b++ = '@';
	*b++ = '"';
	*b++ = 0;
	return buf;
    }

    for (p = str; *p != 0; p++) {
	if (Iscntrl(*p)) {
	    *b++ = '^';
	    if (*p == '\177')
		*b++ = '?';
	    else
		*b++ = *p | 0100;
	}
	else if (*p == '^' || *p == '\\') {
	    *b++ = '\\';
	    *b++ = *p;
	}
	else if (*p == ' ' || (Isprint(*p) && !Isspace(*p))) {
	    *b++ = *p;
	}
	else {
	    *b++ = '\\';
	    *b++ = ((*p >> 6) & 7) + '0';
	    *b++ = ((*p >> 3) & 7) + '0';
	    *b++ = (*p & 7) + '0';
	}
    }
    *b++ = '"';
    *b++ = 0;
    return buf;			/* should check for overflow */
}
