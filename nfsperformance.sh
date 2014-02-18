#!/bin/bash
## Super awful NFS performance data capture script
## Maintainer: Kyle Squizzato - ksquizza@redhat.com

## Fill in each of the variables in the SETUP section then start the script
## to capture performance data.  Script captures NFS memory usage, CPU, local disk
## IOs, stack traces and a tcpdump.  


## -- SETUP -- 

# Case Number
casenumber=X

# Interval to wait in seconds before captures
interval="5"

# Stack trace interval.  Note: Stack traces generate a lot of CPU activity.
str="300" 

# Capture time in seconds to capture all data.
capture="600"

## TCPDUMP Specific Options

# Interface to filter
# It's best to filter the results based on the interface and server (if applicable) that
# is problematic.  If you do not know what interface to use specify 'any'.
interface="eth0"

# Server IP or hostname to filter
# If server filtering is not required simply remove the 'host $server' section from the
# tcpdump command below.  More complicated host filtering can be used if desired, check 
# 'man tcpdump'.
server="192.168.122.1"

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 1 file, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s 512 -i $interface host $server -W 1 -C 1024M -w /tmp/performance.pcap -Z root"

## -- END SETUP -- 

# Capture data for NFS performance problems  
$tcpdump &
nfsiostat $interval /nfs/mount/point > /tmp/nfsiostat.out & 
iostat -xt $interval > /tmp/iostat.out & 
iostat -ct $interval > /tmp/nfs_cpu.out & 
(while true; do echo "t" > /proc/sysrq-trigger; sleep $str; done) &
(while true; do date >> /tmp/nfs_meminfo.out; cat /proc/meminfo | egrep "(Dirty|Writeback|NFS_Unstable):" >> /tmp/nfs_meminfo.out; sleep 5; done) &

# Wait 10 minutes, then kill all above commands 
sleep $capture
kill -9 $(jobs -p) > /dev/null 2>&1

# Run mountstats on each NFS mount point
awk '$2 !~ /\/proc\/fs\/nfsd/ && $3 ~ /nfs/ { print $2 }' /proc/mounts | while read nfsmounts; do date >> /tmp/mountstats.out ; echo "NFS Mount: $nfsmounts" >> /tmp/mountstats.out; mountstats --rpc $nfsmounts >> /tmp/mountstats.out; mountstats --nfs $nfsmounts >> /tmp/mountstats.out; done

# Tar up the resulting data set
sleep 10
tar czvf /tmp/$casenumber.tar.gz /tmp/*.out /tmp/performance.pcap /var/log/messages

echo -e 'DONE: Compressed statistics data can be found in' /tmp/$casenumber.tar.gz
