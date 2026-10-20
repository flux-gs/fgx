/* lvalue_addr_ptr2ptr: bare '&p[i]' on a pointer-to-pointer -- the address of
 * an element of the T*-array that p points at.  = p + i*sizeof(T*) with p's
 * BANK carried through (K&R A.7.4.2 '&', A.7.3.1 E1[E2]==*(E1+E2)); routed to
 * the uniform walker (N_ADDR_LV_E -> emit_lvalue_addr), whose deref-then-add
 * preserves the far-pointer bank that the plain p+i node drops.  Mirrors tcsh
 * sh.glob:230 / tc.func's '&p[i]'.  -> 42. */
int
main()
{
    int   a, b, c;
    int  *arr[4];
    int **p;
    int **q;
    int  *tmp;
    int   r;

    a = 10; b = 12; c = 20;
    arr[0] = &a; arr[1] = &b; arr[2] = &c;
    p = arr;

    q = &p[1];  tmp = *q;  r  = *tmp;   /* &arr[1] -> arr[1]==&b -> 12 */
    q = &p[2];  tmp = *q;  r += *tmp;   /* &arr[2] -> arr[2]==&c -> +20 = 32 */
    q = &p[0];  tmp = *q;  r += *tmp;   /* &arr[0] -> arr[0]==&a -> +10 = 42 */

    return r;
}
