#!/bin/bash

# file		target_kgdb_setup.bash
# author	Piotr Gregor
# purpose	Setup kgdb for remote debugging on target machine PHY1.
# details		TARGET script.
#               Set kgdb to use kgdboc via specified serial port.
#				This script MUST be run AS root (sudo is not enough).
# date		5/12/2016 12:59


usage () {
	if [ $1 != 1 ]; then
		echo "Please specify serial port [ttyS*]"
		echo "Usage:"
		echo "	./`basename "$0"` <ttyX>."
		echo "		ttyX serial port to use (in the form ttyS[*])"
		exit 1
	fi;
}
usage $#
tty=$1
if [[ $tty == /* ]]; then
	echo "Please give serial port identifier in ttyS[*] format"
	exit 1
fi
echo "echo $tty,115200 > /sys/module/kgdboc/parameters/kgdboc"
echo $tty,115200 > /sys/module/kgdboc/parameters/kgdboc
if [ $? -ne 0 ]; then
	echo "Are you running this script with root privileges?"
	exit 1;
fi;
echo "Call [echo g > /proc/sysrq-trigger] to trap kernel and pass control to kgdb"
