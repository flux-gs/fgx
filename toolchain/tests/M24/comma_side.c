/* C-2: comma operator evaluates left for its side effect, value is right.
 * b = (a=3, a+4) -> a becomes 3, then a+4 = 7.  Returns 7. */
int main(){ int a; int b; a=0; b=(a=3, a+4); return b; }
