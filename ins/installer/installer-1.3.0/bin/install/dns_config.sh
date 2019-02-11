#!/bin/bash
. /etc/bashrc
. $APP_BASE/install/funs.sh
bin=$(cd $(dirname $0); pwd)

if [ "$INSTALL_DNS" != "true" ] ; then
    exit 0
fi

if [ "$#" != "3" ] ; then
    echo "Usage: $0 \"172.16.131.131,172.16.131.132,172.16.131.133\" \"node01,node02,node03\" \"pf.ery.com\""
    exit 1
fi

dnsIPs=$1
dnsHosts=$2
PRODUCT_DOMAIN=$3
dnsIPs=`echo "$dnsIPs" | awk -F '[,; ]+' '{$1=$1; print $0}'`
dnsHosts=`echo "$dnsHosts" | awk -F '[,; ]+' '{$1=$1; print $0}'`
proDomain=${PRODUCT_DOMAIN%%.*}
rootDomain=${PRODUCT_DOMAIN#*.}

systemctl stop appdns >/dev/null 2>&1
systemctl stop named >/dev/null 2>&1
mkdir -p ${APP_BASE}/install/haproxy
echo "$bin/${0##*/} \"$1\" \"$2\" \"$3\"" > ${APP_BASE}/install/haproxy/dns_reset.sh
chmod +x ${APP_BASE}/install/haproxy/dns_reset.sh


getHostIPFromPing(){
    thisIP=$(ping $1 -c 1  -W 1 | grep "icmp_seq" |grep from|sed -e 's|.*(||' -e 's|).*||')
    if [ "$thisIP" = "" ] ; then
        thisIP=$(ping $1 -c 1 -W 1 | grep "bytes of data" |awk  '{print $3}'|sed -e 's|.*(||' -e 's|).*||')
    fi
    echo "$thisIP"
}

namedPath=`which named 2>/dev/null `
if [ "$namedPath" = "" ] ; then
    packages="bind* bind-utils"
    yum install -y $packages
    res=$?
    tryTimes=0
    while [ $res -ne 0 ]; do
        error_package=`yum install -y $packages 2>&1 | grep "Error: Package:"`
        rpmdb_problem=`yum install -y $packages 2>&1 | grep "rpmdb problem"`
        if [ -n "$error_package" ];then
            error_package=`yum install -y $packages 2>&1 | grep "Installed:" | awk -F '(' '{print $1}' | awk -F 'Installed: ' '{print $NF}'`
            yum remove -y $error_package
        fi

        if [ -n "$rpmdb_problem" ];then
            rpmdb_problem=`yum install -y $packages 2>&1 | grep "has missing requires of" | awk -F 'has missing requires of ' '{print $NF}' | awk -F '[>=(]' '{print $1}'`
            if [ -n "$rpmdb_problem" ];then
                yum install -y $rpmdb_problem
            fi

            rpmdb_problem=`yum install -y $packages 2>&1 | grep "is a duplicate with" | grep -v "yum" | awk -F 'is a duplicate with ' '{print $NF}' | awk '{print $1}'`
            if [ -n "$rpmdb_problem" ];then
                yum remove -y $rpmdb_problem
            fi
        fi
        ((tryTimes++))
        yum install -y $packages
        res=$?
        if [ $res -ne 0 -a "$tryTimes" -gt "3" ];then
            echo "exec failed: yum install -y $packages"
            exit 1
        fi
    done
fi

if [ -f "$APP_BASE/install/bind/bind_install.sh" ] ; then
    $APP_BASE/install/bind/bind_install.sh
fi

sed -i 's#listen-on port 53 { 127.0.0.1; };#listen-on port 53 { any; };#' /etc/named.conf
sed -i 's#listen-on-v6 port 53 { ::1; };#//listen-on-v6 port 53 { ::1; };#' /etc/named.conf
sed -i 's#//.*listen-on-v6 port 53 { ::1; };#//listen-on-v6 port 53 { ::1; };#' /etc/named.conf
sed -i 's#allow-query     { localhost; };#allow-query     { any; };#' /etc/named.conf

# echo "====================forwarders===================="
# rrsetOrder=$(grep "forwarders {" /etc/named.conf )
# if [ "$rrsetOrder" = "" ] ; then
    # forwarders="        forwarders {\\
                # 223.5.5.5;\\
                # 223.6.6.6;\\
            # };"
    # sed -i "/.*allow-query     { any; };*/a\\$forwarders"  /etc/named.conf
# fi

echo "===========forwarders================="
FORWARDERS=$(cat /etc/resolv.conf|grep -v localhost |grep  -E "^nameserver"|sed -e 's|nameserver|\n|')
rrsetOrder=$(grep "forwarders {" /etc/named.conf )
if [ "$rrsetOrder" = "" ] ; then
        HOSTIP=`hostname -I`
    forwarders="        forwarders {"
    for dnsip in $FORWARDERS ; do
        if [ "${HOSTIP//$dnsip/}" = "${HOSTIP}" ] ; then
            forwarders="$forwarders\\
            $dnsip;"      
        fi
    done
    forwarders="$forwarders };"
    echo "FORWARDERS=$forwarders"      
    sed -i "/.*allow-query     { any; };*/a\\$forwarders"  /etc/named.conf  
fi

sed -i -e "s|dnssec-enable.*|dnssec-enable no;|" /etc/named.conf
sed -i -e "s|dnssec-validation.*|dnssec-validation no;|" /etc/named.conf

#判断是否存在，不存在添加到 allow-query 下一行 fixed random  cyclic
echo "===========rrsetOrder================="
rrsetOrder=$(grep "type A name \"${PRODUCT_DOMAIN}\"" /etc/named.conf )
if [ "$rrsetOrder" = "" ] ; then
    rrsetOrder=$(grep 'rrset-order {' /etc/named.conf )
    if [ "$rrsetOrder" = "" ] ; then
        rrsetOrder="        rrset-order {\\
            class IN type A name \"${PRODUCT_DOMAIN}\" order random;\\
            order cyclic;\\
        };"
         echo "rrsetOrder=$rrsetOrder
        =================================="
        sed -i "/.*allow-query .*{.*/a\\$rrsetOrder"  /etc/named.conf
    elif [ "${rrsetOrder/\};/}" = "$rrsetOrder" ] ; then
        rrsetOrder="            class IN type A name \"${PRODUCT_DOMAIN}\" order cyclic;"
        sed -i "/.*$rrsetOrder.*/a\\$rrsetOrder"  /etc/named.conf
        echo "rrsetOrder=$rrsetOrder
        =================================="
    else
        sed -i -e "s/$rrsetOrder//"  /etc/named.conf
        oldOrder=`echo "$rrsetOrder"|sed -e 's|rrset-order {||'  `
        oldOrder="${oldOrder/\};/}"
        rrsetOrder="        rrset-order {\\
            class IN type A name \"${PRODUCT_DOMAIN}\" order cyclic;\\
            $oldOrder\\
        };"
         echo "rrsetOrder=$rrsetOrder
        =================================="
        sed -i "/.*allow-query .*{.*/a\\$rrsetOrder"  /etc/named.conf
    fi
fi

DN_NAMED_FILE="/etc/named/$rootDomain.key"
echo "===========$DN_NAMED_FILE================="
rrsetOrder=$(grep "$DN_NAMED_FILE" /etc/named.conf )
if [ "$rrsetOrder" = "" ] ; then
    echo "include \"$DN_NAMED_FILE\";" >> /etc/named.conf
fi

cd /var/named/
rm -rf /var/named/K$rootDomain.*.private /var/named/K$rootDomain.*.key
rm -rf /var/named/${rootDomain}.zone*
#dnssec-keygen -r /dev/urandom -a HMAC-MD5 -b 512 -n HOST $rootDomain
#priKey=`cat K$rootDomain.*.private|grep Key:|sed -e 's|Key: ||'`
priKey="vQ9U23WtJg2C9RaEItv42AaI/aECSiKW7oszg6IWQFoyQ49Rex/KRl3PWaBdLyty/ofaYhy/DxvjnP2T7HEFcw=="

chown named:named -R /var/named
setsebool named_write_master_zones true

DNSKEY_NAME=${rootDomain//./}
echo "===========name dns ================="
if [ -f "/var/named/${rootDomain}.dns"  ] ; then
    echo "zone \"${PRODUCT_DOMAIN}\" IN {"> $DN_NAMED_FILE
else
    echo "zone \"${rootDomain}\" IN {"> $DN_NAMED_FILE
fi
echo "     type master;">> $DN_NAMED_FILE
echo "     file \"${rootDomain}.zone\";
     allow-update { any; };
     allow-query { any; };
     notify yes;
};
" >> $DN_NAMED_FILE

#反向解析配置
# for hostIP in ${dnsIPs}; do
    # arpaID=`echo $hostIP | awk -F. '{print $3"."$2"."$1}'`
    # arpaIDs=$arpaIDs
    # [[ "$arpaIDs" =~ "$arpaID" ]] && arpaIDs=$arpaIDs || arpaIDs="$arpaIDs $arpaID"
    # echo "arpaIDs=$arpaIDs"
# done

# for arpaID in $arpaIDs; do
    # ID=`echo $arpaID | awk -F. '{print $3"."$2"."$1}'`
# echo "
# zone \"${arpaID}.in-addr.arpa\" IN {
    # type master;
    # file \"${ID}.zone\";
    # allow-update { any; };
    # allow-query { any; };
# };
# " >> $DN_NAMED_FILE
# done

echo "
key \"$DNSKEY_NAME\" {
    algorithm hmac-md5;
    secret \"$priKey\";
};
" >> $DN_NAMED_FILE

nsFile="/var/named/${rootDomain}.zone"
ipFile="/var/named/${rootDomain}.zone.loopback"

echo "\$TTL 5s
@    IN   SOA   ${rootDomain}.   ns.${rootDomain}. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum" > $nsFile

echo "@               IN    NS      ns.${rootDomain}.">> $nsFile

for hostIP in ${dnsIPs}; do
    echo "ns             IN    A       $hostIP" >> $nsFile
done

if [ -f "/var/named/${rootDomain}.dns" ] ; then
    for hostIP in ${dnsIPs}; do
        echo "@             IN    A       $hostIP" >> $nsFile
    done
fi

for hostIP in ${dnsIPs}; do
    echo "$proDomain            IN    A      $hostIP" >> $nsFile
done

echo "config apps dns : $ALL_APP"
for appName in ${ALL_APP//,/ } ; do
    appHosts="${appName}_hosts"
    _appHosts=`env |grep -E "^${appHosts}=" | sed -e "s|${appHosts}=||" `
    if [ "$_appHosts" = "" ] ; then
        if [ -f "${APP_BASE}/install/cluster.cfg" ] ; then
             _appHosts=`cat ${APP_BASE}/install/cluster.cfg|grep "app.$appName.install.hosts=" |awk -F= '{print $2}'`
             if [ "$_appHosts" = "" ] ; then
                _appHosts=`cat ${APP_BASE}/install/cluster.cfg|grep "cluster.$appName.install.hosts=" |awk -F= '{print $2}'`
             fi
        fi
    fi
    appName=${appName/_docker/}
    if [ "$_appHosts" = "" ] ; then
        continue
    fi

    #只保留registry
    if [ "$appName" != "registry" ] ; then
        continue
    fi

    echo "config app $appName dns:$_appHosts"
    for HOST in ${_appHosts//,/ } ; do
        HOSTIP=`getHostIPFromPing $HOST`
        echo "$appName            IN    A      $HOSTIP " >> $nsFile
    done
done

#添加反向解析
# thisHostIndex=0
# for HOST in ${dnsHosts} ; do
    # ((thisHostIndex++))
    # if [ "`hostname`" = "$HOST" ] ; then
        # break
    # fi
# done

# for arpaID in $arpaIDs; do
    # ID=`echo $arpaID | awk -F. '{print $3"."$2"."$1}'`
    # arpaFile="/var/named/${ID}.zone"

# echo "\$TTL 5s
# @    IN   SOA   ${rootDomain}.   ns.${rootDomain}. (
                                        # $(date +%s)     ; serial
                                        # 60      ; refresh
                                        # 1H      ; retry
                                        # 1W      ; expire
                                        # 3H )    ; minimum" > $arpaFile
# echo "@               IN    NS      ns${thisHostIndex}.${rootDomain}.">> $arpaFile

    # for hostIP in ${dnsIPs}; do
        # ipId=${hostIP##*.}
        # IDaaa=`echo $hostIP | awk -F. '{print $1"."$2"."$3}'`
        # [[ "$ID" = "$IDaaa" ]] || continue
        # echo "$ipId            IN   PTR      ${PRODUCT_DOMAIN}." >> $arpaFile
    # done
# done

OLD_DNS=`cat /etc/resolv.conf|grep "^nameserver"|uniq`
echo ";generated by app ">/etc/resolv.conf
if [ "$NEBULA_VIP" = "$PRODUCT_DOMAIN" -o "`check_app keepalived`" = "false" ] ; then
    for hostIP in ${dnsIPs}; do
        echo "nameserver $hostIP" >>/etc/resolv.conf
    done
else
    echo "nameserver $NEBULA_VIP" >>/etc/resolv.conf
fi

for hostIP in ${dnsIPs}; do
   OLD_DNS=`echo "$OLD_DNS" |grep -v $hostIP`
done

OLD_DNS=`echo "$OLD_DNS" |grep -v $NEBULA_VIP`
echo "$OLD_DNS" >> /etc/resolv.conf

cat $nsFile > $nsFile.bak
mkdir -p ${LOGS_BASE}/haproxy/
scp $nsFile ${LOGS_BASE}/haproxy/${nsFile##*/}.$(date +%Y%m%d)

echo "systemctl restart named"
systemctl enable named
systemctl restart named

if [ ! -e /etc/profile.d/dns.sh ] ; then
clusIpLists=""
for hostIP in ${dnsIPs}; do
    if [ "$clusIpLists" = "" ] ; then
        clusIpLists="$hostIP"
    else
        clusIpLists="$clusIpLists,$hostIP"
    fi
done

clusHostLists=""
for host in ${dnsHosts}; do
    if [ "$clusHostLists" = "" ] ; then
        clusHostLists="$host"
    else
        clusHostLists="$clusHostLists,$host"
    fi
done

echo "export dns_hosts=\"$clusHostLists\"
export dns_ips=\"$clusIpLists\"
" > /etc/profile.d/dns.sh
fi




