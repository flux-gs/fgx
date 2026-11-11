# netudp.json's workload: syslogd -u hearing a line over lo0, then loopprobe -u.
kill `cat /var/run/syslog.pid`
sleep 1
/sbin/syslogd -u
sleep 3
/testbin/loopprobe -s
sleep 3
/testbin/loopprobe -u
