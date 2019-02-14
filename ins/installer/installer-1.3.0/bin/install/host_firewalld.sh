#!/bin/bash


. /etc/profile.d/1sobeyhive.sh
. /etc/profile.d/1appenv.sh

. $APP_BASE/install/funs.sh

# 1.0 不安装 firewalld
if [ "$INSTALL_FIREWALLD" != "true" ] ; then
    systemctl stop firewalld
    systemctl disable firewalld
    exit 0
fi

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$CLUSTER_HOST_LIST" = "" -o "$CLUSTER_IP_LIST" = "" ] ; then
    echo "evn CLUSTER_HOST_LIST or CLUSTER_IP_LIST is null,parse hostname ip form env DOCKER_NETWORK_HOSTS"
    CLUSTER_HOST_LIST=""
    CLUSTER_IP_LIST=""
    for HOSTIPNAME in ${DOCKER_NETWORK_HOSTS//--add-host=/ } ; do
        HOSTNAME=$(echo "$HOSTIPNAME" | awk -F: '{print $1}')
        HOSTIP=$(echo "$HOSTIPNAME" | awk -F: '{print $2}')
        CLUSTER_HOST_LIST="$CLUSTER_HOST_LIST $HOSTNAME"
        CLUSTER_IP_LIST="$CLUSTER_IP_LIST $HOSTIP" 
    done
fi

#其它系统服务设置
systemctl enable rc-local.service 2>/dev/null
systemctl stop NetworkManager
systemctl disable NetworkManager

#firewalld 配置
systemctl enable firewalld
dockerStatus=$(systemctl status docker |grep "Active: active (running)")
if [ "$dockerStatus" = "" ] ; then
systemctl restart firewalld
fi
firewalldStatus=`systemctl status firewalld|grep "active (running)"`
if [ "$firewalldStatus" = "" ] ; then
    echo "not starting firewalld, dot config"
    exit 0
fi


#设置主机间互信
DEFAULT_FIREWALLD_ZONE="public"

echo "firewall-cmd --set-default-zone=$DEFAULT_FIREWALLD_ZONE"
firewall-cmd --set-default-zone=$DEFAULT_FIREWALLD_ZONE

oldRichRUle=$(firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --list-rich-rule|grep "port port=\"1-65535\"")
oldIFS=$IFS
IFS="
"
echo "remove rich-rule : $oldRichRUle "
for RichRUle in $oldRichRUle ; do
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --remove-rich-rule="$RichRUle" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --remove-rich-rule="$RichRUle"  --permanent
done
IFS=$oldIFS

CLUSTER_HOSTS_LIST=(${CLUSTER_HOST_LIST//,/ })
CLUSTER_IPS_LIST=(${CLUSTER_IP_LIST//,/ })
HOST_COUNT=${#CLUSTER_HOSTS_LIST[@]}
echo "config cluster host mutual trust : ${CLUSTER_IPS_LIST[@]}"

## keepalived iptables 配置
#/sbin/iptables -A INPUT -i eth1 -d 224.0.0.0/8 -j ACCEPT 
#/sbin/iptables -A INPUT -i eth1 -p 112 -j ACCEPT 
# keepalived 多播包
#tcpdump -v -i eth1 host 224.0.0.18 
#tcpdump -vvv -n -i eth1 host 224.0.0.18

for ((i=0; i <HOST_COUNT;i++ )) do
    firewall-cmd --direct  --add-rule ipv4 filter INPUT 0   --protocol vrrp -j ACCEPT 
    firewall-cmd --direct  --add-rule ipv4 filter INPUT 0   --protocol 112 -j ACCEPT 
    firewall-cmd --direct  --permanent --add-rule ipv4 filter INPUT 0   --protocol vrrp -j ACCEPT 
    firewall-cmd --direct  --permanent --add-rule ipv4 filter INPUT 0   --protocol 112 -j ACCEPT 
                                                                        # -s 172.16.131.0/24
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${CLUSTER_IPS_LIST[$i]}" port protocol="tcp" port="1-65535"  accept" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${CLUSTER_IPS_LIST[$i]}" port protocol="tcp" port="1-65535"  accept" --permanent
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${CLUSTER_IPS_LIST[$i]}" port protocol="udp" port="1-65535"  accept" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${CLUSTER_IPS_LIST[$i]}" port protocol="udp" port="1-65535"  accept" --permanent
done
# vip 设置
if [ "$NEBULA_VIP" != "$PRODUCT_DOMAIN" ] ; then
    echo "config cluster host mutual trust : $NEBULA_VIP"
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${NEBULA_VIP}" port protocol="tcp" port="1-65535"  accept" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${NEBULA_VIP}" port protocol="tcp" port="1-65535"  accept" --permanent
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${NEBULA_VIP}" port protocol="udp" port="1-65535"  accept" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-rich-rule="rule family="ipv4" source address="${NEBULA_VIP}" port protocol="udp" port="1-65535"  accept" --permanent
fi

oldPorts=$( firewall-cmd --list-ports)
echo "remove ports: $oldPorts"
for PORT in $oldPorts ; do
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --remove-port="$PORT" 
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --remove-port="$PORT" --permanent
done


ExternalServicePort="22 53 80 86 88 48800 3306 3307 80-65535"
echo "config ports $ExternalServicePort"
for PORT in $ExternalServicePort ; do
    firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-port=$PORT/tcp
    firewall-cmd --permanent  --zone=$DEFAULT_FIREWALLD_ZONE --add-port=$PORT/tcp
done

# 因存在多网卡,不指定网卡与规则的绑定
if [ "$dockerStatus" = "" ] ; then
    echo "systemctl restart firewalld"
    systemctl restart firewalld
fi

echo "firewall-cmd --list-all"
firewall-cmd --list-all
# firewall-cmd --list-all-zone
echo " current open all ports , if your want to change  example:
close port:   firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --remove-port=\"80-63335/tcp\" 
open port:   firewall-cmd --zone=$DEFAULT_FIREWALLD_ZONE --add-port=80/tcp

"
exit 0
