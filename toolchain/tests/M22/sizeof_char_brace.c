/* sizeof of an implicitly-sized char[] with a BRACE-LIST initializer.
 * fcc sized `char x[]={...}` at 2*n (int stride) while emitting n bytes, so
 * sizeof over-reported 2x — telnet's `nfrontp += sizeof(doopt)-2` over-ran and
 * leaked NULs onto the wire (garble after the login prompt).  Now 1 byte/elem.
 * doopt is telnet's exact idiom (IAC-valued bytes > 127).  -> 42. */
char doopt[] = { 255, 253, '%', 'c', 0 };   /* 5 bytes */
char two[]   = { 1, 2 };                      /* 2 bytes */
char nums[3] = { 1, 2, 3 };                   /* 3 bytes, explicit size */
int main(void)
{
    /* 5*7 + 2*2 + 3 = 35 + 4 + 3 = 42; under the 2x bug: 10*7+4+3 = 77 */
    return sizeof(doopt) * 7 + sizeof(two) * 2 + sizeof(nums);
}
