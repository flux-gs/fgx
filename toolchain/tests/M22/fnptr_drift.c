/* M22/G-drift: struct-array fn-ptr dispatch table (elvis vikeys[] shape) whose
 * target functions are FORWARD-DECLARED and DEFINED AFTER the table.  Defining
 * a forward-declared function PROMOTES it (its g_funcs slot is removed and the
 * definition re-appended at the end, renumbering the slots between).  The
 * struct-array's stored fn indices must be remapped through that renumbering,
 * else each entry names whatever function slid into the promoted slot -- this
 * is why elvis vi.c's `{v_start,...}` vikeys entries emitted `strcpy` (fixed in
 * symtab.c funcs_declare's remap loop, which now covers struct fn-ptr fields).
 * tbl[0] must stay add_a through the promotions -> add_a(40) = 42; the pre-fix
 * compiler drifted tbl[0] onto add_b (returned 60). */
int add_a();
int add_b();
int add_c();

struct centry { int (*fn)(); int tag; };
struct centry tbl[] = {
    { add_a, 1 },
    { add_b, 2 },
    { add_c, 3 },
};

int add_b(x) int x; { return x + 20; }
int add_c(x) int x; { return x + 30; }
int add_a(x) int x; { return x + 2; }

int main(void)
{
    return tbl[0].fn(40);   /* add_a(40) = 42 */
}
