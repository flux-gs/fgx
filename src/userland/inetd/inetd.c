/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD inetd(8)
 *   Reshaped from inetd(8), 2.11BSD (inetd.c 8.4.1 (2.11BSD) 1996/10/30),
 *   vendored at vendor/2.11BSD/usr/usr.sbin/inetd/inetd.c.
 *   Copyright (c) 1983, 1991, 1993, 1994
 *   The Regents of the University of California.  All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * inetd(8) - internet super-server.
 *
 * The configuration file, its syntax, the servtab shape, the select-over-
 * listeners loop and the hand-off contract (the connection arrives as the
 * child's fd 0, 1 and 2) are all upstream's.  What follows is what FGX makes
 * different, because one of them is structural rather than a simplification.
 *
 * A LISTENER IS SINGLE-USE ON THE WIRE, AND THAT REWRITES THE MAIN LOOP.  On
 * the W5100 path accept(2) DETACHES the listener: the hardware socket moves to
 * the accepted connection and the listening descriptor is left owning nothing
 * (include/socket.s, SOCK_HW_NONE -- "accept detaches the listener's hw ->
 * the connfd").  Upstream binds once at startup and accepts forever; this
 * re-arms after every accept, and a service whose re-arm fails is carried as
 * DOWN and retried rather than silently dropped.
 *
 * THE TWO TRANSPORTS DO NOT AGREE ABOUT THIS, whatever the loopback code's own
 * comment suggests: _Loop_AcceptTry leaves its listener InUse and TCP_LISTEN --
 * "the listener is free again (one caller at a time)" -- so on loopback the
 * listener is NOT spent and re-arming it is redundant.  Redundant, but not
 * harmful, because handoff() closes the old one in the child: two live
 * TCP_LISTEN descriptors on one port would send every later connect to
 * whichever _Loop_FindListener reaches first.  Re-arming is unconditional
 * because inetd cannot tell the transports apart: one wildcard listener
 * serves both, the wire through the card and 127.0.0.1 through the rings
 * (apple/fgx#128, #363).
 *
 * THREE HARDWARE SOCKETS, TOTAL.  _W5_SockAlloc hands out 1..3 (0 is reserved
 * for /dev/bpf0 MACRAW), so at most three WIRE listeners can be armed at once,
 * and each live connection holds one for its lifetime.  A loopback listener
 * costs none since apple/fgx#132.  inetd therefore refuses to arm more
 * services than the machine can carry rather than letting socket() fail in the
 * middle of the config.
 *
 * WHAT IS NOT HERE, and each is a deliberate omission rather than an oversight:
 *  - dgram/udp and `wait' services.  The single-threaded model hands the
 *    SOCKET to the child and waits for it to exit; nothing in the tree wants
 *    it yet, and the accept-detach rule above does not even apply.  Parsed,
 *    named in the log, skipped.
 *  - the built-in services (echo, discard, chargen, daytime, time).  `internal'
 *    is recognised and skipped, so a stock inetd.conf does not produce a
 *    parade of "cannot exec internal".
 *  - per-service setuid.  Upstream does setgid/initgroups/setuid between fork
 *    and exec; FGX spawns with file actions and has no hook there for it, and
 *    no unprivileged user in /etc/passwd to drop to.  The user field is parsed
 *    and REQUIRED to be root, so a conf line that expects privilege dropping
 *    is refused rather than quietly run as root.
 *  - TCP wrappers, tcpmux, the RPC services and the rate limiter.
 *
 * IT DETACHES THROUGH daemon(3) as upstream does, unless -d is given, and its
 * reports go to syslogd(8) through syslog(3).  The lines it prints on
 * standard output -- a service armed, re-armed or
 * handed to a pid -- are -d's, like upstream's `if (debug) fprintf(stderr,
 * ...)', since a detached inetd's standard output is /dev/null.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fgx.h>

#define CONFIG      "/etc/inetd.conf"
/* MAXSERV against SOCKD_MAX 12, and the arithmetic matters: every ARMED
 * listener holds a descriptor for as long as inetd runs, a live session holds
 * two more (the client's connector and the server's accepted end), and the
 * other daemons of a networked boot hold about eight.  At 12 the listeners
 * alone would fill the table and nothing could be accepted. */
#define MAXSERV     4           /* 4 listeners + 2 per session, of SOCKD_MAX 12 */
#define MAXARGV     6
#define ARGBUF      96          /* argv0 + args, NUL-separated */
#define NAMELEN     32
#define PATHLEN     64
#define LINELEN     160
#define W5_USABLE   3           /* hardware sockets 1..3; 0 is /dev/bpf0 */
#define RETRY_SECS  10          /* before re-arming a service that failed */

struct servtab {
    char se_service[NAMELEN];   /* "telnet" */
    char se_proto[8];           /* "tcp" */
    char se_server[PATHLEN];    /* "/testbin/telnetd" */
    long se_addr;               /* bind address, network order */
    int  se_wire;               /* 1 = not 127/8, so it costs a hw socket */
    char se_args[ARGBUF];       /* argv0 then args, each NUL-terminated */
    int  se_nargv;              /* how many strings se_args holds */
    int  se_port;               /* host order */
    int  se_fd;                 /* listening fd, or -1 when down */
    int  se_down;               /* 1 = re-arm pending */
    long se_nextry;             /* ticks() before which not to retry */
    int  se_logged;             /* this outage has already been reported */
};

/* DATA-SEGMENT, not stack.  The socket wrappers pass a buffer as a bare 16-bit
 * offset and let the bank default to DBR, so a bank-0 stack local resolves in
 * the wrong bank -- the wart loopprobe's header documents.  Everything a
 * syscall sees is therefore file scope. */
static struct servtab g_serv[MAXSERV];
static int    g_nserv;
static struct sockaddr_in g_sin;
static char   g_line[LINELEN];
static char   g_fa[64];
static char    *g_argv[MAXARGV + 1];
static int    g_debug;

extern int errno;

/* ---- tiny field splitter.  Upstream's skip()/sskip() walk a char** across the
 * line in place; the same idea, minus the malloc'd string table. ---- */
static char *
nextfield(pp)
char **pp;
{
    char *p, *start;

    p = *pp;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p == '\0' || *p == '\n' || *p == '#')
        return (char *)0;
    start = p;
    while (*p && *p != ' ' && *p != '\t' && *p != '\n')
        p++;
    if (*p)
        *p++ = '\0';
    *pp = p;
    return start;
}

static void
copyfield(dst, src, max)
char *dst, *src;
int max;
{
    int i;

    for (i = 0; i < max - 1 && src[i]; i++)
        dst[i] = src[i];
    dst[i] = '\0';
}

/* ---- arm one service: socket, bind, listen.  Returns 0 on success.
 *
 * Called at startup AND after every accept, because accept detaches the
 * listener (see the header).  Failure is not fatal: the service is marked down
 * and retried, which is upstream's own RETRYTIME behaviour for a bind that
 * loses a race with a lingering socket. ---- */
/* ONCE PER OUTAGE, not once per attempt.  A service that cannot arm at all --
 * a wire listener on a machine with no Ethernet card is the ordinary case --
 * is retried for as long as inetd runs, and reporting each attempt turns a
 * standing condition into a repeating error.  The flag clears on success, so a
 * service that goes down again says so again. */
static void
armfail(sep, what)
struct servtab *sep;
char *what;
{
    if (sep->se_logged)
        return;
    sep->se_logged = 1;
    syslog(LOG_ERR, "%s/%s: %s: %m\n", sep->se_service, sep->se_proto, what);
}

static int
arm(sep)
struct servtab *sep;
{
    int i, on;

    sep->se_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (sep->se_fd < 0) {
        armfail(sep, "socket");
        sep->se_down = 1;
        return -1;
    }

    on = 1;
    if (setsockopt(sep->se_fd, SOL_SOCKET, SO_REUSEADDR,
                   (char *)&on, sizeof(on)) < 0)
        syslog(LOG_ERR, "setsockopt (SO_REUSEADDR): %m\n");   /* advisory */

    for (i = 0; i < sizeof(g_sin); i++)
        ((char *)&g_sin)[i] = 0;
    g_sin.sin_family = AF_INET;
    g_sin.sin_port   = htons(sep->se_port);
    /* Whatever the config asked for.  0.0.0.0 means every local address, as
     * upstream's does: listen() puts it on the W5100 when a card can take it,
     * and a loopback connect still finds it there (_Loop_FindListener matches
     * the state and the port, not the transport); with no card it becomes a
     * loopback listener instead (apple/fgx#128).  127/8 is claimed for the
     * rings at bind and never reaches the card. */
    g_sin.sin_addr.s_addr = sep->se_addr;

    if (bind(sep->se_fd, &g_sin, sizeof(g_sin)) < 0) {
        armfail(sep, "bind");
        close(sep->se_fd);
        sep->se_fd = -1;
        sep->se_down = 1;
        return -1;
    }
    if (listen(sep->se_fd, 1) < 0) {
        armfail(sep, "listen");
        close(sep->se_fd);
        sep->se_fd = -1;
        sep->se_down = 1;
        return -1;
    }
    sep->se_down   = 0;
    sep->se_logged = 0;         /* a later outage is news again */
    return 0;
}

/* ---- hand the connection to the server.
 *
 * Upstream forks, dup2's the connection onto 0/1/2 in the child, closes the
 * rest, drops privilege and execs.  FGX's spawn is fused, so the same sequence
 * is expressed as file actions -- which run in the CHILD's fd table only, so
 * the parent's listener and its other services are untouched.
 *
 * THE CHILD MUST CLOSE THE LISTENER TOO, and "accept already detached it" is
 * only half true.  On the W5100 path the hardware socket really does move to
 * the accepted connection.  On LOOPBACK it does not: _Loop_AcceptTry consumes
 * SLF_PENDING and hands back the peer, but leaves the descriptor InUse, still
 * TCP_LISTEN and still bound -- its own comment says "the listener is free
 * again (one caller at a time)".
 *
 * So the listener is a live descriptor the child inherits.  Without this close
 * the parent's close on re-arm is NOT the last reference (Fs_Close tears a
 * socket down only on the last one), the old listener outlives the session, and
 * the re-arm adds a SECOND TCP_LISTEN on the same port -- _Loop_BindTry has no
 * EADDRINUSE check.  _Loop_FindListener returns the FIRST match, the stale one
 * nobody selects on, so a second client is told "Connected" and then never
 * accepted: it hangs until the first session ends.  That is the silent-hang
 * shape apple/fgx#140 exists to remove, reintroduced one layer up.
 *
 * Closing it here makes the parent's close the last reference, and it is what
 * upstream does anyway -- an inetd child gets the connection and nothing
 * else. ---- */
static int
handoff(sep, c)
struct servtab *sep;
int c;
{
    int k, off;

    k = 0;
    g_fa[k++] = 3; g_fa[k++] = 0; g_fa[k++] = c;  g_fa[k++] = 0;  /* dup2 c->0 */
    g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 3; g_fa[k++] = 1; g_fa[k++] = c;  g_fa[k++] = 0;  /* dup2 c->1 */
    g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 3; g_fa[k++] = 2; g_fa[k++] = c;  g_fa[k++] = 0;  /* dup2 c->2 */
    g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 2; g_fa[k++] = c; g_fa[k++] = 0;  g_fa[k++] = 0;  /* close c */
    g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 2; g_fa[k++] = sep->se_fd;                        /* close the */
    g_fa[k++] = 0; g_fa[k++] = 0;                                 /*  listener */
    g_fa[k++] = 0; g_fa[k++] = 0;
    g_fa[k++] = 0;                                                /* END */

    /* argv points INTO se_args: far pointers, which spawnx hands the kernel
     * as they are. */
    off = 0;
    for (k = 0; k < sep->se_nargv && k < MAXARGV; k++) {
        g_argv[k] = &sep->se_args[off];
        while (sep->se_args[off])
            off++;
        off++;                          /* past the NUL */
    }
    g_argv[k] = (char *)0;
    return spawnx(sep->se_server, g_argv, g_fa);
}

/* ---- read /etc/inetd.conf.  BSD syntax, unchanged:
 *
 *     service socktype protocol wait|nowait user server [argv0 ...]
 *
 * Everything this build cannot honour is NAMED in the log and skipped, rather
 * than being silently dropped or half-run.  A config that is entirely skipped
 * is reported as such by the caller -- an inetd sitting in select() with no
 * listeners looks identical to a working one otherwise. ---- */
static int
readconf()
{
    FILE *fp;
    char *p, *f_service, *f_socktype, *f_proto, *f_wait, *f_user, *f_server;
    char *f_arg, *host, *colon;
    int off;
    struct servent *sv;
    struct servtab *sep;
    int n, wire;

    fp = fopen(CONFIG, "r");
    if (fp == (FILE *)0) {
        syslog(LOG_ERR, "%s: %m\n", CONFIG);
        return -1;
    }

    n = 0;
    wire = 0;
    while (fgets(g_line, sizeof(g_line), fp) != (char *)0) {
        p = g_line;
        f_service = nextfield(&p);
        if (f_service == (char *)0)
            continue;                       /* blank or comment */
        f_socktype = nextfield(&p);
        f_proto    = nextfield(&p);
        f_wait     = nextfield(&p);
        f_user     = nextfield(&p);
        f_server   = nextfield(&p);
        if (f_server == (char *)0) {
            syslog(LOG_ERR, "%s: short line for %s\n", CONFIG, f_service);
            continue;
        }
        /* argv0 and any further arguments.  Collected after the checks below
         * so a skipped line costs nothing. */

        if (strcmp(f_socktype, "stream") != 0 || strcmp(f_proto, "tcp") != 0) {
            syslog(LOG_ERR, "%s: %s/%s not supported, skipped\n",
                   CONFIG, f_socktype, f_proto);
            continue;
        }
        if (strcmp(f_wait, "nowait") != 0) {
            syslog(LOG_ERR, "%s: %s: only nowait is supported, skipped\n",
                   CONFIG, f_service);
            continue;
        }
        if (strcmp(f_user, "root") != 0) {
            /* REFUSED, not run as root anyway: a line asking for an
             * unprivileged user is asking for something this build cannot do,
             * and running it privileged would be the opposite of what it
             * says. */
            syslog(LOG_ERR, "%s: %s: user %s: no privilege dropping, skipped\n",
                   CONFIG, f_service, f_user);
            continue;
        }
        if (strcmp(f_server, "internal") == 0) {
            syslog(LOG_ERR, "%s: %s: built-in services not provided, skipped\n",
                   CONFIG, f_service);
            continue;
        }
        if (n >= MAXSERV) {
            syslog(LOG_ERR, "%s: more than %d services, %s skipped\n",
                   CONFIG, MAXSERV, f_service);
            continue;
        }
        /* (the hardware ceiling is charged below, once the bind address is
         * parsed and we know whether this listener is on the wire) */

        sep = &g_serv[n];

        /* [host:]service.  Upstream 2.11BSD has no host part -- it binds
         * INADDR_ANY always -- and the shipped file uses none.  A host serves
         * one address only: 127.0.0.1 keeps a service off the LAN.  The
         * `host:service' form is the one later inetds settled on, so it is the
         * least surprising place to put it.
         *
         * No host means INADDR_ANY, which is upstream's behaviour and the one
         * that answers the LAN. */
        host = f_service;
        colon = strchr(f_service, ':');
        if (colon != (char *)0) {
            *colon = '\0';
            f_service = colon + 1;
        } else {
            host = (char *)0;
        }
        if (host == (char *)0 || strcmp(host, "*") == 0)
            sep->se_addr = 0;                   /* INADDR_ANY */
        else {
            sep->se_addr = inet_addr(host);
            if (sep->se_addr == -1) {
                syslog(LOG_ERR, "%s: %s: bad bind address, skipped\n",
                       CONFIG, host);
                continue;
            }
        }
        /* A 127/8 listener rides the loopback rings and costs no hardware
         * socket; anything else is on the wire and holds one of the three. */
        sep->se_wire = (ntohl(sep->se_addr) >> 24) != 127;

        copyfield(sep->se_service, f_service, NAMELEN);
        copyfield(sep->se_proto,   f_proto,   8);
        copyfield(sep->se_server,  f_server,  PATHLEN);

        /* argv: the configured argv0 and the arguments after it.  With none
         * given, upstream runs the server with its own path as argv[0]. */
        off = 0;
        sep->se_nargv = 0;
        while (sep->se_nargv < MAXARGV &&
               (f_arg = nextfield(&p)) != (char *)0) {
            if (off + (int)strlen(f_arg) + 1 >= ARGBUF) {
                syslog(LOG_ERR, "%s: %s: argument list too long, truncated\n",
                       CONFIG, f_service);
                break;
            }
            strcpy(&sep->se_args[off], f_arg);
            off += strlen(f_arg) + 1;
            sep->se_nargv++;
        }
        if (sep->se_nargv == 0) {
            copyfield(sep->se_args, f_server, ARGBUF);
            sep->se_nargv = 1;
        }

        sv = getservbyname(sep->se_service, sep->se_proto);
        if (sv != (struct servent *)0)
            sep->se_port = ntohs(sv->s_port);
        else
            sep->se_port = atoi(sep->se_service);   /* numeric service name */
        if (sep->se_port <= 0) {
            syslog(LOG_ERR, "%s: %s/%s: unknown service, skipped\n",
                   CONFIG, sep->se_service, sep->se_proto);
            continue;
        }

        /* CHARGE THE HARDWARE CEILING, and count only what actually costs one.
         * Refused here rather than left to fail at socket() partway through the
         * config: _W5_SockAlloc hands out 1..3 (0 is /dev/bpf0), and each armed
         * WIRE listener holds one for as long as inetd runs.  This used to be a
         * counter that was compared and never incremented -- a guard that
         * cannot fire reads as protection. */
        if (sep->se_wire) {
            if (wire >= W5_USABLE - 1) {
                syslog(LOG_ERR, "%s: %s: no hardware socket left, skipped\n",
                       CONFIG, sep->se_service);
                continue;
            }
            wire++;
        }

        sep->se_fd     = -1;
        sep->se_down   = 1;
        sep->se_nextry = 0;
        sep->se_logged = 0;
        n++;
    }
    fclose(fp);
    g_nserv = n;
    return 0;
}

main(argc, argv)
int argc;
char **argv;
{
    int i, c, nfds, maxfd, pid;
    int rfds[2];
    struct servtab *sep;

    openlog("inetd", LOG_PID, LOG_DAEMON);

    for (i = 1; i < argc; i++)
        if (strcmp(argv[i], "-d") == 0)
            g_debug = 1;
    if (g_debug == 0)
        daemon(0, 0);

    if (readconf() < 0)
        exit(1);
    if (g_nserv == 0) {
        /* SAY SO.  An inetd with no listeners blocks in select() forever and
         * is indistinguishable from a working one; every skip above logged its
         * reason, and this is the summary that makes the silence legible. */
        syslog(LOG_ERR, "no usable services in %s\n", CONFIG);
        exit(1);
    }

    for (i = 0; i < g_nserv; i++)
        if (arm(&g_serv[i]) == 0 && g_debug)
            printf("inetd: armed %s/%s:%d\n", g_serv[i].se_service,
                   g_serv[i].se_proto, g_serv[i].se_port);

    for (;;) {
        /* Reap whatever finished.  A `nowait' service is not waited for, so
         * without this the table fills with zombies and NPROC is 12. */
        while ((pid = waitpid(-1, (int *)0, WNOHANG)) > 0)
            if (g_debug)
                printf("inetd: reaped %d\n", pid);

        rfds[0] = 0;
        rfds[1] = 0;
        maxfd = 0;
        nfds = 0;
        for (i = 0; i < g_nserv; i++) {
            sep = &g_serv[i];
            if (sep->se_down) {
                /* BACKED OFF, not retried every pass.  A service that cannot
                 * arm at all -- a wire listener on a machine with no card, say
                 * -- otherwise re-attempts on every select wake for as long as
                 * ANOTHER service keeps the loop turning, and each failure
                 * syslogs.  Measured: one card-less `*:telnet' line repainted
                 * the console between every other line of output.
                 *
                 * The whole-config sleep below only covers the case where
                 * NOTHING is armed, which is exactly when it does not
                 * happen. */
                if (ticks() < sep->se_nextry)
                    continue;
                if (arm(sep) < 0) {
                    sep->se_nextry = ticks() + (long)RETRY_SECS * 60;
                    continue;
                }
                if (g_debug)
                    printf("inetd: %s re-armed\n", sep->se_service);
            }
            if (sep->se_fd < 0)
                continue;
            rfds[sep->se_fd >> 4] |= 1 << (sep->se_fd & 15);
            if (sep->se_fd > maxfd)
                maxfd = sep->se_fd;
            nfds++;
        }
        if (nfds == 0) {
            /* Everything is down.  Sleep rather than spin: the retry above
             * runs once per pass and a tight loop here would starve the
             * machine at kernel priority for as long as the fault lasts. */
            sleep(RETRY_SECS);
            continue;
        }

        if (select(maxfd + 1, rfds, (void *)0, (void *)0,
                   (struct timeval *)0) <= 0) {
            if (errno == EINTR)
                continue;               /* a child exited under us */
            syslog(LOG_ERR, "select: %m\n");
            sleep(1);
            continue;
        }

        for (i = 0; i < g_nserv; i++) {
            sep = &g_serv[i];
            if (sep->se_fd < 0)
                continue;
            if ((rfds[sep->se_fd >> 4] & (1 << (sep->se_fd & 15))) == 0)
                continue;

            c = accept(sep->se_fd, (struct sockaddr *)0, (int *)0);
            if (c < 0) {
                /* RE-ARM, DO NOT JUST COMPLAIN.  select said this listener was
                 * ready; if accept disagrees, the descriptor is not usable and
                 * leaving it in the set means waking on it again immediately.
                 * Measured over the wire before the kernel half of this was
                 * fixed: a spent listener reported readable forever, and this
                 * arm spun at full speed filling the console with
                 * "accept: Socket is not connected" while the service was deaf
                 * to every real connection.
                 *
                 * The kernel no longer lies about a spent listener
                 * (_Net_Xport_SockStatus), so this is the belt to that braces:
                 * whatever the reason accept refused, a rebuild is the only
                 * thing that can help and a retry on the same descriptor
                 * cannot. */
                syslog(LOG_ERR, "%s: accept: %m\n", sep->se_service);
                close(sep->se_fd);
                sep->se_fd     = -1;
                sep->se_down   = 1;
                sep->se_nextry = ticks() + (long)RETRY_SECS * 60;
                continue;
            }

            pid = handoff(sep, c);
            if (pid < 0)
                syslog(LOG_ERR, "%s: %s: %m\n",
                       sep->se_service, sep->se_server);
            else if (g_debug)
                printf("inetd: %s: pid %d\n", sep->se_service, pid);

            /* The parent's copy goes away either way: the child holds the
             * connection now, and on a failed spawn nobody does. */
            close(c);

            /* RE-ARM.  accept() detached the listener -- it owns no hardware
             * socket now -- so this descriptor is spent.  Upstream keeps its
             * listener and loops; here the loop has to rebuild it, or the
             * service answers exactly one client and then goes quiet. */
            close(sep->se_fd);
            sep->se_fd = -1;
            sep->se_down = 1;
        }
    }
}
