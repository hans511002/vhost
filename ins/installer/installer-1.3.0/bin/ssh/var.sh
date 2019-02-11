#!/bin/bash

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`


HOST_CONFIG=

CLUSTER_IPS=
CLUSTER_ROOTPASS=
CLUSTER_HADOOP_USER=
CLUSTER_HADOOP_PASS=
CLUSTER_HOST_NAME=
CLUSTER_NUMBER=0

if test -f  $bin/sshHosts ;  then
	index=0
	#cat  $bin/sshHosts|
	while read line
	do
         HOST_CONFIG[$index]=$line
         # echo ${HOST_CONFIG[$index]}
        ((index++))
	done < $bin/sshHosts

fi

index=0
count=${#HOST_CONFIG[@]}
for (( i=0;i<count;i=i+1))
do
	HostPar=${HOST_CONFIG[$i]}

	if test "`expr substr "$HostPar" 1 1`" = "#" ; then
			continue;
		fi
	if test "`expr substr "$HostPar" 1 1`" = "" ; then
			continue;
		fi
	if test "`expr substr "$HostPar" 1 1`" = "\r" ; then
			continue;
		fi

	arr=($HostPar) #字符转数组 ##arr=(${HostPar// / })
	if test "${#arr[@]}" -lt 1 ;then
		continue;
	fi


	echo ${arr[0]} | perl -ne 'exit 1 unless /\b(?:(?:(?:[01]?\d{1,2}|2[0-4]\d|25[0-5])\.){3}(?:[01]?\d{1,2}|2[0-4]\d|25[0-5]))\b/'
	if [ $? -eq 1 ];then
		continue;
	fi

 	echo HostPar=$HostPar

    CLUSTER_IPS[$index]=${arr[0]}
    CLUSTER_ROOTPASS[$index]=${arr[1]}
    CLUSTER_HADOOP_USER[$index]=${arr[2]}
    CLUSTER_HADOOP_PASS[$index]=${arr[3]}
    CLUSTER_HOST_NAME[$index]=${arr[4]}
    ((CLUSTER_NUMBER++))
    ((index++))

done

	echo CLUSTER_NUMBER=$CLUSTER_NUMBER
	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		echo ${CLUSTER_IPS[$i]} ${CLUSTER_ROOTPASS[$i]} ${CLUSTER_HADOOP_USER[$i]} ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HOST_NAME[$i]}
	done

