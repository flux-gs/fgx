/* expect: bit-field */
struct bf { int a : 3; int b : 5; } s;
int main() { int *p; p = &s.b; return 0; }
