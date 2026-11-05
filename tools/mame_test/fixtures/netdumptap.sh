# netdumptap.json's workload: netdump over the kernel stack's tap, watching the
# probe's ARP and echo to the gateway, both directions.  The screen shows one of
# each kind of line, if netdump printed it.
modload bsdnetd bsdnet0 bsdnet1 bsdnet2 bsdnet3 >/dev/null 2>&1
modload bpf >/dev/null 2>&1
netdump 14 >/tmp/nd 2>&1
for w in listening who-has is-at 'echo req' 'echo rep'
do
	grep "$w" /tmp/nd | head -1
done
