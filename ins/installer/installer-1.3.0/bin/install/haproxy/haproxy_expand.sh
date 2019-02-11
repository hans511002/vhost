#! /bin/bash

if [ $# -lt 2 ] ; then 
  echo "usetag:haproxy_expand.sh CLUSTER_HOST_LIST EXPAND_HOSTS_LIST"
  exit 1
fi

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

. ${APP_BASE}/install/funs.sh
CLUSTER_HOST_LIST=$1
CLUSTER_HOST_LIST="${CLUSTER_HOST_LIST//,/ }"


EXPAND_HOSTS_LIST=$2
EXPAND_HOSTS_LIST="${EXPAND_HOSTS_LIST//,/ }"

NEW_HOST_ONE=$(echo "$EXPAND_HOSTS_LIST" |awk '{print $1}')

$BIN/haproxy_reset.sh true


. /etc/profile.d/dns.sh 

if [  "$INSTALL_DNS" = "true"  -a "`isDnsHaHost`" = "true" ] ; then
    clusIpLists=`getDnsIpList`
    clusHostLists=`getDnsHostList`
    if [ "$clusHostLists" = "" ] ; then
        echo "config install dns ,but not dns host to install:=clusHostLists=$clusHostLists "
        exit 1
    fi    
    echo "export dns_hosts=\"$clusHostLists\"
export dns_ips=\"$clusIpLists\"
" > /etc/profile.d/dns.sh
    for HOST in $CLUSTER_HOST_LIST ; do
        scp /etc/profile.d/dns.sh $HOST:/etc/profile.d/dns.sh
    done

#export dns_hosts="hivenode01 hivenode02 hivenode03"
#export dns_ips="172.16.131.131 172.16.131.132 172.16.131.133"
    # if [ "${clusHostLists/$LOCAL_HOST/}" != "$clusHostLists" -a "${dns_hosts/$LOCAL_HOST/}" = "$dns_hosts"    ] ; then
    # fi
    # firstIp=$(echo "${clusIpLists//,/ }" | awk '{print $1}') 
    # ipPriex=$(echo "$firstIp" | awk -F. '{printf("%s.%s.%s" ,$1,$2,$3)}') 
    # IPIDS=""
    # for tip in ${clusIpLists//,/ } ; do
        # if [ "$IPIDS" = "" ] ; then  
            # tipId=$(echo "$tip" | awk -F. '{ print $4 }') 
            # IPIDS="$tipId"
        # else
            # tipId=$(echo "$tip" | awk -F. '{ print $4 }') 
            # IPIDS="$IPIDS,$tipId"
        # fi
    # done
    # echo "config domain .....$PRODUCT_DOMAIN............."
    # proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}') 
    # rootDomain=${PRODUCT_DOMAIN/$proDomain./}
    # echo "rootDomain=$rootDomain"

    # DNS_STATUS=""
    # for OLDHOST in ${CLUSTER_HOST_LIST//$EXPAND_HOSTS_LIST/} ; do
         # DNS_STATUS="true $DNS_STATUS"
    # done
    
    for NEWHOST in $EXPAND_HOSTS_LIST ; do
        echo "======================================================================
        ssh $NEWHOST ${APP_BASE}/install/dns_config.sh \"'$clusIpLists'\" \"'$clusHostLists'\" \"$PRODUCT_DOMAIN\"
        =========================================================================="
        ssh $NEWHOST ${APP_BASE}/install/dns_config.sh \"$clusIpLists\" \"$clusHostLists\" \"$PRODUCT_DOMAIN\" 
        if [ $? -ne 0 ];then
            echo "dns config failed "
            exit 1
        fi
        # DNS_STATUS="$DNS_STATUS false"
    done
    # for NEWHOST in $EXPAND_HOSTS_LIST ; do
        # echo "ssh $NEWHOST echo \\\"$DNS_STATUS\\\" \\>\\>/tmp/dns_state" 
        # ssh $NEWHOST echo \"$DNS_STATUS\" \>\>/tmp/dns_state
        # ssh $NEWHOST ${APP_BASE}/install/dns_ddns.sh
    # done
    
fi
#
#for HOST in $CLUSTER_HOST_LIST ; do
#	echo "$HOST exec: $BIN/haproxy_reset.sh \"$NEBULA_VIP\" \"$CLUSTER_HOST_LIST\"   "
#    ssh $HOST "$BIN/haproxy_reset.sh \"$NEBULA_VIP\" \"$CLUSTER_HOST_LIST\"  "
#done

exit $?
