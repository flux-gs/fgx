int main()
{
    int x;
    int *p;
    x = 7;
    p = &x;
    *p += 14;
    *p *= 2;
    return x;
}
