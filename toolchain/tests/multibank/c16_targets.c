/* c16_targets.c — extern fn-ptr targets pinned in a DIFFERENT code bank than the
 * table that points at them (construct 16).  K&R empty-parens (elvis vikeys[] idiom). */
int c16_fa() { return 0x10; }
int c16_fb() { return 0x06; }
