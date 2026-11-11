# netftp.json's workload: a passive ftp get over the chip's own TCP, with the
# kernel stack holding socket 0, then the file's size and checksum.
printf 'open %s\nuser anonymous fgx@fgx\nbinary\nget sun/top-3.5beta9.tar /tmp/netftp.tar\nquit\n' `cat /etc/netftp.host` >/tmp/fi
ftp -n </tmp/fi
wc -c /tmp/netftp.tar
sum /tmp/netftp.tar
