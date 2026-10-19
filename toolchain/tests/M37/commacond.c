/* Comma operator in a controlling expression -- while/for/if all take a full
 * `expression`, so `while (c = next(), c != END)` is legal (joe termidx.c's
 * char-scan idiom).  fcc used ast_build_assign for the conditions, which stops
 * below the comma and died "expected ')'".  FGX-only oracle.  Value 42. */
int fed;
int next(void) { return fed++; }

int main(void)
{
    int c, i, r = 0;

    fed = 3;
    while (c = next(), c < 6)          /* runs c=3,4,5; stops at 6 */
        r += c;                         /* 3+4+5 = 12 */
    /* c is 6 here */
    if (c = c + 1, c == 7) r += 10;     /* comma in if: 22 */
    for (i = 0; c = i + 100, i < 4; ++i)  /* comma in for-cond */
        r += 1;                         /* 4 times: 26 */
    if (c == 104) r += 16;              /* last for-cond set c=104 (i=4): 42 */
    return r;
}
