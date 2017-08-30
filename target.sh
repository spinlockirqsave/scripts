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
		echo "\t\t-p absolute path to kernel module (optional, no slash at the end, /home/peter/kernel/nonrt/linux-4.4.70)"
		echo "\t\t-d absolute path on host where to save the result file (optional, /home/peter/kernel/nonrt/linux-4.4.70)"
		echo "\t\t-f file name on host where to save the result command (under result dir) (optional, dbg.ksyms)"
		echo "\t\t-k absolute path to the vmlinux on host (to be xferred to remote) (optional, /home/p/k/n/linux-4.4.70)"
		exit 1
	fi
}

hostip=
module=
path=
result_dir="/home/peter/kernel/nonrt/linux-4.4.70"
result_file="dbg.ksyms"
kernel_obj="/home/peter/kernel/nonrt/linux-4.4.70/vmlinux"
while getopts "i:m:p:d:f:k:" opt; do
	case $opt in
	i)
		hostip=$OPTARG
		echo "SET hostip [$hostip]" ;;
	m)
		module=$OPTARG
		echo "SET kernel module [$module]" ;;
	p)
		path=$OPTARG
		echo "SET path to kernel module [$path]" ;;
	d)
		result_dir=$OPTARG
		echo "SET result dir (host) [$result_dir]" ;;
	f)
		result_file=$OPTARG
		echo "SET result file (host) [$result_file]" ;;
	k)
		kernel_obj=$OPTARG
		echo "SET kernel (host) [$kernel_obj]" ;;
	\?)
		echo "SET Invalid option: -$OPTARG." >&2
		usage $#
		exit 1 ;;
	:)
		echo "SET Option: -$OPTARG requires argument." >&2
		usage $#
		exit 1 ;;
	esac
done
# call usage with the number of arguments passed to this script
usage $#
if [ -z "$module" ]; then # if $module is of 0 length (doesn't matter if it is uninitialized or set to zero length string)
    module="pcie215"
    echo "kernel module [$module] (default)"
fi
if [ -z "$path" ]; then # if $path is of 0 length (doesn't matter if it is uninitialized or set to zero length string)
    path="/home/peter/kernel/nonrt/linux-4.4.70/drivers/staging/pcie215"
    echo "absolute path to kernel module [$path] (default)"
fi

echo "USING hostip [$hostip]"
echo "USING kernel module [$module]"
echo "USING path to kernel module [$path]"
echo "USING result dir (host) [$result_dir]"
echo "USING result file (host) [$result_file]"
echo "USING kernel (host) [$kernel_obj]"

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
ssh -v peter@$hostip "echo $cmd > $result_dir/$result_file"

report_step "4" "Transfering kernel from [$kernel_obj] to [$result_dir/vmlinux]"
scp $kernel_obj peter@"$hostip"://"$result_dir"/vmlinux
