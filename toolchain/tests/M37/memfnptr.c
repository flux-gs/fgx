/* Direct call through a struct-member function pointer via `->`, in BOTH
 * expression and statement position, one hop and two, plus the empty-paren
 * `void (*)()` shape joe's watom->disp uses.  Before the fix only `(p->fn)(a)`
 * and `fp=p->fn; fp(a)` worked: build_postfix_value_chain had no fn-ptr call
 * arm (expr), and the statement dispatcher parsed the chain then died
 * "expected '='" on the '(' (stmt).  FGX-only oracle.
 * 10 (1hop expr) + 10 (2hop expr) + 10 (2hop stmt) + 12 (empty-paren stmt) = 42. */
int add3(int x) { return x + 3; }
int dbl(int x)  { return x * 2; }

struct inner { int (*fn)(int); int out; };
struct outer { struct inner *in; int (*g)(int); };

int g_side;
void setside() { g_side = 30; }        /* void (*)() empty-paren member target */
struct ev { void (*hit)(); };

struct inner g_in;
struct outer g_o;
struct ev g_e;

int main(void)
{
    struct outer *o = &g_o;
    struct ev *e = &g_e;
    int r = 0;

    g_in.fn = add3; g_in.out = 0;
    o->in = &g_in;
    o->g  = dbl;
    e->hit = setside;

    if (o->g(5) == 10) r += 10;            /* 1-hop member call, expr */
    if (o->in->fn(7) == 10) r += 10;       /* 2-hop member call, expr */

    o->in->fn(3);                          /* 2-hop member call, bare stmt */
    e->hit();                              /* empty-paren member call, stmt */
    if (g_side == 30) r += 10;

    o->in->out = o->in->fn(9);             /* member call as store RHS */
    if (o->in->out == 12) r += 12;

    return r;
}
