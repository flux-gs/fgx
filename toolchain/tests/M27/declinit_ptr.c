/* M27/P3-2.7b: the last legacy-carrier statement arms, FPR-native.
 *
 * - Local ptr-ARRAY brace init: pre-2.7b the decl builder sized the
 *   elements at 2 bytes (offset word only, BANK DROPPED) while post-2.6a
 *   element reads use the 4-byte stride — a[1] read garbage.  A live
 *   miscompile (FGX1-masked; brace-init + ptr-array was never exercised).
 * - Local struct ptr / fn-ptr FIELD init (was carrier-fed via fpr_out).
 * - ++*p / --*p statement RMW, word + byte + pointer pointee (was
 *   _fcc_ptr staging; the ptr-pointee bump must leave the bank intact).
 * - arr[i].field[j] = rhs struct-array element store, global + local
 *   (was the bank re-establish store on _fcc_ptr). */
char gs1[4];
char gs2[4];
struct pv { char *p; int x; };
struct fv { int (*fn)(); };
struct rec { int pad; char name[4]; int vals[3]; };
struct rec recs[2];
int gi;

int
f7()
{
    return 7;
}

int
main()
{
    char *a[3] = { gs1, gs2 };          /* third element zero-filled */
    struct pv v = { gs1, 7 };
    struct fv w = { f7 };
    struct rec lr[2];
    int *ip;
    char *cp;
    char **pp;
    int i;

    /* decl-init ptr array: elements are far pointers (offset+bank) */
    if (a[0] != gs1 || a[1] != gs2 || a[2] != 0) return 1;
    *a[1] = 5;
    if (gs2[0] != 5) return 2;

    /* decl-init struct ptr + fn-ptr fields */
    if (v.p != gs1 || v.x != 7) return 3;
    *v.p = 9;
    if (gs1[0] != 9) return 4;
    if (w.fn() != 7) return 5;

    /* S_PREINC_DEREF: word pointee */
    gi = 10;
    ip = &gi;
    ++*ip;
    ++*ip;
    --*ip;
    if (gi != 11) return 6;

    /* S_PREINC_DEREF: byte pointee */
    cp = gs2;
    ++*cp;
    --*cp;
    --*cp;
    if (gs2[0] != 4) return 7;

    /* S_PREINC_DEREF: pointer pointee (offset-word bump, bank intact) */
    pp = &a[0];
    ++*pp;
    if (a[0] != gs1 + 1) return 8;
    if (*a[0] != gs1[1]) return 9;

    /* S_SARR_FIELD_IDX: global struct array */
    i = 1;
    recs[i].name[2] = 3;
    recs[i].vals[2] = 400;
    if (recs[1].name[2] != 3 || recs[1].vals[2] != 400) return 10;

    /* S_SARR_FIELD_IDX: local (soft-stack) struct array */
    lr[i].name[0] = 8;
    lr[i].vals[1] = 250;
    if (lr[1].name[0] != 8 || lr[1].vals[1] != 250) return 11;

    return 42;
}
