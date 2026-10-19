/* expect: block static '_libso_asm_n' is named in an __asm line */
/* flags: --libso */
static int n;
int main() { __asm("LDA _libso_asm_n"); return n; }
