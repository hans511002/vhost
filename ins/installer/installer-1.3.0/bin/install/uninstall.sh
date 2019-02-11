#!/bin/bash
. /etc/bashrc

BIN=$(cd $(dirname $0); pwd)
appHosts=${CLUSTER_HOST_LIST//,/ }

if [ "$USER" != "root" ] ; then
    echo "must run in root user"
    exit 1
fi

if [ "$1" != "-y" ] ; then
    echo -n "Are you sure uninstall app system platform(y/n)[n]: "
    read answer
    if [ "$answer" != "y" ] ; then
        exit 0
    fi
else
    shift
fi

oneAll="$1"
if [ "$oneAll" = "" ] ; then
    echo -n "Are you sure uninstall this host or all host(one/all)[one]: "
    read answer
    oneAll="$answer"
fi
if [ "$oneAll" != "one" -a "$oneAll" != "all" ] ; then
    exit 0
fi

if [ -f "$APP_ETC/cluster.cfg" ] ; then
    ADDUSERS=`cat $APP_ETC/cluster.cfg |grep install.user=|sed -e "s|.*install.user=|user=|"|sort|uniq|grep -v root|awk -F= '{printf("%s ", $2)}'`
else
    ADDUSERS=`cat $BIN/cluster.cfg |grep install.user=|sed -e "s|.*install.user=|user=|"|sort|uniq|grep -v root|awk -F= '{printf("%s ", $2)}'`
fi

if [ "$oneAll" = "all" ] ; then
    echo "begining uninstall app system platform"
    cmd.sh service appservice stop
    cmd.sh service deploy stop
    cmd.sh service appdns stop
    cmd.sh service docker stop
    cmd.sh service keepalived stop
    cmd.sh service haproxy stop

    for zkHost in ${zookeeper_hosts//,/ } ; do
        ssh $zkHost \$ZOOKEEPER_HOME/sbin/stop-zk.sh
    done

    if [ "`ls /dev/docker/data`" != "" ] ; then
    for host in `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'` ; do
        echo "$host start docker service for remove iamges "
        ssh $host service docker start
        echo "$host remove  CONTAINER "
        ssh $host "docker ps -a |grep -v CONTAINER |awk '{print \$NF}' |xargs docker rm -f"
        echo "$host remove images "
        ssh $host "docker images | grep -v REPOSITORY |awk '{print \$3}' |xargs docker rmi -f"
        ssh $host service docker stop
    done
    fi

    for host in `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'` ; do
        ssh $host rm -rf  /etc/xinetd.d/*_status
    done
    
    for serApp in shostname appservice deploy appdns docker ; do
        cmd.sh service $serApp stop
        cmd.sh systemctl disable $serApp
        cmd.sh rm -rf /usr/lib/systemd/system/$serApp.service
    done

    for serApp in keepalived haproxy ; do
        cmd.sh service $serApp stop
        cmd.sh systemctl disable $serApp
        cmd.sh "yum remove -y $serApp >/dev/null"
    done
    
    for app in ${ALL_APP//,/ } ; do
        cmd.sh rm -rf /etc/profile.d/$app.sh
    done
    echo "del users"
    for user in $ADDUSERS ; do
        echo "userdel $user"
        cmd.sh userdel $user
        cmd.sh rm -rf /home/$user
    done
    cmd.sh groupdel docker 2>/dev/null
    cmd.sh  scp /etc/resolv.conf.bak /etc/resolv.conf

	for host in $appHosts ; do
		ssh $host "rm -rf /etc/resolv_app.conf"
		ssh $host "sed -i '/nameserver 127.0.0.1/d' /etc/resolv.conf"
		ssh $host "sed -i '1i nameserver 127.0.0.1' /etc/resolv.conf"
	done

    rmFiles="/etc/init.d/netpcap.sh /etc/init.d/appservice.sh /etc/init.d/shostname.sh /etc/init.d/deploy.sh /etc/init.d/dns_daemon.sh \
    /etc/haproxy/ $APP_ETC /etc/keepalived/ $APP_BASE $DATA_BASE $LOGS_BASE $INSTALL_ROOT/docker /etc/profile.d/1appenv.sh /etc/profile.d/0jdk.sh /etc/profile.d/app_hosts.sh \
    /etc/docker /bin/docker* /etc/xinetd.d/\*_status /bin/cp.sh /bin/cmd.sh"
    for file in ${rmFiles} ; do
        cmd.sh rm -rf "$file"
    done
    echo "uninstall app system platform end"

else
    echo "begining uninstall app system platform  on this host "

    $ZOOKEEPER_HOME/bin/zkServer.sh stop
    service docker stop

    if [ "`ls /dev/docker/data`" != "" ] ; then
        echo " start docker service for remove iamges "
        service docker start
        echo "$host remove  CONTAINER "
        docker ps -a |grep -v CONTAINER |awk '{print \$NF}' |xargs docker rm -f
        echo " remove images "
        docker images |grep -v REPOSITORY |awk '{print \$3}' |xargs docker rmi -f
        service docker stop
    fi

    if [ "$PPID" = "1" ] ; then
        nodeList=`$INSTALLER_HOME/sbin/installer zkctl -c base -d nodeList`
        while [ "${nodeList//$HOSTNAME,/}" != "${nodeList}" -o "${nodeList//,$HOSTNAME/}" != "${nodeList}" ] ;  do
          sleep 1
          echo "wait deploy service delete node $HOSTNAME, cluster node list:$nodeList"
          nodeList=`$INSTALLER_HOME/sbin/installer zkctl -c base -d nodeList`
        done
        sleep 2
    fi
    for serApp in keepalived haproxy ; do
        service $serApp stop
        systemctl disable $serApp
        yum remove -y $serApp >/dev/null
    done
    for serApp in shostname appservice deploy appdns docker ; do
        service $serApp stop
        systemctl disable $serApp
        rm -rf  /usr/lib/systemd/system/$serApp.service
    done
    for app in ${ALL_APP//,/ } ; do
        rm -rf /etc/profile.d/$app.sh
    done
    echo "del users"
    for user in $ADDUSERS ; do
        echo "userdel $user"
        userdel $user
        rm -rf /home/$user
    done
    groupdel docker

    rmFiles="/etc/init.d/netpcap.sh /etc/init.d/appservice.sh /etc/init.d/shostname.sh /etc/init.d/deploy.sh /etc/init.d/dns_daemon.sh \
    /etc/haproxy/ $APP_ETC /etc/keepalived/ $APP_BASE $DATA_BASE $LOGS_BASE $INSTALL_ROOT/docker /etc/profile.d/1appenv.sh /etc/profile.d/0jdk.sh /etc/profile.d/app_hosts.sh \
    /etc/docker /bin/docker*  /etc/xinetd.d/\*_status /bin/cp.sh /bin/cmd.sh"
    for file in ${rmFiles} ; do
        rm -rf $file
    done
    scp  /etc/resolv.conf.bak /etc/resolv.conf
	rm -rf /etc/resolv_app.conf
	sed -i '/nameserver 127.0.0.1/d' /etc/resolv.conf
	sed -i '1i nameserver 127.0.0.1' /etc/resolv.conf	

    echo "uninstall system platform on this host end"
fi

exit 0
