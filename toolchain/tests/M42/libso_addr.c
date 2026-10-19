/* M42: --libso block-static address.  &s of a block static is its block
 * cell's value plus its offset, in the data bank. */
static int s = 5;
int deref(p) int *p; { return *p; }
int main() { return deref(&s) == 5 ? 42 : 1; }
