/* K&R-compat prototype keep (M-4 2026-07-17): an empty-paren redeclaration
 * of an already-PROTOTYPED function must NOT downgrade the prototype — the
 * later `extern unsigned long wide();` here would otherwise flip wide()'s
 * caller convention back to push-args-as-is, and g()'s int argument would
 * go up as 2 bytes where the callee reads a 4-byte long (the elvis
 * config.h `extern void *malloc();` -vs- wide stdlib.h malloc shape).
 * The golden locks the widened (4-byte, _fcc_long_from_int) call. */
unsigned long wide(unsigned long size);
extern unsigned long wide();

unsigned long g(int n)
{
    return wide(n);
}

unsigned long wide(size)
unsigned long size;
{
    return size + 1;
}

int main(void)
{
    /* 70000 needs the high word: proves the arg arrived as a real long. */
    if (g(5) != 6) return 1;
    if (wide(70000L) != 70001L) return 2;
    return 0;
}

/* NOTE: parked under tests/repros/ (not the golden M-dirs) because the
 * golden regen flow keys on per-dir _seg link scaffolding; fold this into
 * the golden suite on the next regen sweep.  On-target coverage today:
 * FGX vi_arrow_exline (elvis built with -include stdlib.h over the
 * vendored K&R config.h). */
