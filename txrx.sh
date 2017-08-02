#!/bin/sh

# Author:	Piotr Gregor
# Brief:	Run RAM loading
# Date:		20.07.2017
#
# This script allows for installation of txrx and/or running of the RAM loading procedure
# Use txrx --install to compile & install txrx program in the system
# Use txrx --run to perform RAM loading
# Use txrx --uninstall to clean build & uninstall txrx program from the system
# Use -l parameter to direct output of the script to the file/stream. Absolute
# (full) path to the log file is needed.
#
# Examples:
#
#   txrx --run
#       Run RAM loading and ignore the output of the script (will print to bin: /dev/null).
#
#   txrx --run -l new.log
#       Run RAM loading and log the output of the script to the new.log file.
#
#   txrx --run -l /dev/stdout
#       Run RAM loading and log the output of the script to the standard output (usually screen).
#


RAMLOADDIR=$RTEXEC/linkage/ramload
logfile=/dev/null

usage () {
	echo "Usage:\n\t`basename "$0"` [--install] [--uninstall] [--run] [-l logfile]"
	echo "\n"
	echo "\t\tPlease pass long options first,"
    echo "\t\tshort options at the end (-l)."
	echo "\n"
	echo "\t\t--install     : compile (if necessary)"
    echo "\t\t                and install in the system"
    echo "\t\t--uninstall   : make clean build and uninstall"
    echo "\t\t                from the system"
    echo "\t\t--run         : run RAM loading procedure"
    echo "\t\t-l            : log file name where output"
    echo "\t\t                of the script is saved:"
    echo "\t\t                absolute (full) path is needed."
    echo "\n\tExamples:"
    echo ""
    echo "\t\ttxrx --run"
    echo "\t\t\tRun RAM loading and ignore the output of the script"
    echo "\t\t\t(will print to bin: /dev/null)."
    echo ""
    echo "\t\ttxrx --run -l \$(pwd)/new.log"
    echo "\t\t\tRun RAM loading and log the output of the script"
    echo "\t\t\tto the new.log file in current working directory."
    echo ""
    echo "\t\ttxrx --run -l /dev/stdout"
    echo "\t\t\tRun RAM loading and log the output of the script"
    echo "\t\t\tto the standard output (usually screen)."
    echo ""
	exit 1
}

me=`basename "$0"`

install_txrx ()
{
	cd "$RTEXEC"/txrx/src
    echo "\t"$me": Logfile is $logfile"
	make 1>$1 2>&1
	make install 1>$1 2>&1	# root privileges are needed during this command execution to copy binary to /usr/bin
	cd - 1>2 2>/dev/null
}

uninstall_txrx ()
{
	cd "$RTEXEC"/txrx/src
    echo "\t"$me": Logfile is $logfile"
	make clean 1>$1 2>&1
	make uninstall 1>$1 2>&1   # root privileges are needed during this command execution to delete binary from /usr/bin
	cd - 1>2 2>/dev/null
}

run_txrx ()
{
    echo "\t"$me": RAM load directory is "$RAMLOADDIR""
    echo "\t"$me": Logfile is $logfile"
	cd $RAMLOADDIR
	txrx --test5 --irq_enable --irq_print --pcie215 1>$1 2>&1
	cd - 1>2 2>/dev/null
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

opts="$@"
for arg in "$@"; do
	#shift
	case "$arg" in
		"--i"|"--in"|"--ins"|"--inst"|"--insta"|"--instal"|"--install")
			install="true"
            shift
			;;
		"--u"|"--un"|"--uni"|"--unin"|"--unins"|"--uninst"|"--uninsta"|"--uninstal"|"--uninstall")
			uninstall="true"
            shift
			;;
		"--r"|"--ru"|"--run")
			run="true"
            shift
			;;
		(*)
			#echo "\t"$me": Unknown option" >&2
			#usage
			#exit 1
			;;
	esac
done

while getopts ":l:" opt "$@"; do
	case $opt in
	l)
		logfile=$OPTARG
		;;
	\?)
		;;
	:)
		echo "\t"$me": ERR, Option: -$OPTARG requires argument." >&2
		;;
	esac
done

if [ "$uninstall" = "true" ]; then
	echo "\t"$me": Uninstalling txrx..."
	uninstall_txrx $logfile
fi

if [ "$install" = "true" ]; then
	echo "\t"$me": Installing txrx..."
	install_txrx $logfile
fi

if [ "$run" = "true" ]; then
	echo "\t"$me": Running txrx..."
	run_txrx $logfile
fi
