/* ITERS=2000 */
#include "marker.h"
int main(void){ unsigned a=0; unsigned x; int i;
  fbench_start();
  for(i=0;i<2000;i++){ x=(unsigned)i; a += (x/8) + (x%8); }
  fbench_done();
  return (int)a; }
