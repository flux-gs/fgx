int main()
{
    char buf[5];
    char *p;
    buf[0] = 0;
    buf[1] = 0;
    buf[2] = 42;
    buf[3] = 0;
    buf[4] = 0;
    p = buf;
    return *(p + 2);
}
