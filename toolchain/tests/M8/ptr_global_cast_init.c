/* ptr_global_cast_init: a pointer global initialized with a CAST of another
 * global (array) -- `T *p = (T *)g`.  The 2.11BSD Bourne shell blok.c does
 * `BLKPTR bloktop = (BLKPTR)end` (end being the loader's end-of-bss array).
 * K&R A.7.5 (cast) + A.7.1 (an array decays to a pointer).  fcc's pointer-
 * global init did not strip a leading cast, taking the integer path instead.
 * -> 42. */
struct blk { int v; };
int         table[4];
struct blk *bp = (struct blk *)table;

int
main()
{
    table[0] = 42;
    return bp->v;            /* bp -> table, table[0] == 42 */
}
