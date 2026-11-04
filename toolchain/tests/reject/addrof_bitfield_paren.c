/* expect: bit-field */
struct bf { int a : 3; int b : 5; };
struct h { int z; struct bf w; } *hp;
int main() { int *p; p = &(hp)->w.b; return 0; }
