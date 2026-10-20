/* setbuf — buffer SELECTION is still a no-op: fopen'd read FILEs get libc's own
 * 512-byte buffer and nothing else is buffered, so there is no caller buffer to
 * install and no unbuffered mode to request (BSD compat). */
void setbuf(char *fp, char *buf)
{
    (void)fp; (void)buf;
}
