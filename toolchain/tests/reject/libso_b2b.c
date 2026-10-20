/* expect: block static '_libso_b2b_n' has its address taken in an initialiser */
/* flags: --libso */
static int n = 5;
static int *p = &n;
int main() { return *p; }
