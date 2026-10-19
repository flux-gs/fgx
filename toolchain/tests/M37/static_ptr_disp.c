/* apple/fgx#282: a static pointer initialiser may carry a CONSTANT
 * DISPLACEMENT on the address it takes -- `&arr[k]', `&obj.member', `arr + k'.
 * Only a bare `&object' or a decayed array name was accepted before; all three
 * died "expected ';'".
 *
 * K&R A.8.7 defers: "All the expressions in the initializer for a static
 * object or array must be constant expressions as described in Par.A.7.19."
 * A.7.19 then grants them by name -- "the unary & operator may be applied to
 * external or static objects, and to external and static arrays subscripted
 * with a constant expression" -- and states the general rule the three forms
 * share: "Initializers must evaluate either to a constant or to the address of
 * a previously declared external or static object plus or minus a constant."
 *
 * THE SCALING IS THE PART A PARSE TEST WOULD MISS.  A subscript on an `int'
 * array displaces by two bytes per element, not one, and A.7.3.1 defines
 * E1[E2] as *(E1+E2), so `iarr + 2' and `&iarr[2]' must land on the SAME
 * byte -- checked here by comparing the two pointers, not just by writing
 * through one.  Exits 42 iff all three land (14 + 14 + 14). */
#define NELEM 8

struct pair { int a; int b; };

char arr[16];
int  iarr[NELEM];
struct pair obj;

char        *cp = &arr[16 - 2];     /* constant EXPRESSION, not just a literal */
int         *ip = &iarr[2];         /* scales by the element, not by one       */
int         *mp = &obj.b;           /* a member displacement                   */
int         *ap = iarr + 2;         /* the same address by the other spelling  */
struct pair *op = &obj;             /* no displacement -- must still work      */

int
main()
{
    int r = 0;

    *cp = 'Q';
    if (arr[14] == 'Q' && arr[13] == 0 && arr[15] == 0)
        r += 14;

    *ip = 0x1234;
    if (iarr[2] == 0x1234 && iarr[1] == 0 && iarr[3] == 0 && ip == ap)
        r += 14;

    obj.a = 0x1111;
    *mp = 0x2222;
    if (obj.a == 0x1111 && obj.b == 0x2222 && op == &obj)
        r += 14;

    return r;
}
