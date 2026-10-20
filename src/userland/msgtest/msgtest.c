/* msgtest.c - bisect the elvis msg()/sprintf %ld hang, headless.
 *
 * The full msgtest hung inside libc pf_format_udec32 (the %ld digit-extraction
 * loop) with Y (the digit counter) blown to 26584 - a non-terminating subtract.
 * This version prints a progress marker before AND after each case so the LAST
 * marker on screen pinpoints exactly which %ld case hangs:
 *
 *   T1 = direct sprintf %ld, small constant (13)
 *   T2 = direct sprintf %ld, a value >= 10^9 (enters the 10^9 subtract loop)
 *   T3 = through the K&R m() layer, %ld small constant
 *   T4 = the full elvis tmp.c:411 shape (mixed pointer/long args)
 *
 * m() mirrors elvis tio.c msg(): K&R, all args long, implicitly declared at the
 * call site (defined below main) so no arg-count check - like elvis's cross-TU
 * calls.  Whichever "Tn ok" is the last line printed, case n+1 is the culprit.
 */

#include <stdio.h>	/* printf/sprintf are variadic: the `...` prototype makes
			 * fcc marshal them right-to-left.  Without the binding
			 * table (Stage A2) an implicit decl would marshal L-to-R. */

char pmsg[80];

extern void m();		/* empty-parens K&R decl, exactly like elvis vi.h:292 msg() */

int main()
{
	char buf[80];

	printf("T0 start\n");

	sprintf(buf, "%ld", 13L);
	printf("T1 ok [%s]\n", buf);

	sprintf(buf, "%ld", 1000000000L);
	printf("T2 ok [%s]\n", buf);

	m("%ld", 13L);
	printf("T3 ok [%s]\n", pmsg);

	m("\"%s\" %s %ld line%s, %ld char%s",
		"/etc/hostname", "", 1L, "", 13L, "s");
	printf("T4 ok [%s]\n", pmsg);

	printf("DONE\n");
	return 0;
}

/* elvis tio.c:263 msg() shape - K&R, all args long, non-__STDC__ branch */
void m(fmt, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
	char	*fmt;
	long	arg1, arg2, arg3, arg4, arg5, arg6, arg7;
{
	sprintf(pmsg, fmt, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}
