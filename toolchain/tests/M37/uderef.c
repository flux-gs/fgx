/* A-1 regression: `*(unsigned *)p` must read UNSIGNED — the cast-deref
 * path dropped the pointee's unsignedness, so widening to long sign-
 * extended values >= 0x8000 (stdarg's va_arg is exactly this shape;
 * printf %u printed 65528 as 4294967288 — H2 vmstat find).  Exit 42. */
int cell;
char buf[16];

int main(void)
{
    unsigned long ul;
    long sl;
    char *p;

    cell = 0xFFF8;              /* -8 as signed, 65528 as unsigned */
    p = (char *)&cell;
    ul = (unsigned long)(*(unsigned *)p);
    if (ul != 65528UL) return 1;
    sl = (long)(*(int *)p);     /* signed deref still sign-extends */
    if (sl != -8L) return 2;
    sprintf(buf, "%u", *(unsigned *)p);
    if (buf[0] != '6' || buf[4] != '8' || buf[5] != 0) return 3;
    return 42;
}
