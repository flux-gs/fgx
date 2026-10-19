int do_it(void *vp, int *ip)
{
    *ip = 42;
    return 0;
}

int main()
{
    int x;
    int y;
    x = 0;
    y = 0;
    do_it(&x, &y);
    return y;
}
