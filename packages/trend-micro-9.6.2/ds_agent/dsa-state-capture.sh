#!/bin/bash

# The first argument is the name of a directory where we can create files or symlinks.
# The agent will include any files we drop in the this directory in the diagnostic zip.
if [ "$#" -ge 1 ]; then
	cd "${1}"
	shift
fi

# ------------------------------------------------------------------------
# make sure we are running as root and output is going to a file or pipe

if test -t 1 ; then
	DATE=$(date +%Y%m%d-%H%M%S)
	FILE="/tmp/dsa-state-$DATE"
	echo output logged to $FILE 2>&1
	exec >$FILE "$0" ${1+"$@"}
	exit 1
fi

if test `id -u` -ne 0 ; then
	echo rerunning script with sudo 2>&1
	exec sudo "$0" $@
	exit 1
fi

# ------------------------------------------------------------------------
# helper functions

die() {
	echo >&2 $@
	exit 1
}

header() {
        echo
	echo "#######################################################################################"
	echo "### $@"
	echo "#######################################################################################"
}

bag() {
    for f in $*; do
        test -r $f && header $f && cat $f
    done
}

DSVA_PATH=/var/vcap/packages/trend-micro-9.6.2/ds_agent
DSVA_ENV=$DSVA_PATH/slowpath/dsva-ovf.env
DSVA_XML=$DSVA_PATH/slowpath/dsva-ovf.xml
IS_DSVA=0
if test -f "$DSVA_ENV" ; then 
    IS_DSVA=1
fi

# ------------------------------------------------------------------------
# fix the PATH

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# ------------------------------------------------------------------------
# kernel info

PROC_FILES=$(ls /proc/*info /proc/cmdline /proc/version)
for f in $PROC_FILES ; do
	ln -s "$f" proc-$(basename "${f}")
done


# ------------------------------------------------------------------------
# dump all of proc

PROC_DSA=/proc/driver/dsa

if test -d "$PROC_DSA" ; then
	PROC_DSA_FILES=$(find $PROC_DSA -type f | grep -v 'trace$' | sort)

	for f in $PROC_DSA_FILES ; do
		ln -s "$f" proc-dsa-$(basename "${f}")
	done

	#This is currently hanging on SuSE 10
	#PROC_DSA_TRACE=/proc/driver/dsa/trace
	#header "PROC: $PROC_DSA_TRACE"
	#( sleep 2 ; ps aux                                       \
	#   | awk '/[c]at.\/proc\/driver\/dsa\/trace/ {print $2}' \
	#   | xargs kill -INT ) &
	#cat $PROC_DSA_TRACE 2>/dev/null
	#echo ""
else
	header "ERROR: no $PROC_DSA directory found"
fi

# dump all of gsch proc

PROC_GSCH=/proc/driver/gsch

if test -d "$PROC_GSCH" ; then
	PROC_GSCH_SCAN_FILES=$(find "${PROC_GSCH}/scan" -type f | sort)
	PROC_GSCH_REDIRFS_FILES=$(find "${PROC_GSCH}/redirfs" -type f | sort)
	PROC_GSCH_SYSHOOK_FILES=$(find "${PROC_GSCH}/syshook" -type f | sort)

	for f in $PROC_GSCH_SCAN_FILES ; do
		ln -s "$f" proc-gsch-scan-$(basename "${f}")
	done
	
	for f in $PROC_GSCH_REDIRFS_FILES ; do
		ln -s "$f" proc-gsch-redirfs-$(basename "${f}")
	done
	
	for f in $PROC_GSCH_SYSHOOK_FILES ; do
		ln -s "$f" proc-gsch-syshook-$(basename "${f}")
	done
else
	header "INFO: no $PROC_GSCH directory found"
fi

# dump all of redirfs proc

PROC_REDIRFS=/sys/fs/redirfs

if test -d "$PROC_REDIRFS" ; then
	PROC_REDIRFS_FILES="/sys/fs/redirfs/count /sys/fs/redirfs/filters/gsch_flt/paths";

	for f in $PROC_REDIRFS_FILES ; do
		ln -s "$f" proc-redirfs-$(basename "${f}")
	done
else
	header "INFO: no $PROC_REDIRFS directory found"
fi

# ------------------------------------------------------------------------
# get info about modules

LSMOD=$(which lsmod)

header "LSMOD"
${LSMOD} 2>&1

# ------------------------------------------------------------------------
# get info about PCI

LSPCI=$(which lspci)

header "LSPCI: tree"
${LSPCI} -tv 2>&1

header "LSPCI: verbose"
${LSPCI} -vv 2>&1

# ------------------------------------------------------------------------
# get info about USB

LSUSB=$(which lsusb)

header "LSUSB"
${LSUSB} 2>&1

# ------------------------------------------------------------------------
# get info about XEN

XEN_CAPS="/proc/xen/capabilities"

header "XEN: capabilities"
cat ${XEN_CAPS}

XENSTORE_LS=$(which xenstore-ls)

header "XEN: xenstore-ls"
${XENSTORE_LS} 2>&1

# ------------------------------------------------------------------------
# get info from ifconfig

IFCONFIG=$(which ifconfig)

header "IFCONFIG"
${IFCONFIG} -a 2>&1

# ------------------------------------------------------------------------
# get info from netstat

NETSTAT=$(which netstat)

if [ $IS_DSVA -eq "0" ]; then
header "NETSTAT: interfaces"
${NETSTAT} -ian 2>&1
fi

if [ $IS_DSVA -eq "1" ]; then
header "NETSTAT: interfaces"
${NETSTAT} -ean 2>&1
fi

header "NETSTAT: routes"
${NETSTAT} -ran 2>&1

if [ $IS_DSVA -eq "0" ]; then
header "NETSTAT: IP"
${NETSTAT} --ip -anp 2>&1
fi

# ------------------------------------------------------------------------
# get info from ethtool

ETHTOOL=$(which ethtool)

for eth in $(ifconfig -a | awk '/:Ethernet/ { print $1 }') ; do
        header "ETHTOOL: info ${eth}"
        "${ETHTOOL}" -i "${eth}" 2>&1

        header "ETHTOOL: pause ${eth}"
        "${ETHTOOL}" -a "${eth}" 2>&1

        header "ETHTOOL: coalesce ${eth}"
        "${ETHTOOL}" -c "${eth}" 2>&1

        header "ETHTOOL: ring ${eth}"
        "${ETHTOOL}" -g "${eth}" 2>&1

        header "ETHTOOL: offload ${eth}"
        "${ETHTOOL}" -k "${eth}" 2>&1
done

# ------------------------------------------------------------------------
# get stuff from sysctl

SYSCTL=$(which sysctl)

header "SYSCTL"
${SYSCTL} -A 2>&1

# ------------------------------------------------------------------------
# get stuff from dmesg

BOOT_DMESG=/var/log/dmesg
DMESG=$(which dmesg)
DMESG_LINES=100

header "DMESG: boot"
cat ${BOOT_DMESG}

header "DMESG: last ${DMESG_LINES}"
${DMESG} | tail -n ${DMESG_LINES}

MSGS=/var/log/messages
SYSL=/var/log/syslog
KERN=/var/log/kern.log

if test -f "$MSGS" ; then
	header "$MSGS"
	cat "$MSGS"
fi

if test -f "$SYSL" ; then
	header "$SYSL"
	cat "$SYSL"
fi

if test -f "$KERN" ; then
	header "$KERN"
	cat "$KERN"
fi

# ------------------------------------------------------------------------
# get kernel config

CONFIG_GZ=/proc/config.gz
CONFIG_VER="/boot/config-$(uname -r)"
CONFIG_DEFAULT="/boot/config"

if test -f "${CONFIG_GZ}" ; then
        header "CONFIG: config.gz"
        zcat "${CONFIG_GZ}" | grep "^CONFIG_"
elif test -f "${CONFIG_VER}" ; then
        header "CONFIG: $(uname -r)"
        cat "${CONFIG_VER}" | grep "^CONFIG_"
else
        header "CONFIG: default"
        cat "${CONFIG_DEFAULT}" | grep "^CONFIG_"
fi

# ------------------------------------------------------------------------
# get kernel package versions

if ( which dpkg >/dev/null 2>&1 ) ; then
        header "DPKG kernel packages"
        dpkg -S /boot/vmlinu* | cut -d : -f 1 | xargs -n1 dpkg-query -W
fi
if ( which rpm >/dev/null 2>&1 ) ; then
        header "RPM kernel packages"
        rpm -qf /boot/vmlinu*
fi

# ------------------------------------------------------------------------
# get disk information
header "DISK Status"
df -h 2>&1
echo

grab() {
    if test -x $1; then
        header $1;
        $* 2>&1
    fi
}
LD_LIBRARY_PATH=/var/vcap/packages/trend-micro-9.6.2/ds_agent/lib grab /var/vcap/packages/trend-micro-9.6.2/ds_agent/ds_am -s 1


header "df -kH"
df -kH
mount

# ------------------------------------------------------------------------
# get stuff from ratt

RATT="/var/vcap/packages/trend-micro-9.6.2/ds_agent/ratt"

if test -x "$RATT" ; then
	header "RATT version"
	$RATT version 2>&1
	echo

	header "RATT inteface"
	$RATT if 2>&1
	echo

	header "RATT blacklist"
	$RATT blacklist -4 2>&1
	$RATT blacklist -6 2>&1
	echo

	header "RATT conntrack UDP"
	$RATT conntrack UDP 2>&1
	echo

	header "RATT conntrack TCP"
	$RATT conntrack TCP 2>&1
	echo

	header "RATT stats"
	$RATT stats -a 2>&1
	echo

	header "RATT trace"
	$RATT trace -i 2>&1
	echo

	header "RATT tz"
	$RATT tz 2>&1
	echo

	header "RATT var"
	$RATT var 2>&1
	echo

else
	header "ERROR: no ratt tool found in $RATT"
fi

bag /var/vcap/packages/trend-micro-9.6.2/ds_agent/am/amgblcfg.xml
ln -s /var/vcap/packages/trend-micro-9.6.2/ds_agent/notifier_version.txt /var/vcap/sys/log/trend-micro/ds_agent/ds_monitor.log .
echo

# ------------------------------------------------------------------------
# get dsva stuff

if [ $IS_DSVA -eq "1" ]; then
header "DSVA INFORMATION STARTS HERE"
header "DSVA INFORMATION - dsva-ovf.env"
	cat "$DSVA_ENV"

header "DSVA INFORMATION - dsva-ovf.xml"
	cat "$DSVA_XML"

# ------------------------------------------------------------------------
# are we on the DSVA
conf="/var/vcap/packages/trend-micro-9.6.2/ds_agent/guests"

# get status of all upstart
header "DSVA Process List"
initctl list 2>&1
echo

initdir="/etc/event.d"

find $conf/ -mindepth 1 -maxdepth 1 -type d | while read i
do

uuid=`basename "$i"`
uuid_path=$conf/$uuid

#ignore 0000-0000-0000
uuid_len=$(echo ${#uuid})
if [ $uuid_len -gt 14 ] ; then

header "DS INFORMATION FOR GUEST:$uuid" 2>&1

header "uuid.map for GUEST:$uuid"
cat $conf/"${uuid}"/uuid.map >&1
echo

header "amvmcfg.xml for GUEST:$uuid"
cat $uuid_path/amvmcfg.xml
echo

header "# of quarantined file(s) GUEST:$uuid"
find $uuid_path/quarantined/ -maxdepth 1 -type f | wc -l 2>&1

header "RATT show interface for GUEST:$uuid"
$RATT  -u "${uuid}" if >&1
echo

header "RATT variables for GUEST:$uuid"
$RATT  -u "${uuid}" var >&1
echo

header "RATT stats for GUEST:$uuid"
$RATT  -u "${uuid}" stats >&1
echo

header "RATT conntrack UDP for GUEST:$uuid"
$RATT -u "${uuid}" conntrack UDP >&1
echo

header "RATT conntrack TCP for GUEST:$uuid"
$RATT -u "${uuid}" conntrack TCP >&1
echo

header "ds_guest_agent.log for GUEST:$uuid"
cat $uuid_path/diag/ds_guest_agent.log

fi

done

fi

if [ -x /var/vcap/packages/trend-micro-9.6.2/ds_agent/dvfilter/vmguestinfo.sh ]; then
	header "DSVA SLOWPATH UNACTIVATED VM INFO" 2>&1
	/var/vcap/packages/trend-micro-9.6.2/ds_agent/dvfilter/vmguestinfo.sh -u >&1
fi

if [ -x /var/vcap/packages/trend-micro-9.6.2/ds_agent/dvfilter/vmguestinfo.sh ]; then
	header "DSVA SLOWPATH ACTIVATED VM INFO" 2>&1
	/var/vcap/packages/trend-micro-9.6.2/ds_agent/dvfilter/vmguestinfo.sh -a >&1
fi

header "DSVA YUM PACKAGE LIST" 2>&1
yum list >&1

exit 0;

