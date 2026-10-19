/* expect: need arithmetic operands */
/* K&R A.7.6: "The operands of * and / must have arithmetic type".  A pointer
 * times two shifted the address's offset word. */
int *p;
int x;

int f() { x = p * 2; return 0; }
