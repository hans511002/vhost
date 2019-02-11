#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN
if [ "${CLUSTER_HOST_LIST//,/ }" = "" ] ; then
    echo "cluster not init"
    exit 1
fi

service deploy stop
service docker stop
umount /var/run/docker/netns/*
rm -rf /var/run/docker/libnetwork/*
rm -rf /var/run/docker/netns/*
rm -rf /var/lib/docker/network/files
DOCKER_DATA=`cat /etc/sysconfig/docker | sed -e "s|.*--graph=||"  -e "s|/docker.*|/docker|" `
if [ "$DOCKER_DATA" = "" ] ; then
    DOCKER_DATA="${DATA_BASE}/docker"
fi
rm -rf $DOCKER_DATA/network/files

service docker start
service deploy start
echo "If the Docker service can not be restarted properly, execute the script again and restart the computer"
