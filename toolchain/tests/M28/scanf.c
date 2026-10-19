/* scanf(3), 2.11BSD's _doscan (libc_c/doscan.c, scanf.c), apple/fgx#447.
 * K&R 2nd ed B.1.3.  Covered through sscanf: %d %o %x, h and l, a field
 * width, `*' suppression, %s %c %[...], a literal between conversions, %f
 * %e %g into a float and %le %lf %lg %Le into a double, the count returned,
 * EOF on empty input and 0 on a mismatch.  Through fscanf on a file: a field
 * ends at a character the scan pushes back, which the next getc returns, and
 * a scan at end of file returns EOF.  A failing check returns its number;
 * all passing returns 42. */
#include <stdio.h>
extern int unlink();

static double
mag(x)
	double x;
{
	return x < 0 ? -x : x;
}

int
main()
{
	int a, b, c, d, n;
	long l;
	short h;
	char s[16], t[16], ch;
	float f;
	double x;
	long double y;
	FILE *fp;

	n = sscanf("12 -34 077 ff", "%d %d %o %x", &a, &b, &c, &d);
	if (n != 4 || a != 12 || b != -34 || c != 63 || d != 255) return 1;
	n = sscanf("70000 -5", "%ld %hd", &l, &h);
	if (n != 2 || l != 70000L || h != -5) return 2;
	n = sscanf("12345", "%3d%d", &a, &b);
	if (n != 2 || a != 123 || b != 45) return 3;
	n = sscanf("7 8", "%*d %d", &a);
	if (n != 1 || a != 8) return 4;
	n = sscanf("hello x", "%s %c", s, &ch);
	if (n != 2 || s[0] != 'h' || s[4] != 'o' || s[5] != 0 || ch != 'x')
		return 5;
	n = sscanf("abc123", "%[a-z]%d", t, &a);
	if (n != 2 || t[2] != 'c' || t[3] != 0 || a != 123) return 6;
	n = sscanf("1,2", "%d,%d", &a, &b);
	if (n != 2 || a != 1 || b != 2) return 7;

	n = sscanf("2.5", "%f", &f);
	if (n != 1 || f != 2.5f) return 8;
	n = sscanf("1e3", "%g", &f);
	if (n != 1 || f != 1000.0f) return 9;
	n = sscanf("-0.375", "%e", &f);
	if (n != 1 || f != -0.375f) return 10;
	n = sscanf("0.1", "%le", &x);
	if (n != 1 || x != 0.1) return 11;
	n = sscanf("3970000000.201", "%lf", &x);
	if (n != 1 || mag(x - 3970000000.201) > 1e-6) return 12;
	n = sscanf("-2.5e-3", "%lg", &x);
	if (n != 1 || mag(x + 0.0025) > 1e-18) return 13;
	n = sscanf("-0.375", "%Le", &y);
	if (n != 1 || y != -0.375L) return 14;

	a = 99;
	if (sscanf("", "%d", &a) != EOF || a != 99) return 15;
	if (sscanf("x", "%d", &a) != 0 || a != 99) return 16;

	fp = fopen("/tmp/scn", "w");
	if (fp == NULL) return 17;
	fputs("42 3.25\n", fp);
	fclose(fp);
	fp = fopen("/tmp/scn", "r");
	if (fp == NULL) return 18;
	n = fscanf(fp, "%d %lf", &a, &x);
	if (n != 2 || a != 42 || x != 3.25) return 19;
	if (getc(fp) != '\n') return 20;
	if (fscanf(fp, "%d", &a) != EOF) return 21;
	fclose(fp);
	unlink("/tmp/scn");
	return 42;
}
