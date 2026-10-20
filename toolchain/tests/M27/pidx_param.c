/* B1c-2b: loop-hot PARAM pointer (entry-seeded img pair) indexed in a loop. */
static int a[3];
static int f(int *p)
{
    int s = 0, i;
    for (i = 0; i < 3; i++) s = s + p[i];
    return s;
}
int main(void)
{
    a[0] = 10; a[1] = 15; a[2] = 17;
    return f(a);                             /* 10 + 15 + 17 == 42 */
}
