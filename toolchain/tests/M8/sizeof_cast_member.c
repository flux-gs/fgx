/* sizeof_cast_member: `sizeof(((struct T *) 0)->field)` -- the "size of a
 * struct member without an instance" idiom (tcsh tc.who
 * `sizeof(((struct utmp *) 0)->ut_name)`, used in both array dims and at
 * runtime).  sizeof's operand parser now recognises a (struct TAG *) member
 * cast and yields the final field's byte_size, compile-time.  -> 42. */
struct utmp { char ut_line[8]; char ut_name[8]; char ut_host[16]; };

int
main()
{
    int a = sizeof(((struct utmp *) 0)->ut_name);       /* 8 */
    int b = sizeof(((struct utmp *) 0)->ut_host);       /* 16 */
    char buf[sizeof(((struct utmp *) 0)->ut_line)];     /* const-dim: [8] */
    buf[0] = 0;
    return a + b + sizeof(buf) + 10;                    /* 8+16+8+10 == 42 */
}
