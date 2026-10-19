int main(void) {
	int  a[4];
	char b[4];
	int  i, s;
	for (i = 0; i < 4; i++) a[i] = i * 3;   /* 0,3,6,9 = 18 */
	for (i = 0; i < 4; i++) b[i] = i + 1;   /* 1,2,3,4 = 10 */
	s = 0;
	for (i = 0; i < 4; i++) s = s + a[i] + b[i];   /* 28 */
	return s + 14;   /* 42 */
}
