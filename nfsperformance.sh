#!/bin/bash
# Super awful NFS performance data capture script
# Needs lotsa work

# -- SETUP -- 

# Case number 
casenumber=01036336

# -- END SETUP -- 

# Capture data for NFS performance problems  
tcpdump -s 512 -i INTERFACE host NFS.SERVER.IP -w /tmp/performance.pcap &
nfsiostat 5 /nfs/mount/point > /tmp/nfsiostat.out & 
iostat -xt 5 > /tmp/iostat.out & 
iostat -ct 5 > /tmp/nfs_cpu.out & 
(while true; do echo "t" > /proc/sysrq-trigger; sleep 300; done) &
(while true; do date >> /tmp/nfs_meminfo.out; cat /proc/meminfo | egrep "(Dirty|Writeback|NFS_Unstable):" >> /tmp/nfs_meminfo.out; sleep 5; done) &

# Wait 10 minutes, then kill all above commands 
sleep 600
kill -9 $(jobs -p)

# Run mountstats on each NFS mount point
awk '$2 !~ /\/proc\/fs\/nfsd/ && $3 ~ /nfs/ { print $2 }' /proc/mounts | while read nfsmounts; do date >> /tmp/mountstats.out ; echo "NFS Mount: $nfsmounts" >> /tmp/mountstats.out; mountstats --rpc $nfsmounts >> /tmp/mountstats.out; mountstats --nfs $nfsmounts >> /tmp/mountstats.out; done

# Tar up the resulting data set
sleep 10
tar czvf /tmp/$casenumber.tar.gz /tmp/*.out /tmp/performance.pcap /var/log/messages

echo -e 'DONE: Compressed statistics data can be found in' /tmp/$caenumber.tar.gz
