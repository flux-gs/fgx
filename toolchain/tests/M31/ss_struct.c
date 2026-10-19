struct pt { int x; char c; int *p; };
int gv;
int main(void) {
	struct pt s;
	gv = 40;
	s.x = 30;
	s.c = 5;
	s.p = &gv;
	return s.x + s.c + (*s.p - 33);   /* 30+5+7 = 42 */
}
