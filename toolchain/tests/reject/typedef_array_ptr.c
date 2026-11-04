/* expect: array typedef */
typedef long A[4];
int f() { A *p; return sizeof *p; }
