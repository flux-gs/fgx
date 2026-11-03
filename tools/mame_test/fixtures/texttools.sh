# texttools.json's workload: each 2.11BSD text tool on a small input.
printf '%s\n' alpha bravo zulu9 >/tmp/f
printf '%s-%d\n' pf 42
tail -2 /tmp/f | rev
mkdir /tmp/dud
split -2 /tmp/f /tmp/dud/p
rev /tmp/dud/pab
echo yxwtee | tee /tmp/t >/tmp/x
rev /tmp/t
printf '%s\n' ant cow >/tmp/f1
printf '%s\n' cow emu >/tmp/f2
comm -12 /tmp/f1 /tmp/f2 | rev
echo tsortaa tsortbb tsortbb tsortcc | tsort | tail -1 | rev
printf 'x\ty\n' | expand | tr ' ' _
printf '        z9\n' | unexpand | od -c
sum /tmp/f
dd if=/tmp/f bs=1 count=6 | rev
du -a /tmp/dud
tty
