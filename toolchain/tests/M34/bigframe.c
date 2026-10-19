/* bigframe.c — correctness queue 8: the G53b dormant >255-byte-frame
 * sub-cases, END-TO-END proven (G53's original failure mode was
 * un-assemblable `LDA n,S` at displacement >255 — P3-3's hardware-stack
 * frame-base model retired the class structurally; this pins it).
 *   - struct FIELD of a local at byte offset >255
 *   - constant-index element load/store at offset >255
 *   - main() itself with a >255 frame + argc/argv binding
 * All standard C — clang cross-checks the exit.  Exit 42. */
struct S { int a; char pad[300]; int b; };

int bigfield()
{
    struct S s;
    s.a = 2;
    s.b = 20;
    return s.a + s.b;            /* 22 */
}

int bigelem()
{
    char big[300];
    big[280] = 15;
    big[2] = 3;
    return big[280] + big[2];    /* 18 */
}

int main(int argc, char **argv)
{
    char big[300];
    big[299] = 2;
    return bigfield() + bigelem() +
           ((argc >= 1) ? big[299] : 0);   /* 22+18+2 = 42 */
}
