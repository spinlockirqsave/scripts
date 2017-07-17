#!/bin/sh

# file		rt.sh
# author	Piotr Gregor
# purpose	Build and optionally install selected version of linux kernel with optional real time preemption.
# details	Script can be used also for downloading of kernel sources (and patch) only,
#			or for creating and/or editing of kernel configuration file.
#			Script performs following steps:
#			1.	"Preparing to install"
#				Housekeeping: Creates hashtable of kernel/patch entries in temporary folder and checks the Operating System (Ubuntu/Debian).
#				Displays information about next steps.
#			2.	"System detection"
#				Checks the operating system version.
#			3.	"Download"
#				Downloads and unpacks the kernel and corresponding RT patch.
#				It is possible to install default kernel linux-4.4.70 and patch it using patch-4.4.70-rt83.patch - internet connection is not needed if kernel and patch (extracted or packed) are present in installation folder.
#			4.	"Patching the kernel"
#				Patches the kernel.
#			5.	"Installing dependencies"
#				Installs the dependencies needed to create menuconfig.
#			6 "Preparing the kernel configuration file \".config\"..."
#				Creates config. Options:
#				6.1	"Optional: Clean default configuration"
#					Creates clean default configuration with make defconfig.
#				6.2 "Optional: Default configuration with oldconfig"
#					Creates new configuration of kernel reflecting current configuration and asks to choose new options which have no match."
#				6.3 "Optional: Copy existing configuration"
#					Copies existing kernel config and builds rt-kernel based on that.
#				6.4 "Adjusting configuration"
#					Make expert adjustments (choose preemption mode, timer frequency, disable drivers e.g. Comedi, etc).
#				6.5 "Optional: enable pcie215 option in kernel config"
#					Enables Quadrant's pcie215 driver in kernel config.
#				6.6 "Optional: .config file review"
#					Displays config in vim for 'inline' adjustments.
#			7.	"Validation"
#				Checks if CONFIG_PREEMPT_RT_FULL option has been turned on in .config - prints WARNING if not and asks if to continue.
#			8. "Build preparing"
#				Checks the number of cores on the machine, so it can pass correct value to make –j flag.
#			9.	"Kernel commpilation"
#				Make (compile core kernel, vmlinuz and compressed bzImage in arch folder (e.g. arch/x86/boot/bzImage)).
#			10.	"Modules compilation"
#				Make all chosen modules.
#			11. "Modules installation"
#				Make modules_install (copy modules to /lib/modules).
#			12.	"Kernel installation"
#				Make install (installation, sources arch/$ARCH/boot/install.sh, copy vmlinuz to /boot, build initial root ram disk file system initramfs, build grub configuration file)
#			13. Reboot?
# date		4/11/2016 13:19

# first, some utility functions
fail () {
	exit $1
}

# param 1 - > Number of step
# param 2 - > Step description
report_step () {
	echo "\n------------>\nStep $1: $2"
	echo "------------>\n"
}

# allows user interaction to stop or continue
user_continue () {
    ans=
    # While nothing entered
    while [ "$ans" = "" ]
    do
        read -p "        Continue (y/n)?" ans # Prompt user for input
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
        read -p "        $1 (y/n)?" ans
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
		read -p "        Which kernel version would you like to install? (please type in format x.y)" ans
    done
	# return version
	echo $ans
}

enable_pcie215 () {
	pcie215_folder=
	read -p "        Please enter absolute (!) path to the pcie215 folder (includes pcie215 at the end): " pcie215_folder
	cp -r "$pcie215_folder" drivers/staging
	echo "\tpcie215 driver will be available under Device drivers -> Staging drivers. If you want to build and install it during following build please turn the option on - otherwise simply exit configuration menu w/o saving."
	user_continue
	echo 'obj-$(CONFIG_PCIE215)	+= pcie215/' >> drivers/staging/Makefile
	sed -i '$ d' drivers/staging/Kconfig
	echo 'source "drivers/staging/pcie215/Kconfig"' >> drivers/staging/Kconfig
	echo '' >> drivers/staging/Kconfig
	echo 'endif # STAGING' >> drivers/staging/Kconfig
	make menuconfig
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

cleanup () {
	rmdir $mapdir
}

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

report_step 1 "Preparing to install..."

echo "\tNext steps"
echo "\t1: Preparing to install"
echo "\t\tThis step."
echo "\t2: System detection"
echo "\t\tChecks the operating system version."
echo "\t3: Download"
echo "\t\tDownloads and unpacks the kernel and corresponding RT patch."
echo "\t\tIt is possible to install default kernel linux-4.4.70 and patch it using patch-4.4.70-rt83.patch."
echo "\t\tInternet connection is not needed if kernel and patch (extracted or packed) are present in installation folder."
echo "\t4: Patching the kernel"
echo "\t\tPatches the kernel."
echo "\t5: Installing dependencies"
echo "\t\tInstalls the dependencies needed to create menuconfig."
echo "\t6: Preparing the kernel configuration file \".config\"..."
echo "\t\tCreates config. Options:"
echo "\t\t6.1	Optional: Clean default configuration"
echo "\t\t		Creates clean default configuration with make defconfig."
echo "\t\t6.2	Optional: Default configuration with oldconfig"
echo "\t\t		Creates new configuration of kernel reflecting current configuration and asks to choose new options which have no match."
echo "\t\t6.3	Optional: Copy existing configuration"
echo "\t\t		Copies existing kernel config and builds rt-kernel based on that."
echo "\t\t6.4	Adjusting configuration"
echo "\t\t		Make expert adjustments (choose preemption mode, timer frequency, disable drivers e.g. Comedi, etc)."
echo "\t\t6.5	Optional: enable pcie215 option in kernel config"
echo "\t\t		Enables Quadrant's pcie215 driver in kernel config."
echo "\t\t6.6	Optional: .config file review"
echo "\t\t		Displays config in vim for 'inline' adjustments."
echo "\t7: Validation"
echo "\t\tChecks if CONFIG_PREEMPT_RT_FULL option has been turned on in .config - prints WARNING if not and asks if to continue."
echo "\t8: Build preparing"
echo "\t\tChecks the number of cores on the machine, so it can pass correct value to make –j flag."
echo "\t9: Kernel commpilation"
echo "\t\tMake (compiles core kernel, vmlinuz and compressed bzImage in arch folder (e.g. arch/x86/boot/bzImage))."
echo "\t10: Modules compilation"
echo "\t\tMakes all chosen modules."
echo "\t11: Modules installation"
echo "\t\tMake modules_install (copy modules to /lib/modules)."
echo "\t12: Kernel installation"
echo "\t\tMake install (source arch/$ARCH/boot/install.sh, copy vmlinuz to /boot, initial root ram disk file system initramfs, grub config)."
echo "\t13: Optional reboot"

put "3.0" "kernel" "linux-3.0.101"
put "3.0" "kernel_folder" "v3.0"
put "3.0" "patch" "patch-3.0.101-rt130.patch"
put "3.2" "kernel" "linux-3.2.88"
put "3.2" "kernel_folder" "v3.x"
put "3.2" "patch" "patch-3.2.88-rt126.patch"
put "3.4" "kernel" "linux-3.4.113"
put "3.4" "kernel_folder" "v3.x"
put "3.4" "patch" "patch-3.4.113-rt145.patch"
put "3.6" "kernel" "linux-3.6.11"
put "3.6" "kernel_folder" "v3.x"
put "3.6" "patch" "patch-3.6.11.9-rt42.patch"
put "3.8" "kernel" "linux-3.8.13"
put "3.8" "kernel_folder" "v3.x"
put "3.8" "patch" "patch-3.8.13.14-rt31.patch"
put "3.10" "kernel" "linux-3.10.105"
put "3.10" "kernel_folder" "v3.x"
put "3.10" "patch" "patch-3.10.105-rt120.patch"
put "3.12" "kernel" "linux-3.12.72"
put "3.12" "kernel_folder" "v3.x"
put "3.12" "patch" "patch-3.12.72-rt97.patch"
put "3.14" "kernel" "linux-3.14.79"
put "3.14" "kernel_folder" "v3.x"
put "3.14" "patch" "patch-3.14.79-rt85.patch"
put "3.18" "kernel" "linux-3.18.48"
put "3.18" "kernel_folder" "v3.x"
put "3.18" "patch" "patch-3.18.48-rt54.patch"
put "4.0" "kernel" "linux-4.0.8"
put "4.0" "kernel_folder" "v4.x"
put "4.0" "patch" "patch-4.0.8-rt6.patch"
put "4.1" "kernel" "linux-4.1.39"
put "4.1" "kernel_folder" "v4.x"
put "4.1" "patch" "patch-4.1.39-rt47.patch"
# changed from 4.4.32 to 4.4.38
# changed from 4.4.38 to 4.4.39
# changed from 4.4.39 to 4.4.60
# changed from 4.4.60 to 4.4.70
put "4.4" "kernel" "linux-4.4.70"
put "4.4" "kernel_folder" "v4.x"
put "4.4" "patch" "patch-4.4.70-rt83.patch"
put "4.6" "kernel" "linux-4.6.7"
put "4.6" "kernel_folder" "v4.x"
put "4.6" "patch" "patch-4.6.7-rt14.patch"
put "4.8" "kernel" "linux-4.8.15"
put "4.8" "kernel_folder" "v4.x"
put "4.8" "patch" "patch-4.8.15-rt10.patch"
put "4.9" "kernel" "linux-4.9.20"
put "4.9" "kernel_folder" "v4.x"
put "4.9" "patch" "patch-4.9.20-rt16.patch"

report_step 2 "System detection"
# source the /etc/os-release config file
. /etc/os-release
if [ "$NAME" = "Ubuntu" ]; then
	echo "\tDetected that OS is Ubuntu"
elif [ "$NAME" = "Debian*" ] || [ "$NAME" = "Debian GNU/Linux" ]; then
	echo "\tDetected that OS is Debian"
	NAME="Debian"
else
	# couldn't get system info, but give user option to continue
	echo "\tCouldn't fetch operating system's version but you can still proceed if you'd like to."
	echo "\tPlease choose option:\nD/d - Debian installation\nU/u - Ubuntu installation\nany other key - abort\n"
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

# get sources (kernel + rt patch)
report_step 3 "Download"
major=
kernel=
patch=

use_default_kernel () {
	kernel=linux-4.4.70
	patch=patch-4.4.70-rt83.patch
	major=4.4
	kernel_folder=$(get "$major" "kernel_folder")

	if [ ! -d "$kernel" ]; then
		if [ ! -f "$kernel.tar.gz" ]; then
			echo "\tNo tar archive found in this folder to unpack the sources."
			user_ask_exec "Download default kernel now?" "wget kernel.org/pub/linux/kernel/$kernel_folder/$kernel.tar.gz" "exit"
		fi
		echo "\tUnpacking kernel..."
		tar zxvf $kernel.tar.gz
	else
		echo "\tUsing old kernel directory..."
	fi

	if [ ! -f "$patch" ]; then
		if [ ! -f "$patch.gz" ]; then
			echo "\tNo archive found in this folder to unpack the patch"
			user_ask_exec "Download default patch now?" "wget kernel.org/pub/linux/kernel/projects/rt/$major/older/$patch.gz" "exit"
		fi
		echo "\tUnpacking patch..."
		gunzip $patch.gz
	else
		echo "\tUsing old patch file..."
	fi
}

use_downloaded_kernel () {
	# setup the sources to install
	versions=`ls $mapdir`
	echo "\n\tSupported major kernel versions:"
	echo "$versions"
	major=$(user_get_kernel_major_version)
	kernel_folder=$(get "$major" "kernel_folder")
	kernel=$(get "$major" "kernel")
	patch=$(get "$major" "patch")
	echo "\tAttempt to download (if needed):\n\tkernel: $kernel.tar.gz\n\trt-patch: $patch.gz"
	user_ask_exec "Continue?" "return 0" "exit 1"

	if [ ! -d "$kernel" ]; then
		if [ ! -f "$kernel.tar.gz" ]; then
			echo "\tDownloading kernel sources..."
			wget kernel.org/pub/linux/kernel/$kernel_folder/$kernel.tar.gz
		fi
		echo "\tUsing old kernel archive..."
		# unpack kernel
		tar zxvf $kernel.tar.gz
		if [ ! -d "$kernel" ]; then
			echo "Kernel source files missing, aborting..."
			exit 1
		fi
	else
		echo "\tUsing old kernel directory..."
	fi

	if [ ! -f "$patch" ]; then
		if [ ! -f "$patch.gz" ]; then
			echo "\tDownloading rt-patch..."
			if [ "$NAME" = "Ubuntu" ]; then
				wget kernel.org/pub/linux/kernel/projects/rt/$major/older/$patch.gz
			else
				wget kernel.org/pub/linux/kernel/projects/rt/$major/older/$patch.gz
			fi
		else
			echo "\tUsing old patch archive..."
		fi
		# unpack patch
		gunzip $patch.gz
		if [ ! -f "$patch" ]; then
			echo "RT patch files missing, aborting..."
			exit 1
		fi
	else
		echo "\tUsing old patch file..."
	fi
}

user_ask_exec "Use default kernel (predownloaded linux-4.4.70) and optionally patch it (with patch-4.4.70-rt83.patch)?" "use_default_kernel" "use_downloaded_kernel"

# patch the kernel
report_step 4 "Patching the kernel..."
eval $(echo cd $kernel)
user_ask_exec "Apply the patch?" "patch -p1 < ../$patch" "return 0"

# install the dependencies (curses, build-essential for menuconfig utility and ssl for kernel build)
report_step 5 "Installing dependencies..."
sudo apt-get update --fix-missing
sudo apt-get --yes --force-yes install libncurses5-dev libssl-dev vim build-essential

# building the kernel configuration file ".config - user must give manual input"
report_step 6 "Preparing the kernel configuration file \".config\"..."

report_step 6.1 "Optional: Clean default configuration"
user_ask_exec "Would you like to run 'make defconfig' (create default configuration)" "make defconfig" "return 0"

report_step 6.2 "Optional: Default configuration with oldconfig"
user_ask_exec "Would you like to run 'make oldconfig' (create new configuration of kernel reflecting current configuration and ask you to configure new options)" "make oldconfig" "return 0"

report_step 6.3 "Optional: Copy existing configuration"
user_ask_exec "Would you like to copy existing kernel config and build rt-kernel based on that? You will be asked about options which have no match in current config." "cp /boot/config-`uname -r` .config; make oldconfig" "return 0"

report_step 6.4 "Adjusting configuration (expert adjustments)"
echo "\tThe configuration menu will now be displayed for making expert adjustments."
echo "\tIf you are building RT kernel it is advised to set following options:"
echo "\t\t1. Preemption model -> Fully preemptible (RT)"
echo "\t\t2. Check stack overflows -> No"
echo "\t\t3. Timer frequency -> 1000HZ"
echo "\t\t4. Disable comedi support (Device drivers -> Staging drivers -> Data Acquisition support - Comedi)"
user_continue
make menuconfig

report_step 6.5 "Optional: enable pcie215 option in kernel config"
user_ask_exec "Would you like to enable pcie215 driver for this kernel?" "enable_pcie215" "return 0"

report_step 6.6 "Optional: .config file review"
user_ask_exec "Would you like to review the .config file?" "vim .config" "return 0"

# assert rt preemption is turned on
report_step 7 "Validation..."
rt_full=`grep -ri CONFIG_PREEMPT_RT_FULL .config`
rt_full_opt=`echo -n $rt_full | tail -c 1`
if [ "$rt_full_opt" != "y" ]
then
	echo "WARNING, RT preemption has not been enabled, the option in kernel config is set to [$rt_full]"
	user_continue
else
	echo "\tOK"
fi

# checking the number of CPU cores on this machine
report_step 8 "Build preparing..."
cpus=`nproc`
cores_per_cpu=`cat /proc/cpuinfo | awk '/^cpu cores/{print $4}' | tail -1`
cores=$(($cpus*$cores_per_cpu))
echo "\tFound $cpus CPUs and $cores cores\n"

# compile new kernel with rt support
report_step 9 "Kernel compilation"
echo "\tCompiling new  $major kernel with rt support.\n\t[vmlinuz] (make -j$cores)...\n\t[bzImage] (make -j$cores)..."
user_continue
make -j$cores

report_step 10 "Modules compilation"
echo "\tCompiling kernel modules (make modules -j$cores)..."
user_continue
sudo make modules -j$cores

report_step 11 "Modules installation"
echo "\tInstalling kernel modules\n\t[/lib/modules] (make modules_install -j$cores)..."
user_continue
sudo make modules_install -j$cores

report_step 12 "Kernel installation"
echo "\tInstalling the kernel\n\t[/boot/vmlinuz] (make install -j$cores)..."
user_continue
sudo make install -j$cores

# OK, ask whether to reboot
report_step 13 "Done ($major)"
echo "\tDone.\n\tYou can boot your new kernel."
sync	
user_ask_exec "Reboot now?" "sudo reboot" "return 0"
cleanup
