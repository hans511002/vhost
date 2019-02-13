#! /bin/bash

HAPROXY_APP_NAME="hadocker"

dockerCons=`docker ps |grep dynamic-ha- |grep $HAPROXY_APP_NAME | awk '{print $NF}'`
if [ "$dockerCons" != "" ] ; then
    for dockCon in $dockerCons ; do
        docker stop $dockCon
    done
    
fi

exit 0
