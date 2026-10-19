/* ITERS=2000 */
#include "marker.h"
/* bubbleSort: sort 16 ints.  Exercises array indexed access + nested swap loops. */
static const int init[16] = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
static int arr[16];
static void do_bsort(int *a, int n) {
    int i, j, t;
    for (i = 0; i < n - 1; i++)
        for (j = 0; j < n - 1 - i; j++)
            if (a[j] > a[j + 1]) { t = a[j]; a[j] = a[j+1]; a[j+1] = t; }
}
int main(void) { int i, k;
  fbench_start();
  for(i=0;i<2000;i++) { for(k=0;k<16;k++) arr[k]=init[k]; do_bsort(arr,16); }
  fbench_done();
  return arr[0]; }
