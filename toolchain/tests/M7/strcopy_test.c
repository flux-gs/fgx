char g_buf[16];
char *g_greet = "hi";

void copy(char *d, char *s)
{
    while (*s) {
        *d = *s;
        d++;
        s++;
    }
    *d = 0;
}

int strlen_(char *s)
{
    char *p;
    p = s;
    while (*p) p++;
    return p - s;
}

int main()
{
    copy(g_buf, g_greet);
    return strlen_(g_buf) * 21;
}
