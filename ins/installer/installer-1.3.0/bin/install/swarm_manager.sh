#!/bin/bash
. /etc/bashrc



BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN

if [ -e ${APP_BASE}/install/funs.sh ] ; then
. ${APP_BASE}/install/funs.sh
else
. ${BIN}/funs.sh
fi
 

checkClusterEnv(){
    if [ "${CLUSTER_HOST_LIST//,/ }" = "" ] ; then
        echo "cluster not init"
        exit 1
    fi
}
getManagerNode(){
    for HOST in ${CLUSTER_HOST_LIST//,/ } ; do
        if [ "$HOST" != "$LOCAL_HSOT" -a "$HOST" != "`hostname`" ] ; then
            swarmStaus=`  ssh $HOST  docker info 2>/dev/null|grep " Is Manager"|awk '{print $3}' `
            if [ "$swarmStaus" = "true"  ] ; then  #  manager
                echo "$HOST"
                break
            fi
        fi
    done
    if [ "$swarmStaus" = "" ] ; then
        swarmStaus=`docker info 2>/dev/null|grep " Is Manager"|awk '{print $3}' `
        if [ "$swarmStaus" = "true" ] ; then  
            echo "$HOSTNAME"
        fi
    fi
}
init(){
    CLUSTERLIST=$1
    CLUSTERLIST="${CLUSTERLIST:=$CLUSTER_HOST_LIST}"
    echo "begin to  init docker Swarm cluster"
    service docker start
    hostSwarmStaus=`docker info 2>/dev/null|grep " Is Manager"|awk '{print $3}' `
    if [ "$hostSwarmStaus" = "true" ] ; then
        echo "swarm cluster is aready inited "
        exit 0
    fi
    docker swarm init --advertise-addr $LOCAL_IP
    swarmInitStaus=`docker swarm join-token manager 2>&1 |grep -v "command:" |sed -e 's|\\\\||'`
    if [ "$swarmInitStaus" = "${swarmInitStaus/--token/}" ] ; then  # �ҵ�manager
        echo "swarm init failed:$swarmInitStaus"
        exit 1
    fi
    docker swarm update --task-history-limit=2   
    swarmInitStaus=`echo $swarmInitStaus` # del \n
    echo "swarmInitStaus=$swarmInitStaus"
    for HOST in ${CLUSTERLIST//,/ } ; do
        if [ "$HOST" != "$LOCAL_HOST" ] ; then
            ssh $HOST service docker start
            errorExit $? "$HOST start docker service failed"
            echo "ssh $HOST \"$swarmInitStaus\""
            ssh $HOST "$swarmInitStaus"
            errorExit $? "$HOST add to swarm cluster failed"
            echo "ssh $HOST service docker restart"
            ssh $HOST service docker restart
        fi
    done
    echo "end  init docker Swarm cluster"
}

addHostToSwarm(){
    CLUSTERLIST=$1
    roleType=$2
    roleType=${roleType:=worker}
    if [ "$CLUSTERLIST" = "" ] ; then
        printHelp
        exit 1
    fi
#    CLUSTERLIST="${CLUSTERLIST:=$CLUSTER_HOST_LIST}"
    managerNode=`getManagerNode`
    if [ "$managerNode" = "" ] ; then
        echo "not get swarm manager node"
        exit 1
    fi 
    swarmInitStaus=""
    if [ "$managerNode" != "" ] ; then
        swarmInitStaus=`  ssh $managerNode  docker swarm join-token $roleType  2>&1 |grep -v "command:" |sed -e 's|\\\\||'`
        swarmInitStaus=`echo $swarmInitStaus` # del \n
    fi
    echo "swarmInitStaus=$swarmInitStaus"
    if [ "$swarmInitStaus" != "${swarmInitStaus/--token/}" ] ; then  # manager
        for HOST in ${CLUSTERLIST//,/ } ; do
            dockerStatus=`ssh $HOST service docker status|grep Active:|grep running`
            if [ "$dockerStatus" = "" ] ; then
                echo "ssh $HOST service docker start"
                ssh $HOST service docker start
                errorExit $? "$HOST start docker service failed"
            fi
            
            echo "ssh $managerNode docker node demote $HOST"
            ssh $managerNode docker node demote $HOST
            echo " ssh $managerNode docker node rm -f $HOST"
            ssh $managerNode docker node rm -f $HOST
            echo "ssh $HOST docker swarm leave --force "
            ssh $HOST docker swarm leave --force 
            hostSwarmStaus=`  ssh $HOST  docker info 2>/dev/null|grep " Is Manager"|awk '{print $3}' `
            if [ "$hostSwarmStaus" != "" ] ; then
                echo "$HOST Is Manager $hostSwarmStaus"
            else
                echo "ssh $HOST \"$swarmInitStaus\""
                ssh $HOST "$swarmInitStaus"
                ssh $HOST service docker restart
                hostSwarmStaus=`ssh $HOST  docker info 2>/dev/null|grep " Is Manager"|awk '{print $3}' `
                if [ "$hostSwarmStaus" = "" ] ; then
                    errorExit 1 "$HOST add to swarm cluster failed"
                fi
            fi
        done
        exit $?
    else
         # init $1
         echo "not find a exists manager,places must init a swarm cluster befor add"
         exit 1
    fi
}



printHelp(){
    echo "usetag:
        init CLUSTER_HOST_LIST: init a swarm cluster
        addhost hosts manager|worker: add host to exists swarm cluster
        node ...: docker node order on swarm manager node
        service ...: docker service order on swarm manager node
        swarm ...: docker swarm order on swarm manager node
        docker ...: docker order on swarm manager node
        ssh \$@
        "
    exit 1
}

if [ "$1" = "-h"  -o "$1" = "--help" ] ; then
    printHelp
    exit 1 
fi

COMMAND=$1
shift

if [ "$COMMAND" = "addhost" -o "$COMMAND" = "node" -o "$COMMAND" = "service" -o "$COMMAND" = "swarm" -o "$COMMAND" = "docker"  ]; then
    checkClusterEnv
    export managerNode=`getManagerNode`
    if [ "$managerNode" = "" ] ; then
        echo "not get swarm manager node"
        exit 1
    fi
fi
    
if [ "$COMMAND" = "init" ]; then
   init $@
elif [ "$COMMAND" = "addhost" ]; then
    addHostToSwarm $@
elif [ "$COMMAND" = "node"  -o "$COMMAND" = "service" -o "$COMMAND" = "swarm" ]; then
    ssh $managerNode docker $COMMAND $@
elif [ "$COMMAND" = "docker" ]; then
     ssh $managerNode docker $@
elif [ "$COMMAND" != "" ]; then
    ssh $COMMAND $@
fi
if [ "$COMMAND" != "" ] ; then
exit $?
fi


#################################################################��װ���� registry ###################################################
