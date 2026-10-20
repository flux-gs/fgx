/* B-3: int ** double-deref.  v=42; q=&v; p=&q; **p == 42. */
int v = 42;
int main(void){ int *q; int **p; q = &v; p = &q; return **p; }
