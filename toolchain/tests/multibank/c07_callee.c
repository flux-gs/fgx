/* c07_callee.c — extern callee pinned in a DIFFERENT code bank; returns a
 * pointer to ITS data-bank global.  The return-value bank lives in _fcc_ptr+2
 * and must survive the (cross-bank) return.  Separate TU so placement can pin it. */
unsigned char c07_g[4] = { 0x71, 0x72, 0x73, 0x74 };

unsigned char *c07_get(void) { return c07_g; }
