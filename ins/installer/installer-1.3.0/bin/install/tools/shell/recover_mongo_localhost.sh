#!/bin/bash

. /etc/bashrc
bin=$(cd $(dirname $0); pwd)
clusterHost=${CLUSTER_HOST_LIST//,/ }
force=$1
appName=mongo

for host in $clusterHost; do
    appHosts=$(ssh $host "echo \$mongo_hosts")
    if [ -n "$appHosts" ]; then
        echo "mongo_hosts=$appHosts"
        appHosts=${appHosts//,/ }
        for mhost in $appHosts; do
            appHome1=$(ssh $mhost "echo \$MONGO_HOME")
            appHome2=$(ssh $mhost "ls $appHome1")
            if [ -n "$appHome2" ]; then
                echo "\$MONGO_HOME=$appHome1"
                mongoHost=$mhost
                break 2
            fi
        done
    fi
done

[[ -n "$mongoHost" ]] || { echo "[ERROR] mongo_hosts= "; exit 1; }
[[ -n "$appHome2" ]] || { echo "[ERROR] \$MONGO_HOME= "; exit 1; }

appHost=$mongoHost
appHome=$appHome1
appVersion=`echo $appHome | awk -F '-' '{print $NF}'`
echo appVersion=$appVersion
appImage=`ssh $appHost "docker ps -a | grep mongo-mongos" | awk '{print $2}'`
echo "appImage=$appImage"

if [ "$force" != "force" ]; then
    if [ -d "$appHome" -o -n "`docker ps -a | grep mongo`" ]; then
        echo "please delete $appHome, delete mongo container, and retry!"
        exit 1
    fi
else
    rm -rf $appHome
    rm -rf ${APP_BASE}/install/mongo/mongo-*-*-run.sh
    docker ps -a | grep mongo | awk '{print $NF}' | xargs docker rm -f 2>/dev/null
fi

appImageFile=`ssh $appHost "ls ${appHome}/${appName}-${appVersion}.tar 2>/dev/null"`
if [ -z "$appImageFile" ];then
    echo "ssh $appHost \"docker save $appImage -o $appHome/${appName}-${appVersion}.tar\""
    ssh $appHost "docker save $appImage -o $appHome/${appName}-${appVersion}.tar"
fi

echo "scp -r ${appHost}:${appHome} ${APP_BASE}/"
scp -r ${appHost}:${appHome} ${APP_BASE}/

rm -rf ${DATA_BASE}/mongo/
rm -rf ${LOGS_BASE}/mongo/
mkdir -p ${DATA_BASE}/mongo/keyfile/
mkdir -p ${LOGS_BASE}/mongo/
mkdir -p ${APP_BASE}/install/mongo/
scp -r ${appHost}:${DATA_BASE}/mongo/keyfile/mongodb-keyfile ${DATA_BASE}/mongo/keyfile/mongodb-keyfile
chownUser=`ssh $appHost "getfacl ${DATA_BASE}/mongo/cfgdb 2>/dev/null" | awk -F ':' '/owner/{print $2}' | xargs echo`

scp -r ${appHost}:${APP_BASE}/install/mongo/mongo-*-${appVersion}-run.sh ${APP_BASE}/install/mongo/
sed -i "s/mongo-cfg-${appHost}/mongo-cfg-${LOCAL_HOST}/g" ${APP_BASE}/install/mongo/*
sed -i "s/mongo-shardrs1-${appHost}/mongo-shardrs1-${LOCAL_HOST}/g" ${APP_BASE}/install/mongo/*
sed -i "s/mongo-mongos-${appHost}/mongo-mongos-${LOCAL_HOST}/g" ${APP_BASE}/install/mongo/*
sed -i "s/${appHost}/${LOCAL_HOST}/g" ${appHome}/sbin/*.sh

scp -r ${appHost}:/etc/profile.d/mongo.sh /etc/profile.d/mongo.sh
. /etc/bashrc

echo "docker load -i ${appHome}/${appName}-${appVersion}.tar"
docker load -i ${appHome}/${appName}-${appVersion}.tar

if [ -n "`docker ps -a | grep mongo`" ]; then
    docker rm -f `docker ps -a | grep mongo | awk '{print $NF}'`
fi

${APP_BASE}/install/mongo/mongo-cfgdb-${appVersion}-run.sh 2>/dev/null
${APP_BASE}/install/mongo/mongo-shardrs-${appVersion}-run.sh 2>/dev/null
${APP_BASE}/install/mongo/mongo-mongos-${appVersion}-run.sh 2>/dev/null

stop_mongo.sh 2>/dev/null || docker stop $(docker ps -a | grep mongo | awk '{print $NF}')

chown -R $chownUser:$chownUser ${DATA_BASE}/mongo/
chown -R $chownUser:$chownUser ${LOGS_BASE}/mongo/


