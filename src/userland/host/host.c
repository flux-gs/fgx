/* host - look up host names and addresses via the FGX resolver.
 *   host <name>        forward:  name  -> address     (gethostbyname)
 *   host <a.b.c.d>     reverse:  address -> name       (gethostbyaddr)
 * Built on libc's slim resolver (/etc/hosts, then DNS-over-UDP).  A `host`-style
 * front end; not an nslookup port (that needs res_* + HEADER bitfields + lex,
 * none of which fcc/FGX has).  -t/MX and other RR types are a follow-up. */
#include <stdio.h>
#include <string.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(int argc, char **argv)
{
    char *arg;
    struct hostent *h;
    unsigned char *a;
    unsigned long v;

    if (argc < 2) { printf("usage: host <name> | host <ip-address>\n"); return 1; }
    arg = argv[1];

    v = inet_addr(arg);
    if (v != (unsigned long)-1) {              /* a.b.c.d -> reverse PTR lookup */
        unsigned char ip[4];
        ip[0]=v&255; ip[1]=(v>>8)&255; ip[2]=(v>>16)&255; ip[3]=(v>>24)&255;
        h = gethostbyaddr((char *)ip, 4, AF_INET);
        if (h == 0) { printf("Host %s not found\n", arg); return 1; }
        printf("%s domain name pointer %s\n", arg, h->h_name);
        return 0;
    }

    h = gethostbyname(arg);                    /* name -> address */
    if (h == 0) { printf("Host %s not found\n", arg); return 1; }
    a = (unsigned char *)h->h_addr_list[0];
    printf("%s has address %d.%d.%d.%d\n", h->h_name, a[0], a[1], a[2], a[3]);
    return 0;
}
