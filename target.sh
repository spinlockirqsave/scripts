#!/bin/sh


# file		target.sh
# author	Piotr Gregor
# purpose	Get symbol addresses of module's sections.
# details       TARGET side script.
#               Script gets addresses of executable kernel module sections
#               as loaded into kernel and creates add-symbol-file command
#               for gdb kernel debugging on HOST side (this command tells
#               gdb where to map kernel module into the kernel).
#               Script opens ssh connection and transfers result command
#               as text in file to debugging HOST.
# date		07/12/2016 11:29


# fail the whole script on first error
#set -e

# param 1 - > Number of step
# param 2 - > Step description
report_step () {
        echo "\n---->\tRunning step $1 : [$2]"
}

# exit if invalid number of arguments passed to script
usage () {
	# compare the value passed to this function with expected number of args
	if [ $1 -lt 2 -o -z $hostip ]; then
		echo "Usage:\n\t./`basename "$0"` <-i IP> [-m module] [-p path] [-f file]."
		echo "\t\t-i host IP where to send the result (mandatory)"
		echo "\t\t-m kernel module name (optional: pcihsd is default)"
		echo "\t\t-p absolute path to kernel module (optional, no slash at the end, /home/qsl/Installer/pcihsd)"
		echo "\t\t-f absolute path on host where to save the result command (optional, /home/qsl/dbg.ksyms)"
		exit 1
	fi
}

hostip=
module=
path=
result_file="/home/qsl/dbg.ksyms"
while getopts "i:m:p:f:" opt; do
	case $opt in
	i)
		hostip=$OPTARG
		echo "hostip [$hostip]" ;;
	m)
		module=$OPTARG
		echo "kernel module [$module]" ;;
	p)
		path=$OPTARG
		echo "path to kernel module [$path]" ;;
	f)
		result_file=$OPTARG
		echo "file (host) [$result_file]" ;;
	\?)
		echo "Invalid option: -$OPTARG." >&2
		usage $#
		exit 1 ;;
	:)
		echo "Option: -$OPTARG requires argument." >&2
		usage $#
		exit 1 ;;
	esac
done
# call usage with the number of arguments passed to this script
usage $#
if [ -z "$module" ]; then # if $module is of 0 length (doesn't matter if it is uninitialized or set to zero length string)
    module="pcihsd"
    echo "kernel module [$module] (default)"
fi
if [ -z "$path" ]; then # if $path is of 0 length (doesn't matter if it is uninitialized or set to zero length string)
    path="/home/qsl/Installer/pcihsd"
    echo "absolute path to kernel module [$path] (default)"
fi

# unmount if mounted
report_step "1" "Getting symbols from [$module/sections] at [/sys/module]"
if [ ! -d /sys/module/$module/sections ]; then
	echo "[$module/sections] directory doesn't exist, exiting"
	exit 1
fi
entries=`ls -a /sys/module/$module/sections`

textaddr=`cat /sys/module/$module/sections/.text`
cmd="add-symbol-file $path/$module.ko $textaddr"
for entry in $entries; do
    if [ "$entry" != "." -a "$entry" != ".." -a "$entry" != ".text" ]; then
        cmd="$cmd -s $entry `cat /sys/module/$module/sections/$entry`"
    fi
done


report_step "2" "Result command"
echo [$cmd]

report_step "3" "Opening ssh connection to [$hostip], saving result in [$result_file]"
ssh -v qsl@$hostip "echo $cmd > $result_file"
