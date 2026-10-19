/* expect: the operand of '~' must have integral type */
/* K&R A.7.4.6: "The operand of the ~ operator must have integral type".  A
 * float compiled to EOR #$FFFF on the low word of its bits. */
float f;
g() { return ~f; }
