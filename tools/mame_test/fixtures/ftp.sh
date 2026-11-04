# ftp.json's workload: ftp(1) reading its commands from a file.  help lists
# the command table, status reports the defaults, passive toggles
# 4.4BSD-Lite2's passive mode off (it starts on), and an open to a port nothing listens on
# comes back refused over loopback.
printf 'help\nstatus\npassive\nopen 127.0.0.1 21\nquit\n' >/tmp/fi
ftp -n </tmp/fi
