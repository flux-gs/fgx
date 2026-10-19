/* pp_adv4.c — T2-2 adversarial fixture 4: the object/funclike COUPLING
 * surfaces (pinned BEFORE the token-pass flip; see the T2 plan).
 *   - funclike macro CALL inside an object-macro body (fcc's own tword.h
 *     INCREF pattern) expands at USE time; an object macro may also be the
 *     ARG of such a call when the callee differs (guard permits it).
 *   - keyword-bodied object macro (`while`); long-literal body (70000L);
 *     string-escape funclike arg; multiline call args; __VA_ARGS__ join.
 *   - #if evaluates an object-macro body as a COMPLETE expression
 *     (implicit parens: A2*2 with A2=1+1 is (1+1)*2=4, NOT cpp's 1+1*2=3).
 *   - empty-body macro in #if evaluates 0 (standard cpp ERRORS on the
 *     empty expression — clang rejects this file); defined() via an
 *     object body (UB per C standard, defined behavior in fcc: 1).
 * Exit 42. */
#define INC(t)  ((t) + 1)
#define INC2(t) ((t) + 2)
#define FIVE  INC(4)               /* funclike call in object body: 5 */
#define SEVEN INC2(FIVE)           /* object-macro ARG expands inside: 7 */

#define LOOP while                 /* keyword-bodied macro */
#define BIG  70000L                /* long-literal body */

#define PICK(s) s
#define ADD2(a, b) ((a) + (b))
#define JOIN(...) take2(__VA_ARGS__)

#define A2 1+1
/* fcc: (1+1)*2 == 4; cpp would get 3.  NOTE: the comment must stay OFF the
 * #if line — today's char evaluator reads the raw line, and a trailing
 * comment corrupts the expression ('/' parses as division).  The token
 * evaluator fixes that; it is a bugfix divergence, deliberately unpinned. */
#if A2 * 2 == 4
#define IMPLICIT_OK 1
#endif

#define EMPTYM
#if EMPTYM
#define EMPTY_TRUE 1               /* must NOT be defined: empty body -> 0 */
#endif

#define HAS defined(INC)
#if HAS
#define HAS_OK 1
#endif

int take2(int x, int y)
{
    return x + y;
}

int main()
{
    int r = 0;
    int n;
    long b;
    char *p;

    r = r + FIVE + SEVEN;          /* 5 + 7 = 12 */

    n = 3;
    LOOP (n > 0) n = n - 1;        /* keyword body drives the loop */
    r = r + n;                     /* +0 */

    b = BIG;
    if (b - 69990L == 10L) r = r + 10;

    p = PICK("a\tb");
    if (p[1] == 9) r = r + 5;      /* \t survived arg passing */

    r = r + ADD2(2,
                 3);               /* multiline args: +5 */

    r = r + JOIN(3, 3);            /* __VA_ARGS__ join: +6 */

#ifdef IMPLICIT_OK
    r = r + 2;
#endif
#ifdef EMPTY_TRUE
    r = r - 100;                   /* would break the 42 */
#endif
#ifdef HAS_OK
    r = r + 2;
#endif
    return r;                      /* 12+10+5+5+6+2+2 = 42 */
}
