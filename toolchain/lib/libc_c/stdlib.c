long atol(char *s)
{
    long v = 0;
    int neg = 0;

    while (*s == ' ' || *s == '\t')
        s++;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') s++;
    while (*s >= '0' && *s <= '9') {
        v = v * 10 + (long)(*s - '0');
        s++;
    }
    if (neg) return -v;
    return v;
}

int atoi(char *s)
{
    return (int)atol(s);
}
