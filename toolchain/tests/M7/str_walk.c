int strlen_(char *s)
{
    char *p;
    p = s;
    while (*p) p++;
    return p - s;
}

int main()
{
    return strlen_("123456789012345678901234567890123456789012");
}
