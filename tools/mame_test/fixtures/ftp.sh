# ftp.json's workload: ftp(1) reading its commands from a file.  help lists
# the command table, status reports the defaults, and an open to a port
# nothing listens on comes back refused over loopback.
printf 'help\nstatus\nopen 127.0.0.1 21\nquit\n' >/tmp/fi
ftp -n </tmp/fi
