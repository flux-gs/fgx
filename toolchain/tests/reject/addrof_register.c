/* expect: register */
int main() { register int r; int *p; r = 1; p = &r; return 0; }
