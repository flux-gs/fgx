#!/bin/sh
# net-mux S5 on real hardware: runs every IIgs-side step of
# docs/history/2026-11-15-net-mux-s5-hardware-run.md and keeps what it prints
# in /root/s5run.log.  On fgxroot-s5.fs it is /root/s5run.sh.
#
#   sh /root/s5run.sh <a free LAN address> <the Mac's address> [off-LAN address]
#
# The free address must be outside the DHCP server's range: step 5 configures
# it by hand.  The off-LAN address must answer ping (8.8.8.8 by default).
# Where a step needs the Mac, the script says what to type there and waits for
# Return; where only the screen can tell, it asks y/n and logs the answer.  At
# the end it sends the log to the Mac with nc.

if test $# -lt 2
then
	echo "usage: sh /root/s5run.sh <free LAN address> <Mac address> [off-LAN address]"
	exit 1
fi
FREE=$1
MAC=$2
FAR=${3-8.8.8.8}
LOG=/root/s5run.log
GW=`sed -n 2p /etc/dhcp.lease`
BCAST=`echo $FREE | sed 's/\.[0-9]*$/.255/'`

(
echo "== 0. this run"
uname -a
date
echo "free $FREE  mac $MAC  far $FAR  gateway $GW  broadcast $BCAST"

echo
echo "== 1. the boot"
/usr/fgx/bin/dmesg | sed -n -e '/w5:/p' -e '/bsdnet/p' -e '/module:/p'
echo "lease file:"
cat /etc/dhcp.lease
echo "Did the boot print 'wz0: bound to ...' (y/n)?"
read A; echo "answer: $A"

echo
echo "== 2. ifconfig"
ifconfig wz0
ifconfig lo0
echo "ifconfig u2s1 (expect: no such interface):"
ifconfig u2s1

echo
echo "== 3. route, and route -f"
echo "-- ping $FAR, routes as booted (expect replies)"
ping $FAR 3
echo "-- route -nf"
route -nf
echo "-- ping the gateway $GW (expect replies)"
ping $GW 3
echo "-- ping $FAR, no default route (expect none)"
ping $FAR 3
echo "-- route add default"
route -n add default $GW 1
echo "-- ping $FAR again (expect replies)"
ping $FAR 3

echo
echo "== 4. dhclient by hand"
dhclient
ping $FAR 3

echo
echo "== 5. a static address, from netstart's commented lines"
route -nf
ifconfig wz0 inet $FREE netmask 255.255.255.0 broadcast $BCAST
route -n add default $GW 1
ifconfig wz0
ping $FAR 3
echo "On the Mac:   ping -c 3 $FREE"
echo "then press Return here."
read A
echo "Did the Mac's ping get replies (y/n)?"
read A; echo "answer: $A"
echo "-- dhclient puts the lease back"
dhclient
ifconfig wz0
ADDR=`sed -n 1p /etc/dhcp.lease`

echo
echo "== 6. descriptor passing over AF_UNIX"
/testbin/unixprobe -r
/testbin/unixprobe -r gc

echo
echo "== 7. S4's steps"
echo "-- 7.2 telnet in from the Mac"
if ps ax | grep -v grep | grep inetd > /dev/null
then
	echo "inetd already running"
else
	/sbin/inetd < /dev/null > /dev/null 2>&1
fi
echo "On the Mac:   nc $ADDR 23   (or telnet).  Log in, log out, connect"
echo "again, log in and out again.  Then press Return here."
read A
echo "Did both connections reach a shell (y/n)?"
read A; echo "answer: $A"

echo "-- 7.3 ftp: an ftp server's address, or Return to skip"
read FTPS
if test -n "$FTPS"
then
	echo "log in, then:  binary,  get <a file of about 1 MB> /tmp/f,  quit"
	# ftp writes to the terminal, not the pipe: login() in ftp.c prints the
	# Name prompt with printf and no fflush, so through a pipe it would sit in
	# stdio's buffer, unseen, while ftp waits for the answer.
	ftp $FTPS > /dev/tty 2>&1
	echo "the line ftp printed after the get (bytes received in ... seconds)?"
	read A; echo "ftp rate: $A"
	sum /tmp/f
	echo "the host's sum of that file?"
	read A; echo "host sum: $A"
fi

echo "-- 7.4 sixteen connections at once"
echo "On the Mac:"
echo "  for i in \$(seq 16); do (sleep 60 | nc $ADDR 23 > /dev/null &); done"
echo "then press Return here within a few seconds."
read A
echo "telnetd count (expect 16 or 17):"
ps ax | grep -c telnetd
echo "waiting 75 s for them to close..."
sleep 75
echo "telnetd count after (expect 0 or 1):"
ps ax | grep -c telnetd
echo "On the Mac: telnet or nc $ADDR 23 once more.  Did it answer (y/n)?"
read A; echo "answer: $A"

echo "-- 7.5 ping both ways"
echo "On the Mac:   ping -c 5 $ADDR   then press Return here."
read A
echo "Did the Mac get replies (y/n)?"
read A; echo "answer: $A"
ping $MAC 5

echo "-- 7.6 syslog over /dev/log and UDP"
logger -p user.err from the local socket
echo "Did 'from the local socket' appear on the console (y/n)?"
read A; echo "answer: $A"
) 2>&1 | tee $LOG

# syslogd is restarted with -u outside the pipe.  Inside `( ... ) 2>&1 | tee',
# sh keeps its own output on fd 11 as a dup of fd 2, the pipe (2.11BSD sh
# xec.c TPAR: rename(dup(2), output)), and a dup2'd descriptor is not
# close-on-exec (kern_descrip.c dup2), so the daemon would inherit the pipe
# and tee would never see its end.
kill `cat /var/run/syslog.pid`
/sbin/syslogd -u < /dev/null > /dev/null 2>&1
sleep 2
echo "syslogd restarted with -u" >> $LOG
ADDR=`sed -n 1p /etc/dhcp.lease`

(
echo "On the Mac:   echo '<11>from the mac' | nc -u -w1 $ADDR 514"
echo "then press Return here."
read A
echo "Did 'from the mac' appear on the console (y/n)?"
read A; echo "answer: $A"

echo "-- 7.7 netdump"
modload bpf
netdump 20 > /tmp/nd.txt
cat /tmp/nd.txt
echo "saturated lines:"
grep -c saturated /tmp/nd.txt

echo
echo "== 8. anything else odd?  Type it on one line, or Return."
read A; echo "note: $A"
date
echo "== done"
) 2>&1 | tee -a $LOG

echo
echo "The log is $LOG.  To send it to the Mac, run there:"
echo "    nc -l 9999 > s5run.log"
echo "then press Return here (or type s and Return to skip).  When the Mac's"
echo "s5run.log stops growing, a few seconds, press Ctrl-C on the Mac: FGX's nc"
echo "waits for the Mac to close, and this prompt then returns."
read A
if test "$A" != s
then
	nc $MAC 9999 < $LOG
	echo "sent."
fi
exit 0
