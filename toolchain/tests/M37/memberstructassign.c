/* memberstructassign.c -- whole-struct assignment where either side is a
 * struct-typed MEMBER.  apple/fgx#207.
 *
 * EIGHT LEFT-HAND SPELLINGS BY FIVE RIGHT-HAND ONES, because that matrix is
 * what showed the shape of the fault and one cell of it was silent.  fcc had:
 *
 *   p->m = <any>        a two-byte store of the SOURCE'S ADDRESS.  Silent.
 *   arr[i].m = <any>    the same, one hop further out.  Also silent, and
 *                       found only by running the matrix after fixing p->m.
 *   sv.m, sv.o.m,
 *   p->o.m  as LHS      rejected outright.
 *   p->m, sv.m,
 *   arr[i].m as RHS     rejected outright.
 *
 * Everything with whole-struct operands on both sides already worked, which is
 * why nothing noticed: the member spellings are the ones vintage BSD writes.
 *
 * IT WAS LIVE IN THE KERNEL.  ufs_inode.c's iget does `iq->i_din = ip->i_din'
 * -- the whole on-disk inode moving from a vnode being discarded into the one
 * being kept -- and that moved 2 of the dinode's 64 bytes, silently, since UFS
 * 1.11a.  The comment above that line says structassign.c "pins the construct
 * on the machine"; structassign.c tests `*dp = *sp`, and its own header claims
 * to cover "`d->m = s->m`, which is iget's actual spelling".  It does not.
 * That is why this file exists as well as that one.
 *
 * K&R A.7.3.3 on `E1->MOS': "The value is the named member of the object to
 * which E1 points ... The value is an lvalue if E1 is an lvalue", and A.7.3.2
 * says the same of `E1.MOS'.  A.7.17 then replaces "the value of the object
 * referred to by the lvalue" and admits "both operands are structures or
 * unions of the same type".  The OBJECT, not its first word, and neither
 * clause conditions the copy on how the lvalue was spelled.
 *
 * EVERY CASE READS A MEMBER PAST THE FIRST TWO BYTES and checks the FENCE on
 * BOTH SIDES of the destination.  A copy loop at the WRONG ADDRESS is the
 * failure a fix for a short copy invites -- the two-hop spellings compute
 * their offset from a parent chain, and a wrong parent offset emits a
 * perfectly good loop into the wrong place.  The fences are what separate
 * "copied" from "copied HERE".
 *
 * Exit 42.
 */

struct inner {
    unsigned short  a;
    long            b;
    unsigned short  c;
};

struct outer {
    unsigned short  head;
    struct inner    m;
    unsigned short  tail;
};

struct nest {
    unsigned short  nhead;
    struct outer    o;
    unsigned short  ntail;
};

struct inner  g_src;
struct inner  g_zero;
struct outer  g_dst;
struct outer  g_dst2;
struct nest   g_nest;
struct outer  g_arr[3];

static void
fill(p)
    struct inner *p;
{
    p->a = 0x1234;
    p->b = 0x11223344L;
    p->c = 0x5678;
}

/* clear -- a destination with a fence on each side of the member. */
static void
clear(p)
    struct outer *p;
{
    p->head = 0xAAAA;
    p->m.a  = 0;
    p->m.b  = 0L;
    p->m.c  = 0;
    p->tail = 0xBBBB;
}

/* landed -- did the whole struct arrive, and only there?  Returns 0 on
 * success so each caller can pick its own case number. */
static int
landed(p)
    struct outer *p;
{
    if (p->m.a != 0x1234)      return (1);
    if (p->m.b != 0x11223344L) return (2);   /* past the first two bytes */
    if (p->m.c != 0x5678)      return (3);
    if (p->head != 0xAAAA)     return (4);   /* nothing before it moved */
    if (p->tail != 0xBBBB)     return (5);   /* and nothing after it */
    return (0);
}

int
main()
{
    struct outer *dp;
    struct outer *sp;
    struct inner *ip;
    struct inner  loc;
    struct nest  *np;
    int           i;

    fill(&g_src);

    /* ================= the five RIGHT-hand spellings ==================
     * driven into ONE destination, so a failure names the source form. */

    dp = &g_dst;

    clear(dp);  dp->m = g_src;                       /* RHS: a global      */
    if (landed(dp))                     return (10 + landed(dp));

    ip = &g_src;
    clear(dp);  dp->m = *ip;                         /* RHS: *q            */
    if (landed(dp))                     return (20 + landed(dp));

    sp = &g_dst2; clear(sp); sp->m = g_src;
    clear(dp);  dp->m = sp->m;                       /* RHS: q->m          */
    if (landed(dp))                     return (30 + landed(dp));
    if (sp->m.b != 0x11223344L)         return (39); /* source undisturbed */

    clear(&g_dst2); g_dst2.m = g_src;
    clear(dp);  dp->m = g_dst2.m;                    /* RHS: sv.m          */
    if (landed(dp))                     return (40 + landed(dp));

    clear(&g_arr[1]); g_arr[1].m = g_src;
    i = 1;
    clear(dp);  dp->m = g_arr[i].m;                  /* RHS: arr[i].m      */
    if (landed(dp))                     return (50 + landed(dp));

    /* ================= the eight LEFT-hand spellings ================== */

    loc.a = 0; loc.b = 0L; loc.c = 0;
    loc = g_src;                                     /* LHS: a local       */
    if (loc.b != 0x11223344L)           return (60);
    if (loc.c != 0x5678)                return (61);

    g_zero.a = 0; g_zero.b = 0L; g_zero.c = 0;
    g_zero = g_src;                                  /* LHS: a global      */
    if (g_zero.b != 0x11223344L)        return (62);
    g_zero.a = 0; g_zero.b = 0L; g_zero.c = 0;

    ip = &loc; ip->a = 0; ip->b = 0L; ip->c = 0;
    *ip = g_src;                                     /* LHS: *p            */
    if (loc.b != 0x11223344L)           return (63);
    if (loc.c != 0x5678)                return (64);

    clear(dp);  dp->m = g_src;                       /* LHS: p->m          */
    if (landed(dp))                     return (70 + landed(dp));

    clear(&g_dst2); g_dst2.m = g_src;                /* LHS: sv.m          */
    if (landed(&g_dst2))                return (80 + landed(&g_dst2));

    /* LHS: arr[i].m -- THE SECOND SILENT CELL.  The index scale and the
     * member offset are added by the same node, so a fix that got one and
     * not the other emits a copy loop into the wrong ELEMENT.  Both
     * neighbours are checked for exactly that. */
    for (i = 0; i < 3; i++)
        clear(&g_arr[i]);
    i = 1;
    g_arr[i].m = g_src;
    if (landed(&g_arr[1]))              return (90 + landed(&g_arr[1]));
    /* THE NEIGHBOURS, THROUGH A POINTER.  `g_arr[0].m.b' -- a two-hop read
     * off a struct-array element -- is refused by fcc ("expected ')'"), which
     * is a READ gap and fails closed; it is not what this file is testing, so
     * the check is spelled the way that compiles rather than widened here. */
    sp = &g_arr[0];
    if (sp->m.b != 0L)                  return (98); /* the element before */
    sp = &g_arr[2];
    if (sp->m.b != 0L)                  return (99); /* and the one after  */

    /* LHS: p->o.m and sv.o.m -- TWO HOPS.  The leaf's own byte_offset is the
     * LAST hop only; the parent chain rides in a separate field, and a wrong
     * one emits a perfectly good copy loop at the wrong address.  nhead and
     * ntail fence the whole nest, head and tail the member inside it. */
    g_nest.nhead = 0xCCCC;
    g_nest.ntail = 0xDDDD;
    clear(&g_nest.o);
    np = &g_nest;
    np->o.m = g_src;                                 /* LHS: p->o.m        */
    if (landed(&g_nest.o))              return (100 + landed(&g_nest.o));
    if (g_nest.nhead != 0xCCCC)         return (108);
    if (g_nest.ntail != 0xDDDD)         return (109);

    g_nest.nhead = 0xCCCC;
    g_nest.ntail = 0xDDDD;
    clear(&g_nest.o);
    g_nest.o.m = g_src;                              /* LHS: sv.o.m        */
    if (landed(&g_nest.o))              return (110 + landed(&g_nest.o));
    if (g_nest.nhead != 0xCCCC)         return (118);
    if (g_nest.ntail != 0xDDDD)         return (119);

    /* ---- 120: THE ZERO SOURCE, which an over-copy cannot fake.  Assigning
     * an all-zero struct must leave the fences alone; a loop with the wrong
     * length writes zeros into head or tail and every case above still
     * passes, because they all check for the PATTERN arriving. */
    clear(dp);
    dp->m = g_zero;
    if (dp->m.a != 0)                   return (120);
    if (dp->m.b != 0L)                  return (121);
    if (dp->m.c != 0)                   return (122);
    if (dp->head != 0xAAAA)             return (123);
    if (dp->tail != 0xBBBB)             return (124);

    return (42);
}
