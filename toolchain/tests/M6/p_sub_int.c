int main()
{
    int a[3];
    int *p;
    a[0] = 10;
    a[1] = 42;
    a[2] = 17;
    p = a + 2;
    return *(p - 1);
}
