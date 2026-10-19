/* ITERS=2000 */
#include "marker.h"
/* sumOfSquares: sum of squares 1..n.  Exercises long multiply. */
static long sum_sq(unsigned n) {
    long total = 0;
    unsigned i;
    for (i = 1; i <= n; i++) total += (long)i * (long)i;
    return total;
}
int main(void) { long acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=sum_sq(16);
  fbench_done();
  return (int)acc; }
