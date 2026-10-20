/* ITERS=2000 */
#include "marker.h"
/* fib: recursive Fibonacci.  Exercises recursive call overhead. */
static unsigned fib_r(unsigned n) {
    if (n < 2) return n;
    return fib_r(n - 1) + fib_r(n - 2);
}
int main(void) { unsigned acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=fib_r(10);
  fbench_done();
  return (int)acc; }
