/* driver.c -- the far-pointer sweep driver (seg0).  crt0_lib far-calls main and
 * SYS_EXITs with A.lo, so main's return value IS the process exit code.
 *
 *   preflight()  proves the binary is genuinely multi-bank; if not, exit 99
 *                (no construct result is trustworthy -- fails CLOSED).
 *   then run EVERY construct, emit a per-construct marker (survives a
 *   destructive wrong-bank write mid-run), exit 43 iff all pass else 100+id.
 *
 * Reserved exit codes: 43 green / 99 preflight / 100+id first-fail / else infra. */
extern void mb_mark(int, int);
extern void mb_end(int);
extern int  mb_bankof(void *);
extern char *malloc(unsigned long);   /* WIDE (M-4): a K&R empty-paren decl pushes 16-bit args where malloc reads a 32-bit size */

extern unsigned char c01_g[4];   /* a data-bank global (construct 1's tag) */
extern int  c15_callee(void);    /* extern callee pinned in a HIGH code bank */
extern int c01_check(void);
extern int c02_check(void);
extern int c03_check(void);
extern int c04_check(void);
extern int c05_check(void);
extern int c06_check(void);
extern int c07_check(void);
extern int c08_check(void);
extern int c09_check(void);
extern int c10_check(void);
extern int c11_check(void);
extern int c12_check(void);
extern int c13_check(void);
extern int c14_check(void);
extern int c15_check(void);
extern int c16_check(void);
extern int c17_check(void);
extern int c18_check(void);
extern int c19_check(void);
/* c20 (errno) deferred pending the libc errno seam (task #28). */
extern int c22_check(void);   /* gap: chained struct-ptr field (emit.c:1228) */
extern int c23_check(void);   /* gap: g[i].c[j]=p[k] indexed store (parse_stmt.c:2576) */
extern int c24_check(void);   /* gap: garr[i] op= x compound-assign (parse_stmt.c:2815) */
extern int c25_check(void);   /* gap: struct by-value arg / MVN (parse_stmt.c:3403) */
extern int c26_check(void);   /* gap: struct by-value arg, STATEMENT context (parse_stmt.c:3400 drift vs expr arm) */
extern int c27_check(void);   /* shim population: pipe(2) into a soft-stack local fd[2] (c_pipe bank) */
extern int c28_check(void);   /* shim population: atoi() on a soft-stack local string (c_atoi bank) */
extern int c29_check(void);   /* adapter: real signal() delivery into a cross-bank fcc C handler */
extern int c30_check(void);   /* errno: failing open() lands kernel ENOENT in the libc_data cell */
extern int c31_check(void);   /* shim: getcwd(2) into a soft-stack local buffer (c_getcwd bank) */
extern int c32_check(void);   /* shim: time(2) epoch from the RTC + store through soft-stack long* */
extern int c33_check(void);   /* shim: stat(2) st_mtime epoch synthesized from ProDOS date words */
extern int c34_check(void);   /* adapter: syscall A/C return preserved across signal delivery */
extern int c35_check(void);   /* NULL-return bank after mid-body implicit decl (Increment 4) */
extern int c36_check(void);   /* P3-2: ptr compare = full (offset,bank); stored-NULL bank stamp */
extern int c37_check(void);   /* P3-2: two live deref-chains in one expression */
extern int c38_check(void);   /* P3-2: FPR pressure — 6 ptr args + ternary ptr join */
extern int c39_check(void);   /* P3-2: ptr RETURN through cross-bank fn-ptr dispatch */
extern int c40_check(void);   /* unary deref of a decayed LOCAL array (*arr === arr[0]); elvis switch(*key) ESC/CR mole */
extern int c41_check(void);   /* train-2 0b: realloc MOVE path — returned heap ptr provenance (2nd-ptr verified) */
extern int c42_check(void);   /* train-2 0b: SPILLED/materialized ptr-local banks (slot + DP-IMG lower paths) */
extern int c43_check(void);
extern int c44_check(void);   /* &p[i].field on a far struct pointer -- the parse !128 added (K&R A.7.3.1) */   /* #6: truth test weighs the bank byte -- bank:0000 is NOT null, and NULL stays null */

static int preflight(void)
{
	char stackvar;
	unsigned char *dp = c01_g;              /* data-bank pointer  -> DBR */
	char *lp = &stackvar;                   /* soft-stack pointer -> soft-stack bank */
	char *hp = malloc(1);                   /* heap pointer       -> heap bank */
	int db = mb_bankof(dp);
	int cb = mb_bankof((void *)c15_callee); /* code bank of a HIGH-seg function */
	int ok = 1;

	/* Report each condition SEPARATELY (ids 90-92).  A bare exit 99 says
	 * "results untrustworthy" without saying why, and the answer decides
	 * whether the sweep, the compiler or the kernel moved -- a preflight
	 * that fails closed but silently costs a whole debugging session. */
	if (!hp)                    ok = 0;
	mb_mark(90, hp != 0);                   /* the heap allocated at all */
	if (db == cb)               ok = 0;
	mb_mark(91, db != cb);                  /* data seg shares a bank with code -> NOT multi-bank */
	if (mb_bankof(lp) == db)    ok = 0;
	mb_mark(92, mb_bankof(lp) != db);       /* soft stack collapsed onto DBR */

	/* The heap is DELIBERATELY in the data bank as of the malloc rework
	 * (issue #4): libc malloc now carves the task's own sbrk arena, and
	 * _Sys_Brk keeps the break inside the task DATA bank.  So "heap bank
	 * != DBR" is no longer a multi-bank signal -- it is a statement that
	 * the allocator still lives in the shared kernel arena, which is the
	 * very thing #4 removed.  Reported for visibility, NOT asserted. */
	mb_mark(93, mb_bankof(hp) != db);
	return ok;
}

int main(void)
{
	int first_fail = 0;
	int code;

	if (!preflight()) { mb_end(99); return 99; }

	{ int ok = c01_check(); mb_mark(1,  ok); if (!ok && !first_fail) first_fail = 101; }
	{ int ok = c02_check(); mb_mark(2,  ok); if (!ok && !first_fail) first_fail = 102; }
	{ int ok = c03_check(); mb_mark(3,  ok); if (!ok && !first_fail) first_fail = 103; }
	{ int ok = c04_check(); mb_mark(4,  ok); if (!ok && !first_fail) first_fail = 104; }
	{ int ok = c05_check(); mb_mark(5,  ok); if (!ok && !first_fail) first_fail = 105; }
	{ int ok = c06_check(); mb_mark(6,  ok); if (!ok && !first_fail) first_fail = 106; }
	{ int ok = c07_check(); mb_mark(7,  ok); if (!ok && !first_fail) first_fail = 107; }
	{ int ok = c08_check(); mb_mark(8,  ok); if (!ok && !first_fail) first_fail = 108; }
	{ int ok = c09_check(); mb_mark(9,  ok); if (!ok && !first_fail) first_fail = 109; }
	{ int ok = c10_check(); mb_mark(10, ok); if (!ok && !first_fail) first_fail = 110; }
	{ int ok = c11_check(); mb_mark(11, ok); if (!ok && !first_fail) first_fail = 111; }
	{ int ok = c12_check(); mb_mark(12, ok); if (!ok && !first_fail) first_fail = 112; }
	{ int ok = c13_check(); mb_mark(13, ok); if (!ok && !first_fail) first_fail = 113; }
	{ int ok = c14_check(); mb_mark(14, ok); if (!ok && !first_fail) first_fail = 114; }
	{ int ok = c15_check(); mb_mark(15, ok); if (!ok && !first_fail) first_fail = 115; }
	{ int ok = c16_check(); mb_mark(16, ok); if (!ok && !first_fail) first_fail = 116; }
	{ int ok = c17_check(); mb_mark(17, ok); if (!ok && !first_fail) first_fail = 117; }
	{ int ok = c18_check(); mb_mark(18, ok); if (!ok && !first_fail) first_fail = 118; }
	{ int ok = c19_check(); mb_mark(19, ok); if (!ok && !first_fail) first_fail = 119; }
	{ int ok = c22_check(); mb_mark(22, ok); if (!ok && !first_fail) first_fail = 122; }
	{ int ok = c23_check(); mb_mark(23, ok); if (!ok && !first_fail) first_fail = 123; }
	{ int ok = c24_check(); mb_mark(24, ok); if (!ok && !first_fail) first_fail = 124; }
	{ int ok = c25_check(); mb_mark(25, ok); if (!ok && !first_fail) first_fail = 125; }
	{ int ok = c26_check(); mb_mark(26, ok); if (!ok && !first_fail) first_fail = 126; }
	{ int ok = c27_check(); mb_mark(27, ok); if (!ok && !first_fail) first_fail = 127; }
	{ int ok = c28_check(); mb_mark(28, ok); if (!ok && !first_fail) first_fail = 128; }
	{ int ok = c29_check(); mb_mark(29, ok); if (!ok && !first_fail) first_fail = 129; }
	{ int ok = c30_check(); mb_mark(30, ok); if (!ok && !first_fail) first_fail = 130; }
	{ int ok = c31_check(); mb_mark(31, ok); if (!ok && !first_fail) first_fail = 131; }
	{ int ok = c32_check(); mb_mark(32, ok); if (!ok && !first_fail) first_fail = 132; }
	{ int ok = c33_check(); mb_mark(33, ok); if (!ok && !first_fail) first_fail = 133; }
	{ int ok = c34_check(); mb_mark(34, ok); if (!ok && !first_fail) first_fail = 134; }
	{ int ok = c35_check(); mb_mark(35, ok); if (!ok && !first_fail) first_fail = 135; }
	{ int ok = c36_check(); mb_mark(36, ok); if (!ok && !first_fail) first_fail = 136; }
	{ int ok = c37_check(); mb_mark(37, ok); if (!ok && !first_fail) first_fail = 137; }
	{ int ok = c38_check(); mb_mark(38, ok); if (!ok && !first_fail) first_fail = 138; }
	{ int ok = c39_check(); mb_mark(39, ok); if (!ok && !first_fail) first_fail = 139; }
	{ int ok = c40_check(); mb_mark(40, ok); if (!ok && !first_fail) first_fail = 140; }
	{ int ok = c41_check(); mb_mark(41, ok); if (!ok && !first_fail) first_fail = 141; }
	{ int ok = c42_check(); mb_mark(42, ok); if (!ok && !first_fail) first_fail = 142; }
	{ int ok = c43_check(); mb_mark(43, ok); if (!ok && !first_fail) first_fail = 143; }
	{ int ok = c44_check(); mb_mark(44, ok); if (!ok && !first_fail) first_fail = 144; }

	code = first_fail ? first_fail : 43;
	mb_end(code);
	return code;
}
