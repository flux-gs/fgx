/* C-2: comma operator in a parenthesized expr — value is the last operand.
 * (5, 7) == 7. */
int main(){ int a; int b; a=5; b=7; return (a, b); }
