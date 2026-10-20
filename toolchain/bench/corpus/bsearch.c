/* ITERS=2000 */
#include "marker.h"
/* bsearch: binary search over sorted int array. */
static const int arr[] = {1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31};
static int do_bsearch(const int *a, int n, int key) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (a[mid] == key) return mid;
        if (a[mid] < key) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}
int main(void) { int acc=0; int i;
  fbench_start();
  for(i=0;i<2000;i++) acc+=do_bsearch(arr,16,17);
  fbench_done();
  return acc; }
