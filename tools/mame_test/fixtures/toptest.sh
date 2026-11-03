# top.json's workload: a CPU-bound process under a name nothing types, given
# time to run up CPU ticks and to lift the load average off zero (the
# averages are recomputed every five seconds), then top until `q'.
cp /bin/yes /tmp/spinme
/tmp/spinme >/dev/null &
sleep 8
top -s 2
kill $!
