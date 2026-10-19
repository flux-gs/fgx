/* ITERS=2000 */
#include "marker.h"
/* dotProduct: dot product of two int vectors.  Exercises long multiply-accumulate. */
static const int va[] = {1,2,3,4,5,6,7,8};
static const int vb[] = {8,7,6,5,4,3,2,1};
static long dot(const int *a, const int *b, unsigned n) {
    long sum = 0;
    unsigned i;
    for (i = 0; i < n; i++) sum += (long)a[i] * (long)b[i];
    return sum;
}
int main(void) { long acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=dot(va,vb,8);
  fbench_done();
  return (int)acc; }
