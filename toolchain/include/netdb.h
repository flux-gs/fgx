/* FGX libc — netdb.h.  Host + service resolution (2.11BSD-shaped). */
#ifndef _NETDB_H
#define _NETDB_H
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

struct hostent  *gethostbyname(char *name);
struct hostent  *gethostbyaddr(char *addr, int len, int type);
struct servent  *getservbyname(char *name, char *proto);

/* Resolver error status (set by gethostby*).  BSD-shaped. */
extern int h_errno;
#define HOST_NOT_FOUND  1       /* authoritative "no such host"       */
#define TRY_AGAIN       2       /* non-authoritative / timeout        */
#define NO_RECOVERY     3       /* non-recoverable (bad response)     */
#define NO_DATA         4       /* name valid, no A record            */
#endif
