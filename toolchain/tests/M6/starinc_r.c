int main()
{
    int a[3];
    int *p;
    a[0] = 21;
    a[1] = 21;
    a[2] = 0;
    p = a;
    return *p++ + *p;
}
