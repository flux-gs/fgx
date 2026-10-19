/* fnptr_tyarr: array of an fn-ptr TYPEDEF at global scope -- the tcsh ed.h
 * `extern PFCmd CcFuncTbl[];` + ed.defns.c `PFCmd CcFuncTbl[] = { f, ... }`
 * construct.  The fn-ptr-ness is in the typedef (base LT_FN_PTR, sig in
 * TypeSpec.struct_id), so this is a typedef + array declarator, NOT the
 * `(*name)()` syntax.  Exercises the fn-ptr-typedef-resolved global branch's
 * new array handling: extern incomplete [], sizeless [] = {names}, and sized
 * [N] = {names}, plus indexed calls.  -> 42. */
typedef int (*PFCmd)();
extern PFCmd ExtTbl[];           /* extern incomplete array -- no storage */
static int f0() { return 10; }
static int f1() { return 12; }
static int f2() { return 20; }
PFCmd Tbl[]  = { f0, f1, f2 };   /* sizeless [], func-name init */
PFCmd Tbl2[2] = { f0, f2 };      /* sized [N], func-name init */
int
main()
{
    PFCmd a = Tbl[0];
    PFCmd b = Tbl[1];
    PFCmd c = Tbl2[1];
    return a() + b() + c();      /* 10 + 12 + 20 == 42 */
}
