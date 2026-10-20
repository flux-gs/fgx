int main()
{
    char buf[4];
    char *p;
    buf[3] = 0;
    p = buf;
    *p++ = 14;
    *p++ = 14;
    *p++ = 14;
    return buf[0] + buf[1] + buf[2];
}
