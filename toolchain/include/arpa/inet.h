/* FGX libc — arpa/inet.h. */
#ifndef _ARPA_INET_H
#define _ARPA_INET_H
#include <sys/types.h>
u_long inet_addr(char *cp);       /* dotted-quad -> network-order addr; -1 on error */
char  *inet_ntoa(struct in_addr in);
#endif
