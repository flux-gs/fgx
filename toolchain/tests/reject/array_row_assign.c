/* expect: an array is not a modifiable lvalue */
/* K&R A.8.6.2: of `int x3d[3][5][7]', "x3d[i], x3d[i][j] ... have type
 * ``array''".  One subscript of a two-dimensional array is a ROW.  In value
 * position this was typed as an int and stored two bytes at the row's start. */
int m2[2][3];
int *q;

int f() { if ((m2[1] = q) != 0) return 1; return 0; }
