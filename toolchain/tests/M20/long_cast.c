/* M20: explicit (int)/(long) casts. */
int main(void)
{
    long l;
    int  i;
    l = 100042L;
    i = (int)(l - 100000L);   /* 42 */
    l = (long)i;               /* widen */
    l = l - 0L;                 /* 42 */
    return (int)l;
}
