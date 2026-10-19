#ifndef FCC_PEEPHOLE_H
#define FCC_PEEPHOLE_H

/* Optimize a Merlin32 assembly text buffer textually.  Returns a newly
 * malloc'd, NUL-terminated optimized buffer; the caller frees it.  Pure:
 * depends only on the C stdlib, never on fcc internals. */
char *peephole_optimize(const char *asm_text);

/* Test-only hook: 1 if the N/Z flags set at line `idx` are provably dead
 * (overwritten before any NZ-reading branch / before a return).  Exposed
 * for unit tests; not used outside the module + tests. */
int ph_test_nz_dead_after(const char *asm_text, int idx);

/* Test-only hook: 1 if the carry flag produced at line `idx` is provably dead
 * (overwritten or unread before a return).  Carry-only liveness (V assumed
 * dead — fcc emits no BVC/BVS).  Exposed for unit tests. */
int ph_test_carry_dead_after(const char *asm_text, int idx);

/* Test-only hook: 1 if the accumulator value defined at line `idx` is provably
 * dead (redefined before any read, only A-neutral lines between).  Exposed for
 * unit tests. */
int ph_test_dead_a_after(const char *asm_text, int idx);

#endif /* FCC_PEEPHOLE_H */
