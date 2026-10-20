/* A null pointer constant stored in a function-pointer member of a static
 * struct is a null pointer: offset and bank both 0 (K&R A.6.6).  The member
 * is first set to a function, which leaves that function's bank in fcc's
 * far-pointer scratch, so a store that took its bank from the scratch would
 * leave the code bank behind.  Returns 42. */
struct s { int pad; int (*fp)(); } sa;

int one()
{
    return 1;
}

int main()
{
    unsigned char *b;

    sa.fp = one;
    sa.fp = 0;
    b = (unsigned char *)&sa.fp;
    return b[0] == 0 && b[1] == 0 && b[2] == 0 ? 42 : 7;
}
