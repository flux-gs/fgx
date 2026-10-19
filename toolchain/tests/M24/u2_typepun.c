/* B-2: union type-punning.  x.i = 0x4142; little-endian byte 0 = 0x42 = 66. */
union u { int i; char c[2]; };
int main(){ union u x; x.i = 0x4142; return x.c[0]; }
