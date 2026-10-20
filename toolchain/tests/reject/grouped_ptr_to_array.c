/* expect: pointer to array/function declared as */
/* `int (*p)[4]' is a pointer to an array of four ints (K&R A.8.6: the group
 * changes the binding).  fcc has no pointer-to-array type, so it refuses the
 * declaration rather than reading it as `int *p[4]'. */
int (*p)[4];
