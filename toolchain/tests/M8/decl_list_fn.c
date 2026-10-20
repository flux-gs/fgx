/* A function declarator among a file-scope init-declarator-list, first or
 * after an object: `int timedout, timeout();' (2.11BSD ntpdc) and `long
 * g(), y;'.  K&R A.8: the list's elements are init-declarators, and "The
 * declarators in the init-declarator list contain the identifiers being
 * declared".  g is called before its definition, so its declared long return
 * must be the one used.  Returns 42. */

int timedout, timeout();
long g(), y;

int main()
{
    timedout = 30;
    y = 100000L;
    return timeout() + (int)(g() - 99990L);   /* 30 + 12 */
}

int timeout() { return timedout; }
long g() { return y + 2; }
