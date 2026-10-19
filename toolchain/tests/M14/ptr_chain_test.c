/* M14 ptr-chain: rvalue chains ptr->arr_field[i].subfield. */

struct Item {
    int val;
    int tag;
};

struct Bag {
    struct Item items[3];
};

struct Bag g_bag;

/* Init the inline items[] array via pointer-to-int cast.  poke_ints
 * takes a raw int pointer, which is the address of g_bag (first field
 * is items[0].val).  Lays out 6 ints: items[0].val, items[0].tag,
 * items[1].val, items[1].tag, items[2].val, items[2].tag. */
void poke_ints(int *p, int v0, int t0, int v1, int t1, int v2, int t2)
{
    p[0] = v0;
    p[1] = t0;
    p[2] = v1;
    p[3] = t1;
    p[4] = v2;
    p[5] = t2;
}

int main(void)
{
    struct Bag *bp;
    int sum;
    poke_ints((int *)&g_bag, 14, 1, 21, 2, 7, 3);
    bp = &g_bag;
    /* Exercise rvalue chain ptr->arr_field[i].subfield */
    sum = bp->items[0].val + bp->items[1].val + bp->items[2].val;
    return sum;   /* 14 + 21 + 7 = 42 */
}
