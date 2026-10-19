/* dot_pun_computed: the '.' global-member pun on a COMPUTED lvalue base --
 * 2.11BSD sh blok.c free(): Lcheat((--p)->word) == (((--p)->word)._cheat), an
 * int alias of the word field's own storage (offset 0, no deref).  K&R A.7.3
 * (1st-ed member namespace) + A.6.6 (pointer<->int).  Host cc (ANSI) rejects the
 * pun; checked against the ANSI-equivalent int-alias.  -> 42. */
typedef struct blk *BLKPTR;
struct blk { BLKPTR word; };
union { int _cheat; };
struct blk arena[4];

int
main()
{
    BLKPTR p;
    p = &arena[2];
    (((--p)->word)._cheat) |= 42;    /* arena[1].word low int: 0 |= 42 = 42 */
    return (int)arena[1].word;       /* Rcheat read: 42 */
}
