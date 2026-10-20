/* M20 acceptance: long[] init + sum_longs(long*, int) + (int) cast.
 * Returns 42. */
long ages[3] = { 100000L, 200000L, 142L };

long sum_longs(long *arr, int n)
{
    long s;
    int  i;
    s = 0L;
    for (i = 0; i < n; i = i + 1) s = s + arr[i];
    return s;
}

int main(void)
{
    long total;
    total = sum_longs(ages, 3);            /* 300142 */
    return (int)(total - 300100L);          /* 42 */
}
