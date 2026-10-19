/* Redundant outer parens around a parenthesized-lvalue assignment — recycle's
 * CLR expands its if-body to `((bitmap[i]) &= ~m)`.  The outer layer is stripped
 * and re-dispatched so the inner `(lvalue) op=` / `(lvalue) =` reaches the G21
 * handlers.  Global-array element (via the DBR-bank compound fix), local scalar,
 * and a triple-paren assign.  -> 42. */
int gv[4];
int gsv;

int main(void)
{
	int lsv;

	gv[0] = 40; if (1) ((gv[0]) += 2);   /* 42, double-paren compound, global arr */
	lsv = 15;   ((lsv) &= 6);             /* 6,  double-paren compound, local     */
	gsv = 100;  (((gsv)) = 7);            /* 7,  triple-paren assign              */

	if (lsv != 6) return 1;
	if (gsv != 7) return 2;
	return gv[0];                         /* 42 */
}
