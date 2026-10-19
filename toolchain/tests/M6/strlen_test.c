void clearbuf(char *p, int n)
{
    int i;
    i = 0;
    while (i < n) {
        p[i] = 0;
        i = i + 1;
    }
}

int strlen_(char *s)
{
    int n;
    n = 0;
    while (*s) {
        s++;
        n = n + 1;
    }
    return n;
}

int main()
{
    char buf[8];
    clearbuf(buf, 8);
    buf[0] = 14;
    buf[1] = 14;
    buf[2] = 14;
    return strlen_(buf) * 14;
}
