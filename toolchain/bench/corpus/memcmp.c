/* ITERS=2000 */
#include "marker.h"
/* memcmp: byte-by-byte memory compare.  Exercises dual-pointer byte-load. */
typedef unsigned char u8;
static const char sa[] = "the quick brown fox jumps over the lazy dog";
static const char sb[] = "the quick brown fox jumps over the lazy dog";
static int do_memcmp(const void *a, const void *b, unsigned n) {
    const u8 *p = (const u8 *)a;
    const u8 *q = (const u8 *)b;
    while (n) {
        if (*p != *q) return *p - *q;
        p++; q++; n--;
    }
    return 0;
}
int main(void) { int acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=do_memcmp(sa,sb,43);
  fbench_done();
  return acc; }
