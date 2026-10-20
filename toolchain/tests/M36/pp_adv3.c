/* pp_adv3.c — T2-2 adversarial fixture 3: funclike edge shapes.
 *   - args containing commas inside parens: PAIR2ND((a,b),c) is 2 args.
 *   - funclike-in-BODY chains expand via rescan: H(v) -> G(v) -> ((v)+3).
 *   - multi-token args substituting into operator context: ADD(2*2, 1).
 *   - ARG-POSITION calls expand (C90 6.8.3.1: arguments are fully
 *     macro-expanded BEFORE substitution): G(G(1)), H(H(0)), and a
 *     mixed-callee nest G(ADD(1,2)).  This was fcc's pinned limitation
 *     ('undeclared' fail-loud) until the 2026-07-10 correctness fix —
 *     the token-pass engine pre-expands collected arg spans; fcc now
 *     matches the standard (this file is clang-cross-checkable).
 * Exit 42. */
#define PAIR2ND(p, q) (q)
#define G(v) ((v) + 3)
#define H(v) G(v)
#define ADD(a, b) ((a) + (b))

int main()
{
    int a = PAIR2ND((1, 2), 10);          /* 10: (1,2) is ONE arg */
    int b = H(4);                         /* body-chain: ((4)+3) = 7 */
    int c = ADD(2 * 2, 1);                /* 5 */
    int d = G(G(1));                      /* ((((1)+3))+3) = 7 */
    int e = H(H(0));                      /* ((((0)+3))+3) = 6 */
    int f = G(ADD(1, 2));                 /* (((1)+(2))+3) = 6 */
    int g = PAIR2ND(G(9), 1);             /* discarded arg still expands: 1 */
    return a + b + c + d + e + f + g;     /* 10+7+5+7+6+6+1 = 42 */
}
