/* ---- tty ioctls + signal registration (C4 batch 9) ---------------------- */

int ioctl(int fd, int cmd, char *arg)
{
    /* SYS_IOCTL: A=fd, X=cmd, Y=arg offset, DBR=arg bank */
    unsigned long lp = (unsigned long)arg;
    int r = (int)__syscall_db(65, (unsigned)(lp >> 16), fd, cmd, (unsigned)lp);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int gtty(int fd, char *sg)
{
    return ioctl(fd, 0x7408, sg);      /* TIOCGETP */
}

int stty(int fd, char *sg)
{
    return ioctl(fd, 0x7409, sg);      /* TIOCSETP */
}

