/* ptr_global_nested_cast_init: a pointer global initialised with a nested-paren
 * cast of another global -- BLK(end) == ((BLKPTR)(end)) (2.11BSD sh blok.c, end
 * the loader's end-of-bss array).  K&R A.7.5 cast + A.7.2 grouping + A.7.1 array
 * decay.  Standard C; host cc validates. -> 42. */
typedef struct blk *BLKPTR;
struct blk { int a; int b; };
struct blk endarr[4];
BLKPTR bloktop = ((BLKPTR)(endarr));

int
main()
{
    bloktop->a = 42;                 /* == endarr[0].a */
    return endarr[0].a;             /* 42 */
}
