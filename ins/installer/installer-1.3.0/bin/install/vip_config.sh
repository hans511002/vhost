#! /bin/bash
#
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

checkParam(){
    if [ $# = 0 ] ; then
        echo "no params"
        exit 1
    fi
}


writeToFile(){
    . /etc/bashrc
    AKSERVER_IP=$NEBULA_VIP
    # CLS_HOST_LIST=`cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'`
    CLS_HOST_LIST="${eagles_hosts//,/ }"
    CLS_HOST_LIST="${CLUSTER_HOST_LIST//,/ }" # 定义全局主机列表
    if [ "$CLS_HOST_LIST" = "" ] ; then
	CLS_HOST_LIST="${CLUSTER_HOST_LIST//,/ }" 
    fi
    HOST_LISTS=`echo $CLS_HOST_LIST|sed -e 's/ /;/g'`

    file=`dirname "${BIN}"`
    file="$file/ipconf.xml"
    if [ -f "$file" ] ; then
		oldVip=`cat $file |grep NEBULA_VIP|sed -e 's/<!--.*-->//'  |sed -r 's/.*<NEBULA_VIP.*>(.*)<.*/\1/'`
		echo "old NEBULA_VIP=$oldVip new=$NEBULA_VIP"
		sed -i -e "s#>$oldVip.*</VIP>#>$NEBULA_VIP</VIP>#" $file
		 
		oldVip=`cat $file |grep LOCAL_IP|sed -e 's/<!--.*-->//'  |sed -r 's/.*<LOCAL_IP.*>(.*)<.*/\1/'`
		echo "old LOCAL_IP=$oldVip new=$LOCAL_IP"
		sed -i -e "s#>$oldVip.*</LOCAL_IP>#>$LOCAL_IP</LOCAL_IP>#" $file
		 
		oldVip=`cat $file |grep LOCAL_HOSTNAME|sed -e 's/<!--.*-->//'  |sed -r 's/.*<LOCAL_HOSTNAME.*>(.*)<.*/\1/'`
		echo "old LOCAL_HOSTNAME=$oldVip new=$HOSTNAME"
		sed -i -e "s#>$oldVip.*</LOCAL_HOSTNAME>#>$HOSTNAME</LOCAL_HOSTNAME>#" $file
		
		oldVip=`cat $file |grep APP_NODES|sed -e 's/<!--.*-->//'  |sed -r 's/.*<APP_NODES.*>(.*)<.*/\1/'`
		echo "old APP_NODES=$oldVip new=$HOST_LISTS"
		sed -i -e "s#>$oldVip.*</APP_NODES>#>$HOST_LISTS</APP_NODES>#" $file
	
	    oldVip=`cat $file |grep DOMAIN_NAME|sed -e 's/<!--.*-->//'  |sed -r 's/.*<DOMAIN_NAME.*>(.*)<.*/\1/'`
		echo "old DOMAIN_NAME=$oldVip new=$PRODUCT_DOMAIN"
		sed -i -e "s#>$oldVip.*</DOMAIN_NAME>#>$PRODUCT_DOMAIN</DOMAIN_NAME>#" $file

        echo "config file update :$file"
    else
        echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<config>
        <VIP>$NEBULA_VIP</NEBULA_VIP>
        <LOCAL_IP>$LOCAL_IP</LOCAL_IP>
        <LOCAL_HOSTNAME>$HOSTNAME</LOCAL_HOSTNAME>
        <DOMAIN_NAME>$PRODUCT_DOMAIN</DOMAIN_NAME>
        <APP_NODES>$HOST_LISTS</APP_NODES>
</config>" > $file

    echo "config file create :$file"
    fi

}

COMMAND=$1
shift

if [ "$COMMAND" = "-h" ] ; then 
   echo "usetag:set <-vip vip>   <-nip ip1,ip2,ip3> <-akip akserverIp>"
  exit 0
fi
writeToFile

if [ "$COMMAND" = "set" ] ; then 
   while [ $# -gt 1 ] ;  do
	    paramName=$1
	    shift
	    if [ "$paramName" = "-vip" -o "$paramName" = "--vip" ] ; then
	         checkParam $@
	        _NEBULA_VIP=$1
	        shift
	        sed -i -e "s/$NEBULA_VIP/$_NEBULA_VIP/" /etc/profile.d/1appenv.sh
	        sed -i -e "s/$NEBULA_VIP/$_NEBULA_VIP/" /etc/keepalived/keepalived.conf
	        IPNil=`echo $NEBULA_VIP |awk -F. '{print $4}'`
	        nIPNil=`echo $_NEBULA_VIP |awk -F. '{print $4}'`
	        sed -i -e "s/VI_$IPNil/VI_$nIPNil/" /etc/keepalived/keepalived.conf
	        sed -i -e "s/virtual_router_id.*$IPNil/virtual_router_id $nIPNil/" /etc/keepalived/keepalived.conf
	        
	        find $INSTALL_ROOT -name "*" | grep -E "\.xml|\.cfg|\.conf|\.sh|\.properties|\.config" 2>/dev/null |xargs grep -n "$HOST_OIP"|awk -F: '{print $1}'|xargs sed -i -e "s/$NEBULA_VIP/$_NEBULA_VIP/"
	        
	        systemctl daemon-reload
	        service keepalived restart
	        service haproxy restart
	        writeToFile
	        echo "Complete VIP changes, please manually restart the appropriate services"
	        $APP_BASE/install/host_firwalld.sh
	    fi
	    if [ "$paramName" = "-akip" -o "$paramName" = "--akip" ] ; then
	         checkParam $@
	        _AKSERVER_IP=$1
	        shift
	        sed -i -e "s/$AKSERVER_IP/$_AKSERVER_IP/" /etc/profile.d/1appenv.sh
	        service keepalived restart
	        service haproxy restart
	        writeToFile
	    fi
	    if [ "$paramName" = "-nip" -o "$paramName" = "--nip" ] ; then
	        checkParam $@
	        NODE_IPS=$1
	        shift
	        
	        #解析出主机名  
	        # export DOCKER_NETWORK_HOSTS="--add-host=A01:172.16.131.91 --add-host=A02:172.16.131.92 --add-host=A03:172.16.131.93 " 
	        HOSTARR=($DOCKER_NETWORK_HOSTS)
	        hostLen=${#HOSTARR[@]}
	        HOST_NAMES=
	        NODE_IPS=${NODE_IPS//,/ }
	        HOST_IPS=($NODE_IPS)
	        
	        ipLen=${#HOST_IPS[@]}
	        
	        if [ $hostLen -ne  $ipLen ] ; then 
	            echo "host szie[$hostLen] not eq ip size[$ipLen]"
	            exit 1
	        fi 
	               echo "hostLen=$hostLen"
	        for ((i=0; i <hostLen;i++ )) do
	            hostName=${HOSTARR[i]}
	              echo "hostName=$hostName"
	            hostName=${hostName//--add-host=/}
	             echo "hostName=$hostName"
	            HOST_OIP=${hostName//*:/}
	            hostName=${hostName//:*/}
	            HOST_NAMES[$i]=$hostName
	            
	            HOST_NIP=${HOST_IPS[$i]} 
	            echo "hostName=$hostName  HOST_OIP=$HOST_OIP HOST_NIP=$HOST_NIP"
	            sed -i -e "s/$HOST_OIP/$HOST_NIP/" /etc/profile.d/1appenv.sh
	
	            cfgFiles=$(find $INSTALL_ROOT -name "*" |grep -v "${DATA_BASE}" | grep -E "\.xml|\.cfg|\.conf|\.sh|\.properties|\.config" |xargs grep -n "$HOST_OIP"|awk -F: '{print $1}')
	            OLDIFS=$IFS
	            IFS="
"
	            for cfgFile in $cfgFiles ; do
	                echo "========$cfgFile "
	                echo " sed -i -e \"s/$HOST_OIP/$HOST_NIP/\" $cfgFile "
	            	  sed -i -e "s/$HOST_OIP/$HOST_NIP/" $cfgFile
	            done
	            IFS="$OLDIFS"
	            
				for cfgFile in /etc/keepalived/keepalived.conf /etc/haproxy/haproxy.cfg /etc/hosts /etc/profile.d/*.sh $APP_ETC/* ${APP_BASE}/install/cluster.cfg /var/named/sobey.com.pf.zones ; do
					echo "========$cfgFile "
	                echo " sed -i -e \"s/$HOST_OIP/$HOST_NIP/\" $cfgFile "
	            	sed -i -e "s/$HOST_OIP/$HOST_NIP/" $cfgFile
				done

	        done
	        systemctl daemon-reload
	        service keepalived restart
	        service haproxy restart
	        service docker restart
	        
	        $APP_BASE/install/host_firwalld.sh

	        # 不能直接删除全部, 如果有其它应用的容器未纳入管理，且不需要重新run或没有run脚本，删除后则丢失了
	        # docker ps -a|grep -v CONTAINER|awk '{print $1}' |xargs docker rm -f 
	        for app in `cat $LOGS_BASE/docker/docker_containers ` ; do
			    echo "rm docker container  $app"
			    docker rm -f $app
			done
			echo "exec all docker run command "
			for runFile in `ls $APP_BASE/install/*/*-run.sh ` ; do
			    echo "re run docker container  $runFile"
			    $runFile
			done
	    fi
	done
fi

 