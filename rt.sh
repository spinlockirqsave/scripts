#!/bin/sh

# file		rt.sh
# author	Piotr Gregor
# purpose	Install linux kernel version with real time preemption.
# details	Script can be used also for downloading of kernel sources (and patch) only,
#			or for creating and/or editing of kernel configuration file.
#			Script performs following steps:
#			1.	Step 1 “Preconditions”:
#				Script creates the hashtable of kernel/patch entries in temporary folder and checks the Operating System (Ubuntu/Debian).
#			2.	Script asks user to choose kernel version to download.
#			3.	Downloading and unpacking of kernel and corresponding RT patch.
#			4.	Patching the kernel.
#			5.	Installing the dependencies needed to create menuconfig.
#			6.	Building config. Optionally build oldconfig -> this creates .config reflecting current settings and asking user to configure only new features. Build menuconfig -> this allows to customize .config (optionally created via oldconfig). Scripts allows to review of .config and edit .config manually in vim.
#			7.	Script checks if CONFIG_PREEMPT_RT_FULL option has been turned on in .config and if not then script asks if to continue.
#			8.	Script checks the number of cores on the machine, so it can pass correct value to make –j flag
#			9.	Make (compile core kernel, vmlinuz and compressed bzImage in arch folder (e.g. arch/x86/boot/bzImage))
#			10.	Make modules (compile modules, compiles individual files for each question you answered M during kernel config. The object code is linked against your freshly built kernel. (For questions answered Y, these are already part of vmlinuz, and for questions answered N they are skipped))
#			11. Make modules_install (copy modules to /lib/modules)
#			12.	Make install (installation, sources arch/$ARCH/boot/install.sh, copy vmlinuz to /boot, build initial root ram disk file system initramfs, build grub configuration file)
#			13.	Update-grub (update grub menu)
#			14. Reboot?
# date		4/11/2016 13:19

# first, some utility functions
fail () {
	exit $1
}

# param 1 - > Number of step
# param 2 - > Step description
report_step () {
	echo "\n---->\nRunning step $1\n$2"
	echo "---->\n"
}

# allows user interaction to stop or continue
user_continue () {
    ans=
    # While nothing entered
    while [ "$ans" = "" ]
    do
        read -p "Continue (y/n)?" ans # Prompt user for input
    done
    # If answer is y
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ] || [ "$ans" = "yes" ]; then
        return 0 # Return a valid return code (0)
    else
        exit 1 # exit signaling user termination
    fi;
}

# allows user interaction to stop or continue
# param 1 -> Question
# param 2 -> command to execute if answer is yes
# param 3 -> command to execute if answer is no
user_ask_exec () {
    ans=
    # While nothing entered
    while [ "$ans" = "" ]
    do
        # Prompt user for input
        read -p "$1 (y/n)?" ans
    done
    # If answer is y
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ] || [ "$ans" = "yes" ]; then
        # execute "yes" action
        eval $2
    else
        # execute "no" action
        eval $3
    fi;
}

# get kernel major version from the user
user_get_kernel_major_version () {
    # While nothing entered
    ans=
    while [ "$ans" = "" ]
    do
        # Prompt user for input
		read -p "Which kernel version would you like to install? (please type in format x.y)" ans
    done
	echo $ans
}

# wrapper over the dictionary
# put() and get() methods written below
# allow for insertion and deletion of entries
# into/from the hashtable
# Hashtable is implemented as a directory structure
# in folder map.XXX created in /tmp with entries represented
# by files, where entry's keys (kernel major version,
# kernel/patch) are directories and entry's value is written
# as file's content under last dir, e.g:

#/tmp
#	|
#	|
#	-map.l03
#		|
#		- 3.0
#		|	|
#		|	|-kernel
#		|	|        linux-3.0.101                
#		|	|-patch
#		|	        patch-3.0.101-rt130
#		- 3.2
#		|   |
#		|   |-kernel
#		|   |     linux-3.2.83
#		|   |-patch
#		|        patch-3.2.83-rt121
#
mapdir=$(mktemp -dt map.XXX)

put() {
	[ "$#" != 3 ] && exit 1
	mapname=$1; key=$2; value=$3;
	[ -d "$mapdir/$mapname" ] || mkdir "$mapdir/$mapname"
	echo $value > "$mapdir/$mapname/$key"
}

get() {
	[ "$#" != 2 ] && exit 1
	mapname=$1; key=$2;
	cat "${mapdir}/${mapname}/${key}"
}

report_step 1 "Information/Preconditions.\nThis scripts can be used for download of kernel sources\nand corresponding RT patch. It will ask if you want to continue\nafter all major steps so it can be used\nalso for downloading of kernel sources without compilation/install. "
report_step 1.1 "Prepairing to install..."
put "3.0" "kernel" "linux-3.0.101"
put "3.0" "kernel_folder" "v3.0"
put "3.0" "patch" "patch-3.0.101-rt130.patch"
put "3.2" "kernel" "linux-3.2.83"
put "3.2" "kernel_folder" "v3.x"
put "3.2" "patch" "patch-3.2.83-rt121.patch"
put "3.4" "kernel" "linux-3.4.113"
put "3.4" "kernel_folder" "v3.x"
put "3.4" "patch" "patch-3.4.113-rt145.patch"
put "3.6" "kernel" "linux-3.6.11"
put "3.6" "kernel_folder" "v3.x"
put "3.6" "patch" "patch-3.6.11.9-rt42.patch"
put "3.8" "kernel" "linux-3.8.13"
put "3.8" "kernel_folder" "v3.x"
put "3.8" "patch" "patch-3.8.13.14-rt31.patch"
put "3.10" "kernel" "linux-3.10.104"
put "3.10" "kernel_folder" "v3.x"
put "3.10" "patch" "patch-3.10.104-rt117.patch"
put "3.12" "kernel" "linux-3.12.66"
put "3.12" "kernel_folder" "v3.x"
put "3.12" "patch" "patch-3.12.66-rt89.patch"
put "3.14" "kernel" "linux-3.14.79"
put "3.14" "kernel_folder" "v3.x"
put "3.14" "patch" "patch-3.14.79-rt85.patch"
put "3.18" "kernel" "linux-3.18.44"
put "3.18" "kernel_folder" "v3.x"
put "3.18" "patch" "patch-3.18.44-rt48.patch"
put "4.0" "kernel" "linux-4.0.8"
put "4.0" "kernel_folder" "v4.x"
put "4.0" "patch" "patch-4.0.8-rt6.patch"
put "4.1" "kernel" "linux-4.1.35"
put "4.1" "kernel_folder" "v4.x"
put "4.1" "patch" "patch-4.1.35-rt41.patch"
# changed from 4.4.32 to 4.4.38
# changed from 4.4.38 to 4.4.39
# changed from 4.4.39 to 4.4.70
put "4.4" "kernel" "linux-4.4.70"
put "4.4" "kernel_folder" "v4.x"
put "4.4" "patch" "patch-4.4.70-rt83.patch"
put "4.6" "kernel" "linux-4.6.7"
put "4.6" "kernel_folder" "v4.x"
put "4.6" "patch" "patch-4.6.7-rt14.patch"
put "4.8" "kernel" "linux-4.8.15"
put "4.8" "kernel_folder" "v4.x"
put "4.8" "patch" "patch-4.8.15-rt10.patch"
put "4.9" "kernel" "linux-4.9"
put "4.9" "kernel_folder" "v4.x"
put "4.9" "patch" "patch-4.9-rt1.patch"

report_step 1.2 "Checking the operating system version"
# source the /etc/os-release config file
. /etc/os-release
if [ "$NAME" = "Ubuntu" ]; then
	echo "Installing for Ubuntu"
elif [ "$NAME" = "Debian*" ] || [ "$NAME" = "Debian GNU/Linux" ]; then
	echo "Installing for Debian"
	NAME="Debian"
else
	# couldn't get system info, but give user option to continue
	echo "Couldn't fetch operating system's version but you can still proceed if you'd like to."
	echo "Please choose option:\nD/d - Debian installation\nU/u - Ubuntu installation\nany other key - abort\n"
    	ans=
    	# While nothing entered
    	while [ "$ans" = "" ]
    	do
        	# Prompt user for input
        	read -p "$1 ([D/d] [U/u] [*])?" ans
    	done
    	if [ "$ans" = "D" ] || [ "$ans" = "d" ]; then
        	NAME="Debian"
		echo "Installing for Debian"
    	elif [ "$ans" = "U" ] || [ "$ans" = "u" ]; then
        	NAME="Ubuntu"
		echo "Installing for Ubuntu"
    	else
		echo "Aborting..."
		exit 2
	fi;
fi;
user_ask_exec "Is this information correct?" "return 0" "exit 1"
major=
kernel=
patch=
report_step 2 "Choosing kernel/patch versions"
# setup the sources to install
echo "Supported major kernel versions:"
ls $mapdir
major=$(user_get_kernel_major_version)
#if [ "$NAME" = "Ubuntu" ]; then
#	#patch_src=patch-4.4.27-rt37.patch
#	#patch_src_gz=patch-4.4.27-rt37.patch.gz
#	#kernel_src=linux-4.4.27
#	#kernel_src_gz=linux-4.4.27.tar.gz
#	kernel=$(get "4.4" "kernel")
#	patch=$(get "4.4" "patch")
#else
#	#patch_src=patch-4.8.6-rt5.patch
#	#patch_src_gz=patch-4.8.6-rt5.patch.gz
#	#kernel_src=linux-4.8.6
#	#kernel_src_gz=linux-4.8.6.tar.gz
#	kernel=$(get "4.6" "kernel")
#	patch=$(get "4.6" "patch")
#fi;
kernel_folder=$(get "$major" "kernel_folder")
kernel=$(get "$major" "kernel")
patch=$(get "$major" "patch")
echo "We will now download\nkernel: $kernel\nrt-patch: $patch"
user_ask_exec "Is this what you want to do (yes-continue, no-abort)?" "return 0" "exit 1"

# get sources (kernel + rt patch)
report_step 3 "Downloading sources (kernel + rt patch)..."
if [ ! -d "$kernel" ]; then
	if [ ! -f "$kernel.gz" ]; then
		wget http://kernel.org/pub/linux/kernel/$kernel_folder/$kernel.tar.gz
	fi
	# unpack kernel
	report_step 3.1 "Unpacking sources (kernel)..."
	tar zxvf $kernel.tar.gz
	if [ ! -d "$kernel" ]; then
		echo "Kernel source files missing, aborting..."
		exit 1
	fi
fi
if [ ! -f "$patch" ]; then
	if [ ! -f "$patch.gz" ]; then
		if [ "$NAME" = "Ubuntu" ]; then
			wget https://www.kernel.org/pub/linux/kernel/projects/rt/$major/$patch.gz
		else
			wget https://www.kernel.org/pub/linux/kernel/projects/rt/$major/$patch.gz
		fi
	fi
	# unpack patch
	report_step 3.2 "Unpacking sources (patch)..."
	gunzip $patch.gz
	if [ ! -f "$patch" ]; then
		echo "RT patch files missing, aborting..."
		exit 1
	fi
fi

# patch the kernel
report_step 4 "Patching the kernel..."
eval $(echo cd $kernel)
user_ask_exec "Would you like to apply the patch?" "patch -p1 < ../$patch" "return 0"
#patch -p1 < ../patch-4.4.27-rt37.patch

# install the dependencies (curses, build-essential for menuconfig utility and ssl for kernel build)
report_step 5 "Installing the dependencies (curses for menuconfig utility and ssl for kernel build)..."
sudo apt-get update
sudo apt-get --yes --force-yes install libncurses5-dev libssl-dev vim build-essential

# building the kernel configuration file ".config - user must give manual input"
report_step 6 "Building the kernel configuration file \".config\"..."
if [ ! -f ".config" ]; then
	# create .config
	user_ask_exec "Would you like to run 'make oldconfig' [this will make new configuration of kernel reflecting current configuration]" "echo \"Some configuration options will now be presented allowing you\nto select the desired values.\"; echo \"In the next step, the configuration menu will be displayed allowing\nyou to change any options\"; user_continue; make oldconfig" "return 0"
fi
echo "The configuration menu will now be displayed allowing you\nto change any options."
echo "If you are building RT kernel this options are suggested"
echo "	1. Preemption model -> Fully preemptible (RT)"
echo "	2. Check stack overflows -> No"
echo "	3. Timer frequency -> 1000HZ"
user_continue
make menuconfig

report_step 6.1 ".config file confirmation"
user_ask_exec "Would you like to review the .config file?" "vim .config" "return 0"

# assert rt preemption is turned on
report_step 7 "Checking if rt preemption is turned on..."
rt_full=`grep -ri CONFIG_PREEMPT_RT_FULL .config`
rt_full_opt=`echo -n $rt_full | tail -c 1`
if [ "$rt_full_opt" != "y" ]
then
	echo "RT preemption has not been enabled, the option in kernel config is set to [$rt_full]"
	user_continue
fi

# checking the number of CPU cores on this machine
report_step 8 "Checking the number of CPU cores on this machine..."
cpus=`nproc`
cores_per_cpu=`cat /proc/cpuinfo | awk '/^cpu cores/{print $4}' | tail -1`
cores=$(($cpus*$cores_per_cpu))
echo "Found $cpus CPUs and $cores cores\n"

# compile new kernel with rt support
report_step 9 "Compiling new  $major kernel with rt support\n[vmlinuz] (make -j$cores)...\n[bzImage] (make -j$cores)..."
user_continue
make -j$cores

report_step 10 "Compiling kernel modules (make modules -j$cores)..."
user_continue
sudo make modules -j$cores

report_step 11 "Installing kernel modules\n[/lib/modules] (make modules_install -j$cores)..."
user_continue
sudo make modules_install -j$cores

report_step 12 "Installing the kernel\n[/boot/vmlinuz] (make install -j$cores)..."
user_continue
sudo make install -j$cores

# add entry in grub
report_step 13 "Updating grub (building initial root ram disk file system initramfs for $major kernel)..."
user_continue
sudo update-grub

# OK, we are done, ask whether reboot now and finish
report_step 14 "Done ($major)"
echo "OK, done.\nYou can now safely boot to rt-preempt kernel (if the building process succeeded)."
echo "You need to choose then proper kernel in grub config displayed at boot prompt."
echo "Sometimes grub doesn't show new entry, in this case please check if kernel has been compiled,\nit should be stored in /boot folder."
sync	
user_ask_exec "Reboot now?" "sudo reboot" "return 0"
