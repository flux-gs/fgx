# netudp.json's workload: syslogd -u hearing a line over lo0, loopprobe -u,
# then loopprobe -h against a junk nameserver on lo0.
kill `cat /var/run/syslog.pid`
sleep 1
/sbin/syslogd -u
sleep 3
/testbin/loopprobe -s
sleep 3
/testbin/loopprobe -u
echo nameserver 127.0.0.1 > /etc/resolv.conf
/testbin/loopprobe -h
