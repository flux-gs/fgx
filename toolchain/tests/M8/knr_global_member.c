/* knr_global_member: K&R GLOBAL member namespace (K&R A.7.3, p.164 -- the
 * 1st-edition rule; the strict "member must belong to the struct" enforcement
 * is an ANSI-ism).  A member name resolves by its offset in whichever struct
 * defines it, on ANY pointer.  The 2.11BSD Bourne shell accesses parallel
 * "variant record" structs (which share a common prefix layout) through one
 * generic pointer: `t->forktyp` where t is a trenod* but forktyp/forktre are
 * forknod fields.  Host `cc` (ANSI) REJECTS this; the value is verified by the
 * ANSI-equivalent layout program (accessing `storage` as a forknod directly),
 * which yields 42.  -> 42. */
struct trenod  { int tretyp; int treio; };
struct forknod { int forktyp; int forkio; int forktre; };
struct forknod storage;                 /* real memory is a forknod */
struct trenod *t;                        /* generic node pointer (TREPTR twin) */

int
main()
{
    t = (struct trenod *)&storage;       /* pun: generic pointer over forknod */
    t->forktyp = 20;                     /* forknod.forktyp @0 (== tretyp)  */
    t->forkio  = 0;                      /* @2 (== treio)                   */
    t->forktre = 22;                     /* forknod.forktre @4 -- NOT in trenod */
    return t->forktyp + t->forktre;      /* 20 + 22 == 42 (via global offsets) */
}
