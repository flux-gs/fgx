/* ITERS=2000 */
#include "marker.h"
/* strcpy: copy string char-by-char.  Exercises dual-pointer byte-store loop. */
static char dst[64];
static const char *src = "the quick brown fox jumps over the lazy dog";
static char *do_strcpy(char *d, const char *s) {
    char *r = d;
    char c;
    do { c = *s++; *d++ = c; } while (c);
    return r;
}
int main(void) { int i;
  fbench_start();
  for(i=0;i<2000;i++) do_strcpy(dst,src);
  fbench_done();
  return (int)dst[0]; }
