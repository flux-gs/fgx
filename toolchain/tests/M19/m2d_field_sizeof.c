/* M19b: `sizeof' applied to an UNPARENTHESIZED member chain.
 *
 * apple/fgx#477's other half.  `sizeof(x.y)' compiled and `sizeof x.y' died
 * "expected ')'", because the parenthesized arm walked '.'/'->' chains and the
 * bare arm stopped at the base.  K&R 2nd ed A.7.4.8 draws no such distinction --
 * "The operand is either an expression, which is not evaluated, or a
 * parenthesized type name" -- and A.7.3 makes `x.y' and `p->x.y' expressions, so
 * both spellings take them.  syslogd(8) writes `sizeof sun.sun_path' and
 * `sizeof f->f_un.f_forw.f_addr'.
 *
 * Every arm is compared against the parenthesized spelling of the same operand,
 * so the fixture fails if the two ever disagree rather than only if one breaks.
 */
struct inner { char path[14]; int n; };
struct outer { struct inner i; char row[3][5]; };

struct outer O;
struct outer *pO = &O;

int main(void)
{
    int acc = 0;

    acc += (sizeof O.i.path    == sizeof(O.i.path))    ? 1 : 0;   /* 14 */
    acc += (sizeof pO->i.path  == sizeof(pO->i.path))  ? 2 : 0;
    acc += (sizeof O.i         == sizeof(O.i))         ? 4 : 0;   /* 16 */
    acc += (sizeof O.row       == sizeof(O.row))       ? 8 : 0;   /* 15 */
    acc += (sizeof O.i.path    == 14)                  ? 16 : 0;
    acc += (sizeof O.row       == 15)                  ? 32 : 0;
    acc += (sizeof O.i.n       == 2)                   ? 64 : 0;
    /* a subscript AFTER the chain is ONE element of it */
    acc += (sizeof O.i.path[0] == 1)                   ? 128 : 0;
    return acc;                                        /* 255 */
}
