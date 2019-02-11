#! /bin/bash

if [ $# -lt 2 ] ; then 
  echo "usetag:docker_expand.sh CLUSTER_HOST_LIST EXPAND_HOSTS_LIST"
  exit 1
fi
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

. $APP_BASE/install/funs.sh


CLUSTER_HOST_LIST=$1
CLUSTER_HOST_LIST="${CLUSTER_HOST_LIST//,/ }"
echo "CLUSTER_HOST_LIST=$CLUSTER_HOST_LIST"
NCLUSTER_HOST_LIST=$2
NCLUSTER_HOST_LIST="${NCLUSTER_HOST_LIST//,/ }"
echo "NCLUSTER_HOST_LIST=$NCLUSTER_HOST_LIST"

if [ "${NCLUSTER_HOST_LIST//$LOCAL_HOST/}" = "${NCLUSTER_HOST_LIST}" ] ; then
    exit 0
fi

echo "add to swarm cluster : ${APP_BASE}/install/swarm_manager.sh addhost ${LOCAL_HOST} worker"
${APP_BASE}/install/swarm_manager.sh addhost ${LOCAL_HOST} worker
errorExit $? "add to swarm cluter with worker failed"

registry_hosts=`getAppHosts registry`
if [ "$registry_hosts" = "" ] ; then
#    for NEWHOST in $NCLUSTER_HOST_LIST ; do
        for OLDHOST in $CLUSTER_HOST_LIST ; do
           # ssh $NEWHOST
           echo " scp $OLDHOST:/etc/profile.d/app_hosts.sh /etc/profile.d/app_hosts.sh  "
              scp $OLDHOST:/etc/profile.d/app_hosts.sh /etc/profile.d/app_hosts.sh  
            if [ "$?" = "0" ] ; then
                break
            fi
        done
#    done
    . /etc/profile.d/app_hosts.sh
    if [ "$registry_hosts" = "" ] ; then
        echo "not find registry hosts"
        exit 1
    fi
fi
if [ ! -f "/etc/profile.d/registry.sh" ] ; then
#    for NEWHOST in $NCLUSTER_HOST_LIST ; do
        for REGHOST in ${registry_hosts//,/ } ; do
            echo "  scp -r  $REGHOST:/etc/profile.d/registry.sh /etc/profile.d/registry.sh"
            #ssh $NEWHOST 
            scp -r  $REGHOST:/etc/profile.d/registry.sh /etc/profile.d/registry.sh
            if [ "$?" = "0" ] ; then
                break
            fi
        done
#    done
fi
if [ -f /etc/profile.d/registry.sh ] ; then
    . /etc/profile.d/registry.sh
    if [ "$REGISTRY_DOMAIN" = "" ] ; then
        echo "not find env: REGISTRY_DOMAIN"
        exit 1
    fi
    #for NEWHOST in $NCLUSTER_HOST_LIST ; do
        #ssh $NEWHOST 
        mkdir -p /etc/docker/certs.d/$REGISTRY_DOMAIN:5000
        cpflag="false"
        for REGHOST in ${registry_hosts//,/ } ; do
            echo " scp -r  $REGHOST:/etc/docker/certs.d/$REGISTRY_DOMAIN:5000/registry.crt  /etc/docker/certs.d/$REGISTRY_DOMAIN:5000/registry.crt"
            #ssh $NEWHOST 
            scp -r  $REGHOST:/etc/docker/certs.d/$REGISTRY_DOMAIN:5000/registry.crt  /etc/docker/certs.d/$REGISTRY_DOMAIN:5000/registry.crt 
            if [ "$?" = "0" ] ; then
                cpflag="true"
                break
            fi
        done
        if [ "$cpflag" != "true" ] ; then
            echo "not find registry file"
            exit 1
        fi 
    #done
    
    if [ "$REGISTRY_USE_AUTH" != "false" ] ; then
        echo "login to  registry : docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS"
        res=1
        retTimes=0
        while [ "$res" != "0" ]  ;  do
            docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS
            res=$?
            ((retTimes++))
           if [ "$retTimes" -gt "10" ] ; then 
               break;
           fi
        done
        errorExit $res "docker login to registry faield : docker login $REGISTRY_DOMAIN:5000  -u $REGISTRY_USER -p  $REGISTRY_PASS"
    fi
fi

exit $?
