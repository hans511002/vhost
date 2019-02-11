. /etc/bashrc

bin=$(cd $(dirname $0); pwd)

if [ `which ssh > /dev/null 2>&1; echo $?` = "0" -a "$1" != "true" ]; then
    ver1=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $1}'`
    ver2=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $2}'`
    if [ "$ver1" = "7.7" ]; then
        echo "ssh -V: `ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}'`"
        exit 0
    fi
fi

if [ "$CLUSTER_HOST_LIST" != "" ] ; then
    echo ". /etc/bashrc
    for HOST in \${CLUSTER_HOST_LIST//,/ } ; do
         sed -i -e \"/\$HOST/d\"  /root/.ssh/known_hosts
    done
    for HOST in \${CLUSTER_HOST_LIST//,/ } ; do
         auto_smart_ssh pass \$HOST  ls / > /dev/null 
    done
">/tmp/known_hosts.sh
    chmod +x /tmp/known_hosts.sh
    for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
        if [ "$HOST" != "$HOSTNAME" ] ; then
            echo "scp -rp $bin/openssh-7.7p1-bin.tar.gz $bin/upgrade_openssh* $HOST:$bin/ "
            scp -rp $bin/openssh-7.7p1-bin.tar.gz $bin/upgrade_openssh* $HOST:$bin/ 
            if [ "$?" != "0" ] ; then
               echo "scp failed: scp -rp $bin/* $HOST:$bin/"
               exit 1
            fi
            echo "scp -p /tmp/known_hosts.sh $HOST:/tmp/known_hosts.sh"
            scp -p /tmp/known_hosts.sh $HOST:/tmp/known_hosts.sh
        fi
    done
     
    for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
        ssh $HOST $bin/upgrade_openssh.sh $1
    done
    /tmp/known_hosts.sh
    rm -rf /tmp/known_hosts.sh
    for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
        if [ "$HOST" != "$HOSTNAME" ] ; then
            ssh $HOST /tmp/known_hosts.sh
            ssh $HOST rm -rf /tmp/known_hosts.sh
        fi
    done
else
    $bin/upgrade_openssh.sh $1
fi 
