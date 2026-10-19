int main()
{
    int a[3];
    int *p;
    a[0] = 10;
    a[1] = 15;
    a[2] = 17;
    p = a;
    return *(p + 2);
}
