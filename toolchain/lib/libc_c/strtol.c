/* strtol(3): parse a signed long in `base` (0 = C auto: 0x->16, 0->8, else
 * 10).  Skips leading whitespace + optional sign, stops at the first char not
 * a digit in the base; *endp (if non-NULL) is left pointing there.  No
 * overflow clamping.  Added for tar(1)'s octal header fields (base 8) so it
 * uses a real libc primitive instead of sscanf("%o"). */
long strtol(char *s, char **endp, int base)
{
    long val;
    int neg, c, d;

    while (*s == ' ' || *s == '\t' || *s == '\n')
        s++;
    neg = 0;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') s++;
    if (base == 0) {
        if (*s == '0') {
            if (s[1] == 'x' || s[1] == 'X') { base = 16; s += 2; }
            else base = 8;
        } else
            base = 10;
    } else if (base == 16 && *s == '0' && (s[1] == 'x' || s[1] == 'X'))
        s += 2;
    val = 0;
    for (;;) {
        c = *s;
        if (c >= '0' && c <= '9')      d = c - '0';
        else if (c >= 'a' && c <= 'z') d = c - 'a' + 10;
        else if (c >= 'A' && c <= 'Z') d = c - 'A' + 10;
        else break;
        if (d >= base)
            break;
        val = val * base + d;
        s++;
    }
    if (endp != 0)
        *endp = s;
    return neg ? -val : val;
}
