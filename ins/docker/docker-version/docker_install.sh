#!/bin/bash
#
# author: zouyuangui
# description: 
# docker服务安装
#sed -i '/^SELINUX=/c\SELINUX=disabled' /etc/selinux/config 
#
if [ $# -lt 2 ] ; then
	echo CFG_FILE  VERSION
	exit 1
fi
 . /etc/bashrc
 . /etc/profile.d/docker.sh
bin=`dirname "${BASH_SOURCE-$0}"`

CFG_FILE=$1 
VERSION=$2

service docker stop


proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}')
rootDomain=${PRODUCT_DOMAIN/$proDomain./}
REGISTRY_DOMAIN=${REGISTRY_DOMAIN:=registry.$rootDomain}  #registry.$PRODUCT_DOMAIN

yum install -y docker-ce

#rpm -ivh --nodeps $bin/docker-engine-1.9.1-1.el7.x86_64.rpm 

#/usr/lib/systemd/system/docker.service
rm -rf /etc/systemd/system/multi-user.target.wants/docker.service
#cat $bin/docker.service > /usr/lib/systemd/system/docker.service
echo "[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
Environment=GOTRACEBACK=crash
ExecStart=/usr/bin/dockerd $OPTIONS \
          $DOCKER_STORAGE_OPTIONS \
          $DOCKER_NETWORK_OPTIONS \
          $ADD_REGISTRY \
          $BLOCK_REGISTRY \
          $INSECURE_REGISTRY
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
Restart=always

StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
" > /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl disable docker.service

DOCKER_GROUP_USER=$(grep "^[[:space:]]*DOCKER_GROUP_USER=" "$CFG_FILE" | sed -e 's/DOCKER_GROUP_USER=//' )
DOCKER_ENABLE=$(grep "^[[:space:]]*DOCKER_SERVICE_ENABLE=" "$CFG_FILE" | sed -e 's/DOCKER_SERVICE_ENABLE=//' )
if [ "$DOCKER_ENABLE" = "true" ] ; then
    systemctl enable docker.service
fi

#for f in `ls $bin/bin` ; do
#   rm -rf  /usr/bin/$f 
#   cp $bin/bin/$f    /usr/bin/$f 
#done
#chmod +x /usr/bin/docker*

DOCKER_OPTIONS=$(grep "^[[:space:]]*DOCKER_OPTIONS=" "$CFG_FILE" | sed -e 's/DOCKER_OPTIONS=//' )
DOCKER_NETWORK_OPTIONS=$(grep "^[[:space:]]*DOCKER_NETWORK_OPTIONS=" "$CFG_FILE" | sed -e 's/DOCKER_NETWORK_OPTIONS=//' )

if [ "${DOCKER_NETWORK_OPTIONS//\$\{IPINTERFACE\}/}" = "" ] ; then
    IP2Interface=$(ifconfig | grep -B 3 "$LOCAL_IP" | grep 'BROADCAST' | cut -d: -f1)
    if [ "$IP2Interface" = "" ] ; then
        IP2Interface=`ip a|grep "$LOCAL_IP"|awk '{print $7}'`
        if [ "$IP2Interface" = "" ] ; then
           IP2Interface="eno0"
        fi
    fi
    DOCKER_NETWORK_OPTIONS="${DOCKER_NETWORK_OPTIONS//\$\{IPINTERFACE\}/$IP2Interface}"
fi

DOCKER_DATADIR=` echo $DOCKER_OPTIONS |sed -e 's/.*--graph=/--graph=/'|sed -e 's/ .*//' |sed -e 's/--graph=//' `
rm -rf $DOCKER_DATADIR/network/files

#--storage-driver devicemapper --log-opt max-size=10m --log-opt max-file=2 --storage-opt dm.fs=xfs --storage-opt dm.basesize=2G --storage-opt dm.override_udev_sync_check=true --insecure-registry registry.ery.com:5000 --ip-forward=true --iptables=true  --restart=true 




echo $DOCKER_OPTIONS |grep -e "( -s )|( --storage-driver )"
SOPT1=$?
if [ "$SOPT1" = "0" ] ; then
    echo $DOCKER_OPTIONS |grep " devicemapper "
    SOPT2=$?
    if [ "$SOPT2" = "0" ] ; then
        echo $DOCKER_OPTIONS |grep "dm.override_udev_sync_check=true"
        if [ "$?" != "0" ] ; then
            DOCKER_OPTIONS="$DOCKER_OPTIONS  --storage-opt dm.override_udev_sync_check=true"
        fi   
    fi
fi

DOCKER_OPTIONS="$DOCKER_OPTIONS --insecure-registry $REGISTRY_DOMAIN:5000 --ip-forward=true --iptables=true  --restart=true "


# -H unix:///var/run/docker.sock 
dockerSockFile=`echo $DOCKER_OPTIONS |grep  -E "unix:///.*.sock "`
if [ "$dockerSockFile" = "" ] ; then
    DOCKER_OPTIONS="$DOCKER_OPTIONS -H unix:///var/run/docker.sock "
fi

dockerSockFile=`echo $DOCKER_OPTIONS |sed -e  "s|.*unix://\(/.*.sock\).*|\1|"`

systemctl daemon-reload

# /etc/sysconfig/docker 
if [ -f "/etc/sysconfig/docker" ] ; then
DOCKER_OPTIONS=${DOCKER_OPTIONS//\//\\\/}
sed -i "s@OPTIONS=.*@OPTIONS=$DOCKER_OPTIONS@g" /etc/sysconfig/docker 
else
echo "OPTIONS=$DOCKER_OPTIONS">/etc/sysconfig/docker 
fi

# /etc/sysconfig/docker-network
if [ -f "/etc/sysconfig/docker-network" ] ; then
DOCKER_NETWORK_OPTIONS=${DOCKER_NETWORK_OPTIONS//\//\\\/}
sed -i "s/DOCKER_NETWORK_OPTIONS=.*/DOCKER_NETWORK_OPTIONS=$DOCKER_NETWORK_OPTIONS/g" /etc/sysconfig/docker-network 
 else
echo "DOCKER_NETWORK_OPTIONS=$DOCKER_NETWORK_OPTIONS">/etc/sysconfig/docker-network 
fi

service docker start
if [ "$?" != "0" ] ; then
    echo "docker start failed"
    exit 1
fi
if [ -e "$dockerSockFile"  ] ; then
    if [ "$docker_user" != "" ] ; then
        sudo chown root:$DOCKER_GROUP_USER $dockerSockFile
    fi
else
    echo "docker sock file not exits : $dockerSockFile"
    exit 1
fi


mkdir -p ${bin}/sbin/

_START_CFGDB_FILE="${bin}/sbin/start_docker.sh"

echo "docker_user=$docker_user"
if [ "$docker_user" != "" ] ; then
    CHOWNSUDO="sudo chown root:$DOCKER_GROUP_USER $dockerSockFile"
    SUDOCMD="sudo"
    echo "sudo mkdir -p /etc/docker"
    sudo mkdir -p /etc/docker
    echo "sudo chown $docker_user:$docker_user -R /etc/docker"
    sudo chown $docker_user:$docker_user -R /etc/docker
fi
    
echo "#!/bin/bash 
$SUDOCMD service docker start 
$CHOWNSUDO
sleep 2
daemonPid=\$(ps -ef|grep dockerd |awk '{print \$2}');
if [ \"X\$daemonPid\" = \"X\" ];then 
DOCKER_OPTIONS=\$(grep \"^[[:space:]]*OPTIONS=\" \"/etc/sysconfig/docker\" | sed -e 's/OPTIONS=//' )
DOCKER_NETWORK_OPTIONS=\$(grep \"^[[:space:]]*DOCKER_NETWORK_OPTIONS=\" \"/etc/sysconfig/docker-network\" | sed -e 's/DOCKER_NETWORK_OPTIONS=//' )
CMD=\"/usr/bin/dockerd --log-level=error \$DOCKER_OPTIONS \$DOCKER_NETWORK_OPTIONS\"
echo \"\$CMD\"
\$CMD
$CHOWNSUDO
exit 0
fi

">$_START_CFGDB_FILE

chmod a+x $_START_CFGDB_FILE

_STOP_CFGDB_FILE="${bin}/sbin/stop_docker.sh"
 
echo "#!/bin/bash 
$SUDOCMD service docker stop  
sleep 1
daemonPid=\$(ps -ef|grep dockerd|awk '{print \$2}');
if [ \"X\$daemonPid\" != \"X\" ];then 
    waitTimes=0
    while  kill -0 \$daemonPid ;  do
       echo \"waitTimes=\$waitTimes\"
       sleep 1
       ((waitTimes++))
       if [ \"$waitTimes\" -gt \"60\" ] ; then
           kill -9 \$daemonPid
           daemonConPid=\$(ps -ef|grep -E \"(docker-containerd-shim)|(docker-proxy)\" |awk '{print \$2}');
           if [ \"\$daemonConPid\" != \"\" ] ; then
                for cPid in \$daemonConPid ; do
                    kill -9 \$cPid
                done
           fi
       fi
    done
    exit 0
fi
">$_STOP_CFGDB_FILE

chmod a+x $_STOP_CFGDB_FILE

exit 0
