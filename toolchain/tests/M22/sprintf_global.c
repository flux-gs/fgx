/* M22: sprintf into a file-scope (data-bank) buffer.  Regression for the
 * fcc sprintf-destination-register bug: the fprintf/sprintf shim loaded
 * the destination into A, but the libc sprintf entry reads the buffer
 * from Y (STY pf_outBuf) — so sprintf wrote to a bogus offset, leaving
 * the buffer empty and corrupting the data bank (df humanize crashed).
 * fmt -> X, buf -> Y is the correct ABI.  buf becomes "31M"; returns 51
 * ('3'). */
#include <stdio.h>
char buf[12];
int main()
{
    sprintf(buf, "%d%c", 31, 'M');
    return buf[0];
}
