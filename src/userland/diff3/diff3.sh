#! /bin/sh
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
#
# FGX-Provenance: 2.11BSD diff3(1)
#   Ported from diff3.sh, 2.11BSD (4.1.1 1996/10/25).  Original work: the
#   Regents of the University of California; the 2.11BSD file carries no
#   copyright notice.  FGX changes are BSD-2-Clause.
#
# vendor/2.11BSD/usr/usr.bin/diff3/diff3.sh, verbatim below this comment.
#
#	diff3.sh	4.1.1	(2.11BSD)	1996/10/25
#
e=
case $1 in
-*)
	e=$1
	shift;;
esac
if test $# = 3 -a -f $1 -a -f $2 -a -f $3
then
	:
else
	echo usage: diff3 file1 file2 file3 1>&2
	exit
fi
trap "rm -f /tmp/d3[ab]$$" 0 1 2 13 15
diff $1 $3 >/tmp/d3a$$
diff $2 $3 >/tmp/d3b$$
/usr/libexec/diff3 $e /tmp/d3[ab]$$ $1 $2 $3
