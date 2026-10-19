int main()
{
    char buf[3];
    char *p;
    buf[0] = 21;
    buf[1] = 21;
    buf[2] = 0;
    p = buf;
    p++;
    return *p + buf[0];
}
