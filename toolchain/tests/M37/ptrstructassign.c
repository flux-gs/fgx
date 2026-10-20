/* ptrstructassign.c -- whole-struct assignment through a dereferenced pointer
 * on the LEFT: `*d = *s` and `*d = g`.  apple/fgx#199.
 *
 * THE FAST PATH CLAIMED A SHAPE IT COULD NOT EMIT.  parse_stmt's `*IDENT = ...`
 * fast path fires for any local whose type is a pointer, and LT_STRUCT_PTR is
 * a pointer, so a whole-struct copy was built as S_DSTORE_LOCAL -- a SCALAR
 * deref store.  It emitted one 16-bit `LDA [ptr] / STA [ptr]` pair and lost
 * every byte after the first two.  No diagnostic; the general path below it
 * has emitted the copy loop correctly all along and was simply never reached.
 *
 * K&R A.7.17 decides it: "In the simple assignment with =, the value of the
 * expression replaces that of the object referred to by the lvalue.  One of
 * the following must be true: both operands have arithmetic type ... or both
 * operands are structures or unions of the same type".  The object, not its
 * first word.  A.7.4.3 makes `*d` an lvalue referring to the whole object, so
 * nothing about the deref narrows what "replaces" covers.
 *
 * WHY THE STRUCTS ARE SHAPED LIKE THIS.  A struct whose members are all one
 * word cannot show the fault at its own first member, so every case here reads
 * a member PAST the first two bytes.  `struct clist` is reproduced exactly --
 * int + char* + char*, 10 bytes on this ABI -- because that is where the bug
 * was found: 2.11BSD's catq() does `*to = *from` and moved 2 of 10 bytes, so
 * the count arrived and both queue pointers stayed stale.
 *
 * THE TWO-BYTE STRUCT IS A CONTROL, not filler.  In `struct one` the broken
 * emitter and the correct one produce the same bytes, so that case CANNOT go
 * red -- it is here to say which cases carry information and which do not.
 *
 * The forms that already worked are controls too (`g = g`, `l = l`, `g = *s`):
 * a fix that reached them instead of the deref-LHS arm would show up as those
 * going red rather than as the new cases going green.
 */

struct clist {
    int   c_cc;
    char *c_cf;
    char *c_cl;
};

struct wide {
    int  a;
    long b;
    int  c;
};

struct one {
    int a;
};

struct clist g_src;
struct clist g_dst;
struct wide  gw_src;
struct one   g_one_src;

char buf_f[4];
char buf_l[4];

int
main()
{
    struct clist  a;
    struct clist  b;
    struct clist *pa;
    struct clist *pb;
    struct wide   w;
    struct wide  *pw;
    struct one    o1;
    struct one   *po;
    struct clist  arr[2];
    struct clist *dp;
    struct clist *sp;

    /* sizeof is the premise every case below rests on: 2 + 4 + 4. */
    if (sizeof(struct clist) != 10) return (10);
    if (sizeof(struct wide) != 8) return (11);

    /* ---- 20: `*d = *s`, both operands dereferenced pointers.  THE CASE. */
    g_src.c_cc = 0x1234;
    g_src.c_cf = buf_f;
    g_src.c_cl = buf_l;
    pa = &g_src;
    pb = &b;
    b.c_cc = 0;
    b.c_cf = (char *)0;
    b.c_cl = (char *)0;
    *pb = *pa;
    if (b.c_cc != 0x1234) return (20);
    if (b.c_cf != buf_f)  return (21);     /* the byte-2 member */
    if (b.c_cl != buf_l)  return (22);     /* the byte-6 member */

    /* ---- 23: `*d = g`, deref on the LEFT only.  Same fast path. */
    a.c_cc = 0;
    a.c_cf = (char *)0;
    a.c_cl = (char *)0;
    pa = &a;
    *pa = g_src;
    if (a.c_cc != 0x1234) return (23);
    if (a.c_cf != buf_f)  return (24);
    if (a.c_cl != buf_l)  return (25);

    /* ---- 26: a 4-byte member in the middle, so a copy that stops early
     * leaves a LONG half-written rather than a pointer.  Different width,
     * same arm. */
    gw_src.a = 0x0111;
    gw_src.b = 0x22223333L;
    gw_src.c = 0x0444;
    w.a = 0;
    w.b = 0L;
    w.c = 0;
    pw = &w;
    *pw = gw_src;
    if (w.a != 0x0111)       return (26);
    if (w.b != 0x22223333L)  return (27);
    if (w.c != 0x0444)       return (28);

    /* ---- 29: THE CONTROL THAT CANNOT FAIL.  One int, so the broken
     * single-word store and the correct copy emit the same thing.  If this
     * ever goes red the harness itself is wrong, not the arm. */
    g_one_src.a = 0x5678;
    o1.a = 0;
    po = &o1;
    *po = g_one_src;
    if (o1.a != 0x5678) return (29);

    /* ---- 30: `*d++ = *s++`.  The fast path used to claim the post-increment
     * form as well; it now falls to the general path, which has to get BOTH
     * the copy and the two increments right. */
    arr[0].c_cc = 0;
    arr[0].c_cf = (char *)0;
    arr[0].c_cl = (char *)0;
    arr[1].c_cc = 0;
    arr[1].c_cf = (char *)0;
    arr[1].c_cl = (char *)0;
    g_dst.c_cc = 0x0777;
    g_dst.c_cf = buf_l;
    g_dst.c_cl = buf_f;
    dp = arr;
    sp = &g_src;
    *dp++ = *sp++;
    if (arr[0].c_cc != 0x1234) return (30);
    if (arr[0].c_cf != buf_f)  return (31);
    if (arr[0].c_cl != buf_l)  return (32);
    if (dp != &arr[1])         return (33);   /* the destination advanced */
    if (sp != (&g_src) + 1)    return (34);   /* ...and so did the source */
    if (arr[1].c_cc != 0)      return (35);   /* and it wrote ONE element */

    /* ---- 40..: the forms that were never broken, as controls.  A fix that
     * landed on the wrong arm shows up here rather than in the cases above. */
    g_dst.c_cc = 0;
    g_dst.c_cf = (char *)0;
    g_dst.c_cl = (char *)0;
    g_dst = g_src;                            /* global = global */
    if (g_dst.c_cc != 0x1234) return (40);
    if (g_dst.c_cl != buf_l)  return (41);

    b.c_cc = 0;
    b.c_cf = (char *)0;
    b.c_cl = (char *)0;
    b = a;                                    /* local = local */
    if (b.c_cc != 0x1234) return (42 + 1);
    if (b.c_cl != buf_l)  return (44);

    g_dst.c_cc = 0;
    g_dst.c_cf = (char *)0;
    g_dst.c_cl = (char *)0;
    pa = &a;
    g_dst = *pa;                              /* global = *ptr (RHS deref) */
    if (g_dst.c_cc != 0x1234) return (45);
    if (g_dst.c_cl != buf_l)  return (46);

    return (42);
}
