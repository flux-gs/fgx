/* fnptr_arr_null: a `0`/NULL entry in an fn-ptr array initializer -- tcsh's
 * ed.defns.c `PFCmd FuncNames[] = { e_expand, ..., 0 }` where the trailing 0
 * is a DUMMY VALUE / NULL terminator.  The walker previously required every
 * item to be a function name; a 0 now emits a 4-byte-zero (NULL) slot.  -> 42. */
typedef int (*PFCmd)();
static int f0() { return 30; }
static int f1() { return 12; }
PFCmd Tbl[] = { f0, f1, 0 };     /* trailing NULL slot */

int
main()
{
    PFCmd a = Tbl[0];
    PFCmd b = Tbl[1];
    int nullslot = (Tbl[2] == 0) ? 0 : 999;   /* NULL slot is zero */
    return a() + b() + nullslot;              /* 30 + 12 + 0 == 42 */
}
