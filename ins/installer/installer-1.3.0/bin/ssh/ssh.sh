#!/bin/bash

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`


. $bin/sshFun.sh
. $bin/var.sh
if [ $? -gt 0 ] ;then
	echo "load params error"
	exit 1
fi

ROOT_SSHED="false"

if [ $# -gt 0 ]
then
	DEST_HOST_IP=$1 #添加指定一台机器
	echo DEST_HOST_IP | perl -ne 'exit 1 unless /\b(?:(?:(?:[01]?\d{1,2}|2[0-4]\d|25[0-5])\.){3}(?:[01]?\d{1,2}|2[0-4]\d|25[0-5]))\b/'
	if [ $? -eq 1 ];then
        ROOT_SSHED="$DEST_HOST_IP";
        DEST_HOST_IP=""
	else
		shift
		ROOT_SSHED=$1
	fi
fi

echo ROOT_SSHED=$ROOT_SSHED
echo DEST_HOST_IP=$DEST_HOST_IP


HSOTS_CONTENT=
DEST_HOST_INDEX=-1
for (( i=0;i<CLUSTER_NUMBER;i=i+1))
do
	echo CLUSTER_IPS[$i]=${CLUSTER_IPS[$i]}
	HSOTS_CONTENT="${HSOTS_CONTENT}${CLUSTER_IPS[$i]} ${CLUSTER_HOST_NAME[$i]} \n"

	if [ "$DEST_HOST_IP" = "${CLUSTER_IPS[$i]}" ] ; then
		DEST_HOST_INDEX=$i
	fi
done
if [ $DEST_HOST_INDEX -gt -1 ] ; then
echo add host="$DEST_HOST_IP"  hostIndex=$DEST_HOST_INDEX
fi

echo assert add...

if [ $DEST_HOST_INDEX -gt -1 ]
then
	if (( "$DEST_HOST_INDEX" = "-1" )) ; then
		echo "输入的IP在配置文件中不存在"
		exit 1
	fi
###################配置各主机HOSTNAME########################################
	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		if [ "$i" = "$DEST_HOST_INDEX" ] ; then
			COMMAND="echo -e 'NETWORKING=yes\nNETWORKING_IPV6=no\nHOSTNAME=${CLUSTER_HOST_NAME[$i]}'>/etc/sysconfig/network"
			echo "配置主机:${CLUSTER_IPS[$i]} Hostname:${CLUSTER_HOST_NAME[$i]} "
			auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
			auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} service network xreload

			#拷贝文件 auto_ssh_copy_id
			auto_scp ${CLUSTER_ROOTPASS[$i]} auto_ssh_copy_id  root@${CLUSTER_IPS[$i]}:/bin/auto_ssh_copy_id
			auto_scp ${CLUSTER_ROOTPASS[$i]} auto_smart_ssh  root@${CLUSTER_IPS[$i]}:/bin/auto_smart_ssh
			auto_scp ${CLUSTER_ROOTPASS[$i]} auto_add_user  root@${CLUSTER_IPS[$i]}:/bin/auto_add_user
			auto_scp ${CLUSTER_ROOTPASS[$i]} auto_passwd_user  root@${CLUSTER_IPS[$i]}:/bin/auto_passwd_user
		fi

	    echo "配置主机${CLUSTER_IPS[i]} Hostname ${CLUSTER_HOST_NAME[$i]} 配置主机Hosts"
		COMMAND="echo -e '127.0.0.1 localhost \n${HSOTS_CONTENT}${CLUSTER_IPS[$i]} LOCAL_IP'>>/etc/hosts"
		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
	done
	i=$DEST_HOST_INDEX

	if test "$ROOT_SSHED" != "true" ; then
		##################实现root用户 ssh 互联######################
		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}   "rm -rf /root/.ssh/*"

		COMMAND="ssh-keygen -t rsa  -f /root/.ssh/id_rsa -q -N ''"
		echo "配置主机${CLUSTER_IPS[i]} Hostname ${CLUSTER_HOST_NAME[$i]} SSH"
		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}   "$COMMAND"
	    auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "cd ~/.ssh && rm -rf authorized_keys known_hosts"

		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
			do
				#远程执行 auto_ssh_copy_id
				echo "copy ${CLUSTER_IPS[i]} root key to  ${CLUSTER_IPS[$j]}   "
				COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_ROOTPASS[$j]}  root@${CLUSTER_IPS[$j]}"
				auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
				COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_ROOTPASS[$i]}  root@${CLUSTER_IPS[$i]}"
				auto_smart_ssh ${CLUSTER_ROOTPASS[$j]} root@${CLUSTER_IPS[$j]}  "$COMMAND"
		done

		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
			do
			#新加主机 连 所有主机
		 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$j]}  ${CLUSTER_IPS[$j]} pwd"
				auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
		 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$j]}  ${CLUSTER_HOST_NAME[$j]} pwd"
			 	auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
			 #所有主机 连 新加主机
			 	COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$i]}  ${CLUSTER_IPS[$i]} pwd"
				auto_smart_ssh ${CLUSTER_ROOTPASS[$j]} root@${CLUSTER_IPS[$j]}  "$COMMAND"
		 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$i]}  ${CLUSTER_HOST_NAME[$i]} pwd"
			 	auto_smart_ssh ${CLUSTER_ROOTPASS[$j]} root@${CLUSTER_IPS[$j]}  "$COMMAND"
		done
	fi
	###################添加 用户############################
	echo "添加 用户   "

	auto_add_user ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} ${CLUSTER_HADOOP_USER[$i]}  ${CLUSTER_HADOOP_PASS[$i]}
	auto_passwd_user ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} ${CLUSTER_HADOOP_USER[$i]}  ${CLUSTER_HADOOP_PASS[$i]}

	###################实现用户 ssh 互联 ############################
	#for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	#do
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}   "rm -rf /home/${CLUSTER_HADOOP_USER[$i]}/.ssh/*"
		COMMAND="ssh-keygen -t rsa  -f /home/${CLUSTER_HADOOP_USER[$i]}/.ssh/id_rsa -q -N ''"
		echo "配置主机${CLUSTER_IPS[i]} Usre: ${CLUSTER_HADOOP_USER[$i]} SSH"
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}   "$COMMAND"
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "cd ~/.ssh && rm -rf authorized_keys known_hosts"

	#done

	#for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	#do
		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
		do
			echo "copy ${CLUSTER_IPS[i]} ${CLUSTER_HADOOP_USER[$i]} key to  ${CLUSTER_IPS[$j]}   "
	 		COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_HADOOP_USER[$j]}@${CLUSTER_IPS[$j]}"
			auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"
			COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_HADOOP_PASS[$i]}  ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}"
			auto_smart_ssh ${CLUSTER_HADOOP_PASS[$j]} ${CLUSTER_HADOOP_USER[$j]}@${CLUSTER_IPS[$j]}  "$COMMAND"
		done
	#done

	#for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	#do
		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
		do
	 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_IPS[$j]} pwd"
			auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"
	 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_HOST_NAME[$j]} pwd"
		 	auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"


		 	COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$i]}  ${CLUSTER_IPS[$i]} pwd"
			auto_smart_ssh ${CLUSTER_ROOTPASS[$j]} ${CLUSTER_HADOOP_USER[$j]}@${CLUSTER_IPS[$j]}  "$COMMAND"
	 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$i]}  ${CLUSTER_HOST_NAME[$i]} pwd"
		 	auto_smart_ssh ${CLUSTER_ROOTPASS[$j]} ${CLUSTER_HADOOP_USER[$j]}@${CLUSTER_IPS[$j]}  "$COMMAND"
		done
	#done

else
###################配置各主机HOSTNAME########################################
	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		COMMAND="echo -e 'NETWORKING=yes\nNETWORKING_IPV6=no\nHOSTNAME=${CLUSTER_HOST_NAME[$i]}'>/etc/sysconfig/network"
		echo "配置主机:${CLUSTER_IPS[$i]} Hostname:${CLUSTER_HOST_NAME[$i]} "
		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}   "$COMMAND"

		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} service network xreload

	    echo "配置主机${CLUSTER_IPS[i]} Hostname ${CLUSTER_HOST_NAME[$i]} 配置主机Hosts"
		COMMAND="echo -e '127.0.0.1 localhost \n$HSOTS_CONTENT'>>/etc/hosts"
		auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"

		#拷贝文件 auto_ssh_copy_id
		auto_scp ${CLUSTER_ROOTPASS[$i]} "auto_ssh_copy_id  root@${CLUSTER_IPS[$i]}:/bin/auto_ssh_copy_id"
		auto_scp ${CLUSTER_ROOTPASS[$i]} "auto_smart_ssh  root@${CLUSTER_IPS[$i]}:/bin/auto_smart_ssh"
		auto_scp ${CLUSTER_ROOTPASS[$i]} "auto_add_user  root@${CLUSTER_IPS[$i]}:/bin/auto_add_user"
		auto_scp ${CLUSTER_ROOTPASS[$i]} "auto_passwd_user  root@${CLUSTER_IPS[$i]}:/bin/auto_passwd_user"
	done

	if test "$ROOT_SSHED" != "true" ; then
		##################实现root用户 ssh 互联######################

		for (( i=0;i<CLUSTER_NUMBER;i=i+1))
		do

			auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}   "rm -rf /root/.ssh/*"

			COMMAND="ssh-keygen -t rsa  -f /root/.ssh/id_rsa -q -N ''"
			echo "配置主机${CLUSTER_IPS[i]} Hostname ${CLUSTER_HOST_NAME[$i]} SSH"
			auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}   "$COMMAND"
			auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "cd ~/.ssh && rm -rf authorized_keys known_hosts"

		done


		for (( i=0;i<CLUSTER_NUMBER;i=i+1))
		do
			for (( j=0;j<CLUSTER_NUMBER;j=j+1))
			do
				#远程执行 auto_ssh_copy_id
				COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_ROOTPASS[$j]}  root@${CLUSTER_IPS[$j]}"
				echo "copy ${CLUSTER_IPS[i]} root key to  ${CLUSTER_IPS[$j]}   "
				auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"

			done
		done

		for (( i=0;i<CLUSTER_NUMBER;i=i+1))
		do
			for (( j=0;j<CLUSTER_NUMBER;j=j+1))
			do
		 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$j]}  ${CLUSTER_IPS[$j]} pwd"
				echo "copy ${CLUSTER_IPS[i]} root key to  ${CLUSTER_IPS[$j]}   "
				auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
		 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_ROOTPASS[$j]}  ${CLUSTER_HOST_NAME[$j]} pwd"
			 	auto_smart_ssh ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]}  "$COMMAND"
			done
		done
	fi
	###################添加用户############################
	echo "添加用户   "

	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		auto_add_user ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} ${CLUSTER_HADOOP_USER[$i]}  ${CLUSTER_HADOOP_PASS[$i]}
	 	auto_passwd_user ${CLUSTER_ROOTPASS[$i]} root@${CLUSTER_IPS[$i]} ${CLUSTER_HADOOP_USER[$i]}  ${CLUSTER_HADOOP_PASS[$i]}
	done
	###################实现用户 ssh 互联 ############################
	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}   "rm -rf /home/${CLUSTER_HADOOP_USER[$i]}/.ssh/*"

		COMMAND="ssh-keygen -t rsa  -f /home/${CLUSTER_HADOOP_USER[$i]}/.ssh/id_rsa -q -N ''"
		echo "配置主机${CLUSTER_IPS[i]} Usre: ${CLUSTER_HADOOP_USER[$i]} SSH"
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}   "$COMMAND"
		auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "cd ~/.ssh && rm -rf authorized_keys known_hosts"

	done

	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
		do
			echo "copy ${CLUSTER_IPS[i]} ${CLUSTER_HADOOP_USER[$i]} key to  ${CLUSTER_IPS[$j]}   "
	 		COMMAND="/bin/auto_ssh_copy_id  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$j]}"
			auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"

		done
	done

	for (( i=0;i<CLUSTER_NUMBER;i=i+1))
	do
		for (( j=0;j<CLUSTER_NUMBER;j=j+1))
		do
	 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_IPS[$j]} pwd"
			auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"
	 		COMMAND="/bin/auto_smart_ssh  ${CLUSTER_HADOOP_PASS[$j]}  ${CLUSTER_HOST_NAME[$j]} pwd"
		 	auto_smart_ssh ${CLUSTER_HADOOP_PASS[$i]} ${CLUSTER_HADOOP_USER[$i]}@${CLUSTER_IPS[$i]}  "$COMMAND"
		done
	done

fi

