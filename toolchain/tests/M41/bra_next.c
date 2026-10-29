/* A far conditional that skips a BRL to the very next label.  `if (a < b)
 * { }' compiles to `BMI *+5 / BRL L / L:'; the peephole deletes the BRL as
 * a branch to the next line, and the BMI then skipped five bytes from
 * itself, past L and into the middle of `LDA g', so f returned the compare
 * result instead of g whenever a < b.  Returns 42. */
int g = 42;

int
f(a, b)
int a, b;
{
	if (a < b) {
	}
	return g;
}

int
main()
{
	if (f(2, 1) != 42)
		return 1;
	return f(1, 2);
}
