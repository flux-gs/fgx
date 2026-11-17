# netdumptap.json's workload: netdump over the kernel stack's tap, watching the
# probe's ARP and echo to the gateway, both directions.  The network modules
# load here, not at boot, and dhclient's lease gives the probe its gateway
# while netdump is watching.  The screen shows one of each kind of line, if
# netdump printed it.
modload bsdnetd bsdnet0 bsdnet1 bsdnet2 bsdnet3 >/dev/null 2>&1
modload bpf >/dev/null 2>&1
netdump 30 >/tmp/nd 2>&1 &
sleep 2
dhclient >/dev/null 2>&1
wait
for w in listening who-has is-at 'echo req' 'echo rep'
do
	grep "$w" /tmp/nd | head -1
done
