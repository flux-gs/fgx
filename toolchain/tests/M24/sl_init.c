/* C-3: static local with constant initializer runs once at load.
 * n inits to 40; two calls 40->41->42.  Returns 42 (if init failed to
 * apply, n would start at 0 and this returns 2). */
int seq(){ static int n = 40; n=n+1; return n; }
int main(){ seq(); return seq(); }
