/* M11: inet_makeaddr and inet_network, 2.11BSD libc inet/inet_maddr.c and
 * inet/inet_network.c.  ifconfig(8) reads a network name through them.
 * inet_makeaddr puts the host into the class's host part: net 127 host 1 is
 * 127.0.0.1, net 128.10 (class B) host 2 is 128.10.0.2, net 192.168.4
 * (class C) host 9 is 192.168.4.9.  inet_network reads the dotted parts as a
 * network number: "10.1" is 0x0a01, "0x7f" is 127, and junk is -1.
 * Returns 42 iff every case holds; a small code names the first failure. */
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main()
{
    struct in_addr a;

    a = inet_makeaddr(127L, 1L);
    if (a.s_addr != htonl(0x7f000001L)) return 1;
    a = inet_makeaddr(0x800aL, 2L);
    if (a.s_addr != htonl(0x800a0002L)) return 2;
    a = inet_makeaddr(0xc0a804L, 9L);
    if (a.s_addr != htonl(0xc0a80409L)) return 3;
    if (inet_network("10.1") != 0x0a01L) return 4;
    if (inet_network("0x7f") != 127L) return 5;
    if (inet_network("zz") != -1L) return 6;
    return 42;
}
