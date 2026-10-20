/* ITERS=2000 */
#include "marker.h"
static const char *s = "the quick brown fox jumps over the lazy dog";
static unsigned slen(const char *p){ unsigned n=0; while(*p++) n++; return n; }
int main(void){ unsigned acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=slen(s);
  fbench_done();
  return (int)acc; }
