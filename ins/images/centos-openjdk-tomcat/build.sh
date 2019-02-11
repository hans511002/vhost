#!/bin/bash
BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$#" -lt "1" ] ; then
    echo "not get image tag"
fi
scp $BIN/../centos-jdk-tomcat/tomcat9.tar.gz ./
docker build -t $1 .

