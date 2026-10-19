/* T5-C C4 batch 6: the socket family in C.
 *
 * Headless MAME has no NIC ("uthernet2: absent"), so every call here
 * exercises the DETERMINISTIC paths: socket() allocates its fd LAZILY
 * (succeeds with no interface — probed), everything else errors on a
 * known-bad fd.  The wrappers' -1/errno contract
 * and the _sock_argblk staging are what's under test; live-net behavior
 * stays with the live-net gates (nc/udpecho/ping, human-run).
 *
 * FGX-only (MAME oracle).  5+5+5+5+5+5+4+4+4 = 42. */
char sa[16];
char buf[8];

int main(void)
{
    int fd, r = 0;

    fd = socket(2, 2, 0);
    if (fd >= 0)                            r += 5;   /* lazy fd alloc */
    if (bind(99, sa, 16) == -1)             r += 5;
    if (connect(99, sa, 16) == -1)          r += 5;
    if (send(99, buf, 4, 0) == -1)          r += 5;
    if (recv(99, buf, 8, 0) == -1)          r += 5;
    if (setsockopt(99, 0, 0, buf, 4) == -1) r += 5;
    if (sendto(99, buf, 4, 0, sa, 16) == -1)   r += 4;
    if (recvfrom(99, buf, 8, 0, sa, 16) == -1) r += 4;
    if (ifctl(0, sa) == -1)                 r += 4;
    close(fd);
    return r;
}
