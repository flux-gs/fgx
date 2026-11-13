/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/trap.c
 *   Written for FGX after 2.11BSD's syscall() in usr/sys/pdp/trap.c, its
 *   copies in usr/sys/sys/kern_subr.c and usr/sys/pdp/net_copy.s, and
 *   sorw/soo_* in usr/sys/sys/sys_generic.c.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* bn_sys.c -- a process's socket call, from net.mod into 2.11BSD's bodies.
 *
 * net.mod keeps the system-call entry and the descriptor: a UDP descriptor
 * carries the struct socket's offset in this bank, and every call on it comes
 * here through bn_sysent (machine/net_asm.s) with a call block naming the
 * syscall's registers.  What is written for FGX is the argument fetch, as the
 * design says: each arm turns FGX's libc argument block into the `struct a'
 * that uipc_syscalls.c's body reads through u.u_ap, and calls the body.
 *
 * The descriptor is net.mod's, so the body's getf() answers one static file
 * standing for it, and falloc/ufalloc are never reached: BNOP_SOCKET calls
 * socreate() directly, and accept and socketpair are TCP's and AF_UNIX's,
 * which stay in net.mod until S4. */
#include "param.h"
#include "user.h"
#include "proc.h"
#include "file.h"
#include "mbuf.h"
#include "socket.h"
#include "socketvar.h"
#include "protosw.h"
#include "uio.h"
#include "ioctl.h"
#include "errno.h"
#include "../netinet/in.h"

/* include/modules.s BNOP_*: the call block's c_op */
#define	BNOP_SOCKET	0
#define	BNOP_BIND	1
#define	BNOP_CONNECT	2
#define	BNOP_SENDTO	3
#define	BNOP_RECVFROM	4
#define	BNOP_SEND	5
#define	BNOP_RECV	6
#define	BNOP_SETSOCKOPT	7
#define	BNOP_GETSOCKNAME 8
#define	BNOP_GETPEERNAME 9
#define	BNOP_SHUTDOWN	10
#define	BNOP_READ	11
#define	BNOP_WRITE	12
#define	BNOP_IOCTL	13
#define	BNOP_SELECT	14
#define	BNOP_CLOSE	15
#define	BNOP_IFCHANGED	16

/* The call block net.mod builds on the caller's kernel stack. */
struct bncall {
	int	c_op;		/* BNOP_* */
	int	c_so;		/* the socket's offset in this bank; 0 for SOCKET */
	int	c_a, c_x, c_y;	/* the syscall's A, X and Y */
	int	c_bank;		/* the caller's bank: its arg block's, its address's */
	int	c_uio;		/* READ and WRITE: the kernel's struct uio, offset */
	int	c_uiobank;	/*   and bank */
	int	c_nb;		/* the descriptor's SOCK_NB (FIONBIO): SS_NBIO */
};

/* FGX's <sys/socket.h>: this call only, non-blocking.  2.11BSD has no such
 * flag; it is SS_NBIO for the call (docs/PROVENANCE.md). */
#define	MSG_DONTWAIT	0x80

extern	int kc_curuid(), kc_sigraise(), kc_wakeup(), w5address();
extern	int bind(), connect(), sendto(), send(), recvfrom(), recv();
extern	int setsockopt(), getsockname(), getpeername(), shutdown();

int	netoff;			/* uipc_syscalls.c tests it: the network is on */

/* net.mod's way in, found through bsdnetd's bn_sys cell (tools/build_bsdnet.py):
 * a far pointer, so the load patches its bank. */
extern	int bn_sysent();
int	(*bn_syscell)() = bn_sysent;
static	struct proc bn_proc;	/* u_procp: sbselqueue reads its p_wchan */
static	struct file bn_file;	/* what getf() answers */
static	struct sockaddr_in bn_to;
static	int bn_len;

/* A far pointer from a bank and an offset. */
static caddr_t
far(bank, off)
	int bank;
	unsigned off;
{
	return ((caddr_t)(((long)(bank & 0xff) << 16) | off));
}

/* The socket from its offset in this bank, the bank u is in. */
static struct socket *
sockat(off)
	unsigned off;
{
	return ((struct socket *)(((long)&u & 0xff0000L) | off));
}

struct file *
getf(fdes)
	int fdes;
{
	return (&bn_file);
}

struct file *
falloc()
{
	panic("falloc: net.mod allocates descriptors");
	return (0);
}

int
ufalloc(i)
	int i;
{
	panic("ufalloc: net.mod allocates descriptors");
	return (-1);
}

/* The process's memory is reached through far pointers, so a copy either way
 * is a copy; FGX checks no addresses here, as it checks none in a read(2). */
int
copyin(from, to, n)
	caddr_t from, to;
	u_int n;
{
	bcopy(from, to, n);
	return (0);
}

int
copyout(from, to, n)
	caddr_t from, to;
	u_int n;
{
	bcopy(from, to, n);
	return (0);
}

/* 2.11BSD pdp/net_copy.s netcopyout: at most *lenp bytes of the mbuf out to
 * the process, and *lenp becomes what went. */
int
netcopyout(m, to, lenp)
	struct mbuf *m;
	caddr_t to;
	int *lenp;
{
	if (*lenp > m->m_len)
		*lenp = m->m_len;
	return (copyout(mtod(m, caddr_t), to, (u_int)*lenp));
}

/* 2.11BSD sys/kern_subr.c uiomove, with every segment one address space. */
int
uiomove(cp, n, uio)
	caddr_t cp;
	u_int n;
	register struct uio *uio;
{
	register struct iovec *iov;
	register u_int cnt;

	while (n > 0 && uio->uio_resid) {
		iov = uio->uio_iov;
		cnt = iov->iov_len;
		if (cnt == 0) {
			uio->uio_iov++;
			uio->uio_iovcnt--;
			continue;
		}
		if (cnt > n)
			cnt = n;
		if (uio->uio_rw == UIO_READ)
			bcopy(cp, iov->iov_base, cnt);
		else
			bcopy(iov->iov_base, cp, cnt);
		iov->iov_base += cnt;
		iov->iov_len -= cnt;
		uio->uio_resid -= cnt;
		uio->uio_offset += cnt;
		cp += cnt;
		n -= cnt;
	}
	return (0);
}

/* FGX's select records no selector, so a wakeup is the channel's (the kernel's
 * _FarSh_SelWakeup says why). */
#define	WCHAN_SELECT	0xFF05		/* include/kernel.s */
void
selwakeup(p, coll)
	struct proc *p;
	long coll;
{
	kc_wakeup((caddr_t)WCHAN_SELECT);
}

/* sosend's SIGPIPE: always the calling process here. */
void
netpsignal(p, sig)
	struct proc *p;
	int sig;
{
	kc_sigraise(sig);
}

/* The bodies' argument blocks, as uipc_syscalls.c declares them. */
static	struct { int s; caddr_t name; u_int namelen; } a_bind;
static	struct { int s; caddr_t buf; int len; int flags; caddr_t to; int tolen; } a_sendto;
static	struct { int s; caddr_t buf; int len; int flags; caddr_t from; int *fromlenaddr; } a_recvfrom;
static	struct { int s; int level; int name; caddr_t val; u_int valsize; } a_sopt;
static	struct { int fdes; caddr_t asa; int *alen; } a_name;
static	struct { int s; int how; } a_shut;

#if NETPROBE == 5
/* kernel.netprobe = 5: the first socket call runs off its slot, and the floor
 * bn_sysent set must stop it (tools/mame_test/tests/netkstkovf.json). */
static int
deep(n)
	int n;
{
	char b[200];

	b[0] = n;
	return (deep(n + 1) + b[0]);
}
#endif

static void
bn_call(cp, so)
	register struct bncall *cp;
	register struct socket *so;
{
	register int *blk;
	struct uio *uio;
	struct socket *nso;
	int resid;

	switch (cp->c_op) {

	case BNOP_SOCKET:
#if NETPROBE == 5
		deep(0);
#endif
		u.u_error = socreate(cp->c_a, &nso, cp->c_x, cp->c_y);
		if (u.u_error == 0)
			u.u_r.r_val1 = (int)(long)nso;
		return;

	case BNOP_BIND:
	case BNOP_CONNECT:
		a_bind.name = far(cp->c_bank, cp->c_a);
		a_bind.namelen = sizeof(struct sockaddr_in);
		u.u_ap = (int *)&a_bind;
		if (cp->c_op == BNOP_BIND)
			bind();
		else
			connect();
		return;

	case BNOP_SENDTO:
	case BNOP_SEND:
		/* libc's block: buf, len, flags, the buffer's bank, then sendto's
		 * address and port in network order (toolchain/lib/libc_c). */
		blk = (int *)far(cp->c_bank, cp->c_a);
		a_sendto.buf = far(blk[3], blk[0]);
		a_sendto.len = blk[1];
		a_sendto.flags = blk[2] & ~MSG_DONTWAIT;
		u.u_ap = (int *)&a_sendto;
		if (cp->c_op == BNOP_SEND) {
			send();
			return;
		}
		bzero((caddr_t)&bn_to, sizeof(bn_to));
		bn_to.sin_family = AF_INET;
		bcopy((caddr_t)&blk[4], (caddr_t)&bn_to.sin_addr, 4);
		bcopy((caddr_t)&blk[6], (caddr_t)&bn_to.sin_port, 2);
		a_sendto.to = (caddr_t)&bn_to;
		a_sendto.tolen = sizeof(bn_to);
		sendto();
		return;

	case BNOP_RECVFROM:
	case BNOP_RECV:
		/* The source address goes where libc's block word 4 points, in the
		 * block's bank, all 16 bytes; libc copies what its caller asked. */
		blk = (int *)far(cp->c_bank, cp->c_a);
		a_recvfrom.buf = far(blk[3], blk[0]);
		a_recvfrom.len = blk[1];
		a_recvfrom.flags = blk[2] & ~MSG_DONTWAIT;
		u.u_ap = (int *)&a_recvfrom;
		if (cp->c_op == BNOP_RECV) {
			recv();
			return;
		}
		bn_len = sizeof(struct sockaddr_in);
		a_recvfrom.from = far(cp->c_bank, blk[4]);
		a_recvfrom.fromlenaddr = &bn_len;
		recvfrom();
		return;

	case BNOP_SETSOCKOPT:
		blk = (int *)far(cp->c_bank, cp->c_a);
		a_sopt.level = blk[0];
		a_sopt.name = blk[1];
		a_sopt.val = far(blk[4], blk[2]);
		a_sopt.valsize = blk[3];
		u.u_ap = (int *)&a_sopt;
		setsockopt();
		return;

	case BNOP_GETSOCKNAME:
	case BNOP_GETPEERNAME:
		bn_len = sizeof(struct sockaddr_in);
		a_name.asa = far(cp->c_bank, cp->c_a);
		a_name.alen = &bn_len;
		u.u_ap = (int *)&a_name;
		if (cp->c_op == BNOP_GETSOCKNAME)
			getsockname();
		else
			getpeername();
		return;

	case BNOP_SHUTDOWN:
		a_shut.how = cp->c_x;
		u.u_ap = (int *)&a_shut;
		shutdown();
		return;

	case BNOP_READ:
	case BNOP_WRITE:
		/* 2.11BSD sys_generic.c sorw */
		uio = (struct uio *)far(cp->c_uiobank, cp->c_uio);
		resid = uio->uio_resid;
		if (cp->c_op == BNOP_READ)
			u.u_error = soreceive(so, (struct mbuf **)0, uio, 0,
			    (struct mbuf **)0);
		else
			u.u_error = sosend(so, (struct mbuf *)0, uio, 0,
			    (struct mbuf *)0);
		u.u_r.r_val1 = resid - uio->uio_resid;
		return;

	case BNOP_IOCTL:
		/* Every ioctl on a kernel socket, which _IoOp_Socket sends here:
		 * soo_ioctl's arms.  FIONREAD stores an int, FGX's width for it
		 * (toolchain/include/sys/ioctl.h), where 2.11BSD's is a long.
		 * FIOASYNC and SIOCSPGRP answer ENOTTY, as the kernel answered
		 * them before: nothing here sends SIGIO or SIGURG. */
		blk = (int *)far(cp->c_bank, cp->c_y);
		switch (cp->c_x) {
		case FIONBIO:
		case SIOCATMARK:
			u.u_error = soo_ioctl(so, cp->c_x, (caddr_t)blk);
			return;
		case FIONREAD:
			*blk = so->so_rcv.sb_cc;
			return;
		case FIOASYNC:
		case SIOCSPGRP:
		case SIOCGPGRP:
			u.u_error = ENOTTY;
			return;
		}
		u.u_error = ifioctl(so, cp->c_x, (caddr_t)blk);
		return;

	case BNOP_SELECT:
		/* bit 0 readable, bit 1 writable, as NETOP_SockStatus answers;
		 * r_val2 is FIONREAD's count.  soo_select arms sb_sel. */
		u.u_r.r_val1 = (soo_select(so, FREAD) ? 1 : 0) |
		    (soo_select(so, FWRITE) ? 2 : 0);
		u.u_r.r_val2 = so->so_rcv.sb_cc;
		return;

	case BNOP_CLOSE:
		u.u_error = soclose(so);
		return;

	case BNOP_IFCHANGED:
		/* The chip has the address already: SYS_IFCONFIG is where a
		 * refusal belongs, so in_control's suser check is passed here
		 * rather than leave the stack on the old address. */
		u.u_uid = 0;
		u.u_error = w5address();
		return;
	}
	u.u_error = EINVAL;
}

/* trap.c's syscall(): a body a signal interrupts comes back through the
 * setjmp with sleep()'s EINTR in u_error.  The bodies with a setjmp of their
 * own (sendit, recvit) set u_qsave again inside. */
int
bn_sys(cp)
	register struct bncall *cp;
{
	register struct socket *so;
	register int *blk;
	int nb, nbset;

	u.u_error = 0;
	u.u_r.r_val1 = 0;
	u.u_r.r_val2 = 0;
	u.u_uid = kc_curuid();
	u.u_procp = &bn_proc;
	so = cp->c_so ? sockat(cp->c_so) : (struct socket *)0;
	bn_file.f_type = DTYPE_SOCKET;
	bn_file.f_socket = so;
	nb = cp->c_nb;
	if (cp->c_op == BNOP_SEND || cp->c_op == BNOP_SENDTO ||
	    cp->c_op == BNOP_RECV || cp->c_op == BNOP_RECVFROM) {
		blk = (int *)far(cp->c_bank, cp->c_a);
		if (blk[2] & MSG_DONTWAIT)
			nb = 1;
	}
	nbset = 0;
	if (so && nb && (so->so_state & SS_NBIO) == 0) {
		so->so_state |= SS_NBIO;
		nbset = 1;
	}
	if (setjmp(&u.u_qsave) == 0)
		bn_call(cp, so);
	if (nbset)
		so->so_state &= ~SS_NBIO;
	return (u.u_r.r_val1);
}
