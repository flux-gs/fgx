# texttools2.json's workload: sort, find, xargs, diff, diffh, diff3, patch
# and pr on small inputs, each needle an output on one line.
printf '%s\n' pear apple fig >/tmp/s
sort /tmp/s | tr '\012' ' '
echo
printf '%s\n' 10 9 100 | sort -n | tr '\012' ,
echo
mkdir /tmp/fd
echo q >/tmp/fd/qzz
find /tmp/fd -name 'q*' -type f -print
printf '%s\n' xa xb | xargs echo xx
printf '%s\n' a b c >/tmp/d1
printf '%s\n' a B c >/tmp/d2
cp /tmp/d1 /tmp/d3
diff /tmp/d1 /tmp/d2 | tr '\012' :
echo
printf '%s\n' x y z >/tmp/e1
printf '%s\n' x y Q >/tmp/e2
diff -h /tmp/e1 /tmp/e2 | head -1
diff3 /tmp/d1 /tmp/d2 /tmp/d3 | head -1
diff /tmp/d1 /tmp/d2 >/tmp/dp
patch /tmp/d3 /tmp/dp >/dev/null 2>&1
tr '\012' - </tmp/d3
echo
pr -h prhdr /tmp/s | grep Page
