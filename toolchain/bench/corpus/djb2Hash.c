/* ITERS=2000 */
#include "marker.h"
/* djb2Hash: djb2 string hash.  Exercises long shift/add in a pointer-walk loop. */
static const char *s = "the quick brown fox jumps over the lazy dog";
static long djb2(const char *p) {
    long h = 5381;
    while (*p) {
        h = ((h << 5) + h) + (int)(unsigned char)(*p++);
    }
    return h;
}
int main(void) { long acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=djb2(s);
  fbench_done();
  return (int)acc; }
