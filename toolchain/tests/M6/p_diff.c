int main()
{
    int a[5];
    int *p;
    int *q;
    p = a;
    q = a + 3;
    return (q - p) * 14;
}
