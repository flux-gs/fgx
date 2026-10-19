/* A `( declarator )' group names the same object as the bare declarator (K&R
 * A.8.6: "The parentheses do not alter the type, but may change the binding
 * of complex declarators").  Vixie cron's bit_decl macro writes every bitmap
 * as `bitstr_t (name)[n]' -- a struct member here, a global, a local, and a
 * `*' inside the group with nothing after it, which is still a plain
 * pointer.  Returns 42. */

typedef unsigned char bitstr_t;

struct ent {
    bitstr_t (minute)[8];
    bitstr_t (hour)[3];
    int flags;
};

static struct ent e;
static char (g)[4];
static int ((*gp));

int main()
{
    int (n);
    char *(p);

    e.hour[2] = 10;
    e.flags = 5;
    g[3] = 20;
    n = 4;
    gp = &n;
    p = &g[3];
    return e.hour[2] + e.flags + *p + *gp + sizeof(e.minute) - 5;  /* 10+5+20+4+8-5 */
}
