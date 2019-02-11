#! /bin/bash


echo "exec cluster_upgrade_init.sh"
echo " 升级过程中禁用自动恢复 "
for host in `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'` ; do
    ssh $host /bin/stop_hive_autostart.sh
done

exit 0
