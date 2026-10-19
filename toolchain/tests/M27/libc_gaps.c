/* SP4 libc gaps: strchr (pointer return via [dp],Y walk) + write (SYS_WRITE
 * return value).  strchr("hello world",'w') -> a ptr whose *p == 'w';
 * write(1,"Z\n",2) -> 2.  6 + 2 + 34 = 42. */
char *strchr(char *s, int c);
int write(int fd, char *buf, int n);

int main()
{
    char *s = "hello world";
    char *p = strchr(s, 'w');
    int n = write(1, "Z\n", 2);
    int ok = (p != 0 && *p == 'w') ? 6 : 0;
    return ok + n + 34;
}
