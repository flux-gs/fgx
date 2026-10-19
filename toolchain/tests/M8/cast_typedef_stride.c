/* cast_typedef_stride: a cast to a TYPEDEF'd struct pointer must keep the
 * struct id, so pointer arithmetic on the cast result strides by the struct
 * size (K&R A.7.5 cast -> A.7.7 `pointer + integer`).  2.11BSD sh blok.c:
 * BLK(stakbas)-1 == (BLKPTR)stakbas - 1.  Standard C; host cc validates. -> 42. */
typedef struct blk *BLKPTR;
struct blk { int a; int b; };
struct blk arena[4];

int
main()
{
    char *base = (char *)&arena[2];
    BLKPTR q = (BLKPTR)base - 1;      /* stride back one struct blk -> &arena[1] */
    q->a = 42;
    return arena[1].a;               /* 42 */
}
