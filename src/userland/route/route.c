/*
 * route - minimal routing config (FGX net-config v1).
 *
 *   route add default <A.B.C.D>
 *
 * Stores the default gateway on the primary interface (ifnet index 0) via
 * SYS_IFCONFIG.  It only STORES the gateway in the ifnet record: the W5100
 * does IP in hardware and takes the gateway from there, and FGX has no
 * routing or forwarding engine of its own.
 *
 * Raw 32-byte ifreq (fcc still even-aligns word members, so no struct even
 * post-B-8); offsets mirror the kernel IF_* layout.
 */
#include <stdio.h>

#define IFR_SIZE      32
#define IFR_SLOT       8
#define IFR_GATEWAY   28

#define IFC_GETN      0
#define IFC_SET       2

int ifctl(int op, unsigned char *ifr);

static unsigned char ifr[IFR_SIZE];

static void parse_ip(char *s, int off)
{
    int i, v;
    for (i = 0; i < 4; i++) {
        v = 0;
        while (*s >= '0' && *s <= '9') {
            v = v * 10 + (*s - '0');
            s++;
        }
        ifr[off + i] = v;
        if (*s == '.')
            s++;
    }
}

int main(int argc, char **argv)
{
    /* route add default <gw> : argv[1]='add' (a), argv[2]='default' (d) */
    if (argc < 4 || argv[1][0] != 'a' || argv[2][0] != 'd') {
        printf("usage: route add default <gateway>\n");
        return 1;
    }

    ifr[IFR_SLOT] = 0;                  /* primary interface */
    if (ifctl(IFC_GETN, ifr) != 0) {
        printf("route: no interface\n");
        return 1;
    }
    parse_ip(argv[3], IFR_GATEWAY);     /* GETN preserved ip/netmask/broadcast */
    if (ifctl(IFC_SET, ifr) != 0) {
        printf("route: set failed\n");
        return 1;
    }
    printf("default gateway %u.%u.%u.%u\n",
           ifr[IFR_GATEWAY], ifr[IFR_GATEWAY + 1],
           ifr[IFR_GATEWAY + 2], ifr[IFR_GATEWAY + 3]);
    return 0;
}
