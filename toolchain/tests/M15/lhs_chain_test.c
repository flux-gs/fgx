/* M15 LHS-chain: 3-level LHS chains AND matching rvalue chains.
 * Exercises:
 *   global.arr_field[i].subfield = expr        (LHS struct → arr → struct → field)
 *   ptr->arr_field[i].subfield   = expr        (LHS via pointer)
 *   global.arr_field[i].subfield               (rvalue chain via struct)
 *   ptr->arr_field[i].subfield                 (rvalue chain via pointer; M14)
 */

struct Item {
    int val;
    int tag;
};

struct Bag {
    struct Item items[3];
    int n;
};

struct Bag g_bag;

int main(void)
{
    struct Bag *bp;
    int sum;
    /* 3-level LHS chains directly on global struct. */
    g_bag.items[0].val = 14;
    g_bag.items[0].tag = 1;
    g_bag.items[1].val = 20;   /* will overwrite via ptr below */
    g_bag.items[1].tag = 2;
    g_bag.items[2].val = 7;
    g_bag.items[2].tag = 3;
    g_bag.n = 3;
    bp = &g_bag;
    /* 3-level LHS via pointer. */
    bp->items[1].val = 21;     /* overwrites the 20 above */
    /* Rvalue chains for read-back, mixing struct-direct and ptr forms. */
    sum = g_bag.items[0].val + bp->items[1].val + g_bag.items[2].val;
    return sum;   /* 14 + 21 + 7 = 42 */
}
