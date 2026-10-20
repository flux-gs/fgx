/* K&R varargs ABI — the elvis msg(fmt, ...) pattern: a char* param0 (fmt) in a
 * variadic call.  Exercises the 4-byte far-pointer arg push + the pointer-param
 * read from the shallow slot.  '*' is ASCII 42, so fmt[0]==42 iff param0 (fmt)
 * was read correctly. */
int msgish();

int
main()
{
    return msgish("*ok", 7);   /* "*"[0] == 42 */
}

int
msgish(fmt, a, b, c, d, e)
    char *fmt;
    int a, b, c, d, e;
{
    return fmt[0];             /* '*' == 42 on success */
}
