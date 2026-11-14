/* FGX libc — netdb.h.  Host + service resolution (2.11BSD-shaped). */
#ifndef _NETDB_H
#define _NETDB_H
#include <sys/types.h>
struct hostent {
    char  *h_name;       /* official name  */
    char **h_aliases;    /* alias list     */
    int    h_addrtype;   /* AF_INET        */
    int    h_length;     /* address length */
    char **h_addr_list;  /* network-order addresses */
};
#define h_addr h_addr_list[0]

struct servent {
    char  *s_name;       /* official service name */
    char **s_aliases;
    int    s_port;       /* network order */
    char  *s_proto;      /* "tcp"/"udp" */
};

/* /etc/networks, 2.11BSD netdb.h's struct netent. */
struct netent {
    char    *n_name;        /* official name of net */
    char    **n_aliases;    /* alias list */
    int     n_addrtype;     /* net address type */
    u_long  n_net;          /* network # */
};

struct hostent  *gethostbyname(char *name);
struct netent   *getnetbyname(char *name);
struct netent   *getnetent(void);
int             setnetent(int f);
int             endnetent(void);
struct hostent  *gethostbyaddr(char *addr, int len, int type);
struct servent  *getservbyname(char *name, char *proto);

/* Resolver error status (set by gethostby*).  BSD-shaped. */
extern int h_errno;
#define HOST_NOT_FOUND  1       /* authoritative "no such host"       */
#define TRY_AGAIN       2       /* non-authoritative / timeout        */
#define NO_RECOVERY     3       /* non-recoverable (bad response)     */
#define NO_DATA         4       /* name valid, no A record            */
#endif
