/* postinc_ptrarray_elem: postfix '++' of a POINTER-array element, old value
 * dereferenced -- `*tab[i]++` (tcsh ed.inputl `*KeyMacro[MacroLvl]++`, KeyMacro
 * a `Char *[]`).  This bumps the element pointer tab[i] (a Char* cursor) in
 * place and dereferences the OLD value; distinct from the whole-array cases.
 * The array-subscript postfix path handled only int/char array elements
 * (N_ARR_POSTINC), leaving '++' on a pointer element unconsumed ("expected
 * ';'").  Routed to N_LV_INCDEC_E (chain mode): address = &tab[i] via
 * emit_lvalue_addr, then the shared in-place RMW yields the OLD far pointer.
 * K&R A.7.3.4 (postfix), A.7.3.1 (E1[E2]), A.7.4.3 ('*').  -> 42. */
char  str[5];
char *tab[2];

int
main()
{
    int r, i;

    str[0] = 10; str[1] = 12; str[2] = 20; str[3] = 99;
    tab[0] = str;            /* tab[0] = cursor -> &str[0] */
    tab[1] = 0;
    i = 0;

    r  = *tab[i]++;          /* *str[0]=10 ; tab[0] -> &str[1]      */
    r += *tab[i]++;          /* *str[1]=12 ; tab[0] -> &str[2] (=22)*/
    r += *tab[i];            /* str[2]=20  (no ++)             (=42)*/

    return r;                /* 42 */
}
