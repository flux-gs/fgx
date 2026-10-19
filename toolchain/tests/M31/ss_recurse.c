int rec(int depth, char c)
{
	char buf[256];
	int  i, r;
	for (i = 0; i < 256; i++) buf[i] = c;
	if (depth > 0) r = rec(depth - 1, c + 1); else r = 0;
	if (buf[0] != c) return 100;        /* frame aliasing bug -> fail */
	return r + buf[0];
}
int main(void) { return rec(3, 9); }    /* 4*9+6 = 42 */
