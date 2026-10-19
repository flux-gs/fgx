/* waitpid-shaped: a callee stores a value through a pointer to the CALLER's
 * bank-0 hardware-stack local (mimics libc waitpid's *status = ...).  The
 * caller then reads the local back.  -> 42 iff the far store hit the local. */
void setit(int *p) { *p = 42; }
int main(void) {
    int st;
    st = 0;
    setit(&st);
    return st;
}
