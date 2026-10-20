/* `&s.u.p[i]': the address of a subscript of a POINTER member reached
 * through an embedded union -- net/if.h's `&ifc.ifc_req[i]', which is
 * `&ifc.ifc_ifcu.ifcu_req[i]'.  K&R A.7.4.2: "The unary operator & takes the
 * address of its operand.  The operand must be an lvalue referring neither to
 * a bit-field nor to an object declared as register"; the member hops that
 * reached the lvalue are not a condition.  A local and a global.  Returns 42. */

struct req { char name[16]; int flags; };
struct conf {
    int len;
    union { char *buf; struct req *req; } u;
};

static struct req arr[3];
static struct conf G;

int main()
{
    struct conf c;
    struct req *r, *q;

    arr[0].flags = 1;
    arr[1].flags = 10;
    arr[2].flags = 30;
    c.u.req = arr;
    G.u.req = arr;
    r = &c.u.req[2];
    q = &G.u.req[1];
    r->flags += 1;                 /* 31, through the address */
    return r->flags + q->flags + (int)(r - q);   /* 31 + 10 + 1 */
}
