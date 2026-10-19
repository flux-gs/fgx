/* (expr)[i][j] — subscripting a PARENTHESIZED pointer value, incl. the
 * double-subscript-on-char** case (++argv)[0][0] that fcc once rejected with
 * "expected ')'".  emit_index_ptr_value used to byte-load a T**[i] element as
 * LT_INT, stopping the chain; it now loads the 4-byte far-pointer element and
 * keeps the result a pointer (g_expr_type = DECREF(pt)), so a following
 * subscript chains.  Returns 42 iff every parenthesized index reads right. */
char a[] = "Xy";
char b[] = "Qz";
char *row[2];

int main(void)
{
	char **p;

	row[0] = a;
	row[1] = b;
	p = row;

	if ((p)[1][0] != 'Q')      /* row[1][0] = b[0] */
		return 1;
	if ((p)[0][1] != 'y')      /* row[0][1] = a[1] */
		return 2;
	if ((++p)[0][0] != 'Q')    /* ++p -> row[1]; [0][0] = b[0] */
		return 3;
	return 42;
}
