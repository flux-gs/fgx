/* expect: block static '_libso_fld2b_n' has its address taken in an initialiser */
/* flags: --libso */
static int n;
static struct t { int *v; } tt = { &n };
int main() { return *tt.v; }
