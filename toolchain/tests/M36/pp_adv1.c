/* pp_adv1.c — T2-2 adversarial fixture 1: behaviors the token-pass flip
 * must preserve EXACTLY (pinned before any pp rework; see the T2 plan).
 *   - #if 0 blocks containing UN-LEXABLE prose (unterminated quote, stray
 *     backslash) — inactive skipping is line-level, never lexed.
 *   - #if arithmetic: division by zero evaluates to 0 (documented quirk).
 *   - funclike macro named in #if WITHOUT args — NOT expanded, treated 0.
 * Exit 42 = all pinned behaviors hold. */
#if 0
this is prose that would never lex: unterminated " quote and a stray \ mark
	and a hash # in column weirdness %% $$$
#endif

#define FL(x) ((x) + 1)

#if 5 / 0
#define DIV_TOOK_TRUE 1
#else
#define DIV_TOOK_FALSE 1
#endif

#if FL
#define FL_TOOK_TRUE 1
#else
#define FL_TOOK_FALSE 1
#endif

int main()
{
    int r = 0;
#ifdef DIV_TOOK_FALSE
    r = r + 20;                 /* 5/0 -> 0 -> false branch */
#endif
#ifdef FL_TOOK_FALSE
    r = r + 22;                 /* bare funclike name -> 0 -> false */
#endif
    return r;                   /* 42 */
}
