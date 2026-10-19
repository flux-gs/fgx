/* ITERS=2000 */
#include "marker.h"
/* popcount: count set bits in a long.  Exercises long shift/mask in a loop. */
static int popcnt(long x) {
    int n = 0;
    while (x) { n += (int)(x & 1); x >>= 1; }
    return n;
}
int main(void) { int acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=popcnt((long)i*0x1234L);
  fbench_done();
  return acc; }
