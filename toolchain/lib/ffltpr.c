/*
 * ffltpr -- printf's %e, %f and %g for a static program that prints no
 * floating point: a `?' in place of the number.
 *
 * 2.11BSD's vendor/2.11BSD/usr/lib/libc/pdp/stdio/ffltpr.s is "Fake floating
 * output support for doprnt": its pfloat, pscien and pgen "Simply output a
 * "?"" and step over the double.  fltpr.s says when it is used: "If fltused
 * is not defined the references to pgen, pfloat and pscien in doprnt will be
 * satisfied by ffltpr.s (fake floating print)."
 *
 * Here libc's printf always calls __lc_pf_float (libc_c/fltpr.c), and fcc
 * marks a translation unit that can print a float with `]__lc_fltused'.
 * fgx_static links this file, compiled as program source, into a program
 * none of whose units carries the marker; its __lc_pf_float, a definition in
 * the program, shadows libc's (fgx_gc.graph's archive search), and fltpr
 * with ecvt and fcvt is never reached.  libc.so, and so every dynamic
 * program, keeps the real printer.
 */
void __lc_pf_q(int width, int zeropad, int leftjust);

void __lc_pf_float(int c, double f, int width, int prec, int hasprec,
                   int zeropad, int leftjust)
{
    __lc_pf_q(width, zeropad, leftjust);
}
