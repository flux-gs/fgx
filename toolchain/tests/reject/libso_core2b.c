/* expect: block static '_libso_core2b_n' has its address taken in an initialiser */
/* flags: --libso */
static int n;
int *q = &n;
int main() { return *q; }
