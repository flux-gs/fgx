/* c16_fnptr.c — construct 16: a fn-ptr table in the data bank whose entries
 * (FGX2_LONG_PTR) point at c16_targets in ANOTHER code bank; called cross-bank.
 * Mole: far-fnptr-in-initializer + struct-array-fnptr promote drift. */
extern int c16_fa();
extern int c16_fb();
int (*c16_tbl[2])() = { c16_fa, c16_fb };

int c16_check(void) { return c16_tbl[0]() + c16_tbl[1]() == 0x16; }
