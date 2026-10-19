/* ---- qsort (H1) -----------------------------------------------------------
 * Shellsort under the qsort(3) contract: in-place, no recursion (the 65816
 * HW stack is small), fine for the few-hundred-element arrays ports sort.
 * cmp gets two far element pointers.  ABI NOTE: the cmp sig is TYPED
 * (2 fixed params, L-to-R) — callers must pass a PROTOTYPED cmp (or a
 * K&R one with a full-prototype forward decl).  An empty-paren `int
 * fcmp();` decl makes the callee read params SHALLOWEST-first (RTL-ABI)
 * while a ()-sig fn-ptr call pushes L-to-R: two same-size args arrive
 * exactly REVERSED (ls -1 sorted descending).  The general ()-fn-ptr vs
 * K&R-callee mismatch is registered in fgx docs/fcc-known-issues.md.
 * gap sequence: n/2, /2, ... */
void qsort(char *base, int n, int size, int (*cmp)(char *, char *))
{
    int gap, i, j, k, t;
    char *a, *b;

    for (gap = n / 2; gap > 0; gap = gap / 2) {
        for (i = gap; i < n; i++) {
            for (j = i - gap; j >= 0; j = j - gap) {
                a = base + j * size;
                b = base + (j + gap) * size;
                if (cmp(a, b) <= 0)
                    break;
                for (k = 0; k < size; k++) {     /* byte swap */
                    t = a[k];
                    a[k] = b[k];
                    b[k] = t;
                }
            }
        }
    }
}

