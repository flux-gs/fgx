/* B-2: union members overlap.  set p->a=42; reading x.b (same storage) = 42. */
union u { int a; int b; };
void setit(union u *p){ p->a = 42; }
int main(){ union u x; x.b = 0; setit(&x); return x.b; }
