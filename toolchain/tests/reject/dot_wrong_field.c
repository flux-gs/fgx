/* expect: no such field */
/* The ONE-HOP form, which fcc rejected correctly all along.  Committed anyway:
 * the two-hop bug was invisible precisely because this case looked fine, so a
 * fix that traded this rejection away would otherwise read as a clean pass. */
struct one { int a; };
struct two { int b; };
struct one M;

int f() { M.b = 7; return 0; }
