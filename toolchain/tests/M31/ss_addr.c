void set(int *p) { *p = 42; }
int main(void) { int x; x = 0; set(&x); return x; }
