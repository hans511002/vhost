#! /bin/bash
echo "exec cluster_upgrade_end.sh"

cmd.sh rm -rf $LOGS_BASE/docker/docker_containers


for host in `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'` ; do
    ssh $host /bin/start_hive_autostart.sh
done
exit 0
