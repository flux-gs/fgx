int main()
{
    int a[3];
    int *p;
    a[0] = 0;
    a[1] = 0;
    a[2] = 42;
    p = a + 2;
    --p;
    --p;
    return *(p + 2);
}
