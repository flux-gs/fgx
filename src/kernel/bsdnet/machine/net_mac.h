/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/net_mac.h
 *   Written for FGX after usr/sys/pdp/net_mac.h, 2.11BSD.  Original work:
 *   Copyright (c) 1988 Regents of the University of California.
 *   All rights reserved.
 */
/* net_mac.h -- on the PDP-11 the network code runs in supervisor space and each
 * of these crosses to or from kernel space.  FGX has one space, so each is the
 * direct call. */
struct socket *asoqremque();
int b_to_q();
int connwhile();
memaddr malloc();
int fpfetch();
void fpflags();
int gsignal();
struct mbuf *m_free();
int m_freem();
int netcopyout();
int netcrash();
int iput();
struct proc *netpfind();
int netpsignal();
void netsethz();
int netstart();
int putc();
int selwakeup();
int sleep();
int soacc1();
int soaccept();
int sobind();
int soclose();
int soconnect();
int soconnect2();
int socreate();
int sogetnam();
int sogetopt();
int sogetpeer();
int solisten();
int soo_ioctl();
int soo_select();
int soo_stat();
int soreceive();
int sosend();
int sosetopt();
int soshutdown();
int timeout();
int ttstart();
int ttyflush();
int ttywflush();
int unpbind();
int unpconn();
int unputc();
void unpdet();
int wakeup();

#define	ASOQREMQUE(so, n)	asoqremque(so, n)
#define	B_TO_Q(cp, cc, q)	b_to_q(cp, cc, q)
#define	CONNWHILE(so)	connwhile(so)
#define	MALLOC(map, size)	malloc(map, size)
#define	FPFETCH(fp, fpp)	fpfetch(fp, fpp)
#define	FPFLAGS(fp, set, clear)	fpflags(fp, set, clear)
#define	GSIGNAL(pgrp, sig)	gsignal(pgrp, sig)
#define	M_FREE(m)	m_free(m)
#define	M_FREEM(m)	m_freem(m)
#define	NETCOPYOUT(from, to, len)	netcopyout(from, to, len)
#define	NETCRASH()	netcrash()
#define	IPUT(ip)	iput(ip)
#define	NETPFIND(pid)	netpfind(pid)
#define	NETPSIGNAL(p, sig)	netpsignal(p, sig)
#define	NETSETHZ()	netsethz()
#define	NETSTART()	netstart()
#define	PUTC(c, p)	putc(c, p)
#define	SELWAKEUP(p, coll)	selwakeup(p, coll)
#define	SELWAITING(p)		selwaiting(p)
#define	SLEEP(chan, pri)	sleep(chan, pri)
#define	SOACC1(so)	soacc1(so)
#define	SOACCEPT(so, nam)	soaccept(so, nam)
#define	SOBIND(so, nam)	sobind(so, nam)
#define	SOCLOSE(so)	soclose(so)
#define	SOCON1(so, nam)	soconnect(so, nam)
#define	SOCON2(so1, so2)	soconnect2(so1, so2)
#define	SOCREATE(dom, aso, type, proto)	socreate(dom, aso, type, proto)
#define	SOGETNAM(so, m)	sogetnam(so, m)
#define	SOGETOPT(so, level, optname, mp)	sogetopt(so, level, optname, mp)
#define	SOGETPEER(so, m)	sogetpeer(so, m)
#define	SOLISTEN(so, backlog)	solisten(so, backlog)
#define	SOO_IOCTL(fp, cmd, data)	soo_ioctl(fp, cmd, data)
#define	SOO_SELECT(fp, which)	soo_select(fp, which)
#define	SOO_STAT(so, ub)	soo_stat(so, ub)
#define	SORECEIVE(so, aname, uiop, flags, rightsp)	soreceive(so, aname, uiop, flags, rightsp)
#define	SOSEND(so, nam, uiop, flags, rights)	sosend(so, nam, uiop, flags, rights)
#define	SOSETOPT(so, level, optname, m0)	sosetopt(so, level, optname, m0)
#define	SOSHUTDOWN(so, how)	soshutdown(so, how)
#define	TIMEOUT(fun, arg, t)	timeout(fun, arg, t)
#define	TTSTART(tp)	ttstart(tp)
#define	TTYFLUSH(tp, rw)	ttyflush(tp, rw)
#define	TTYWFLUSH(tp)	ttywflush(tp)
#define	UNPBIND(path, len, ipp, unpsock)	unpbind(path, len, ipp, unpsock)
#define	UNPCONN(path, len, so2, ipp)	unpconn(path, len, so2, ipp)
#define	UNPUTC(p)	unputc(p)
#define	UNPDET(ip)	unpdet(ip)
#define	WAKEUP(chan)	wakeup(chan)
