#!/bin/bash
#This script is dynamic modify docker container disk
#Author Deng Lei
if [ -z $1 ] || [ -z $2 ]; then
    echo "Usage: container_name increase_capacity"
    echo "Example: I want increase 11G to test"
    echo "The command is:  sh `basename $0` test 11"
    exit 1
fi
if [ `docker inspect $1 &>>/dev/null &&  echo 0 || echo 1` -eq 1 ];then
    echo "The container $1 is no exist!"
    exit 1
fi
container_id=`docker inspect -f '{{ .Id }}' $1`
now_disk=`dmsetup table /dev/mapper/docker-*-$container_id|awk '{print $2}'`
disk=$(($2*512/1024/1024))
if [ $disk -lt $now_disk ]; then
    echo "I can\'t shink container $1 from $(($now_disk* 512/1024/1024))G to ${2}G!I only modify contanier increase disk!"
    exit 1
fi
dmsetup table /dev/mapper/docker-*-$container_id|sed "s/0 [0-9]* thin/0 $disk thin/"|dmsetup load /dev/mapper/docker-*-$container_id
dmsetup resume /dev/mapper/docker-*-$container_id
resize2fs /dev/mapper/docker-*-$container_id
if [ $? -eq 0 ]; then
    echo "dynamic container $1 disk to ${2}G is success!"
else
    echo "dynamic container $1 disk to ${2}G is fail!"
fi
