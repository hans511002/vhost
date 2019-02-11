#!/bin/bash
#desc:installer auto build
. /etc/bashrc
 
yum install -y squid
if [ "$?" != "0" ] ; then
    echo "install http proxy squid failed"
    exit 1
fi
IPNetPRI="`echo $LOCAL_IP |sed -e 's|\..*||'`.0.0.0/8"

sed -i -e "/acl localnet src 10.0.0.0\/8.*/aacl localnet src $IPNetPRI" -e "s|#cache_dir ufs|cache_dir ufs|" \
-e "/cache_dir ufs.*/acache_mem 512 MB " /etc/squid/squid.conf 

systemctl enable squid 
service squid start
# squid -N -d1

http_port=`cat /etc/squid/squid.conf |grep http_port |awk '{print $2}' `
echo "echo \"export http_proxy=http://$LOCAL_IP:$http_port/\" >> /etc/profile "
export http_proxy=http://$LOCAL_IP:$http_port/
