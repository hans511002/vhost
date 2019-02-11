#!/bin/bash

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

cd $BIN

if [ `which named > /dev/null 2>&1; echo $?` = "0" -a "$1" != "true" ]; then
    ver1=`named -v 2>&1 | awk -F '[,_ ]' '{print $2}' `
    if [ "$ver1" = "9.12.1" ]; then
        echo "named -v: `named -v 2>&1 | awk -F '[,_ ]' '{print $2}'`"
        exit 0
    fi
fi

echo "install bind 9.12.1 for dns "
namedStatus=`systemctl  status named|grep Active|awk '{print $3}' | sed -e 's|(||' -e 's|)||' `
echo "tar xf bind.tar.gz"
tar xf bind.tar.gz
chmod +x -R usr/ 
if [ ! -f "/etc/named.conf" ] ; then
    scp etc/named.conf /etc/named.conf
fi
for varFile in 127.0.0.zone empty.zone localhost.ip6.zone localhost.zone root.hint ; do
    if [ ! -f "/var/named/$varFile" ] ; then
        echo "scp var/named/$varFile   /var/named/$varFile"
        scp var/named/$varFile   /var/named/$varFile
    fi
done
mkdir -p /etc/named

if [ "$namedStatus" = "running" ] ; then
    echo "systemctl stop named"
    systemctl stop named
fi
echo "scp -r usr / 2>&1 "
scpLog=`scp -r usr / 2>&1 |  awk -F\" '{print $2}'`
for file in $scpLog ; do
    systemctl stop named
    echo "scp ${file:1}  $file"
    scp ${file:1}  $file
done
echo "/bin/install -c -m 0755 -s usr/bin/nsupdate /usr/bin/nsupdate" 
/bin/install -c -m 0755 -s usr/bin/nsupdate /usr/bin/nsupdate
/bin/install -c -m 0755 -s usr/sbin/named /usr/sbin/named

systemctl daemon-reload
chown -R named:root /var/named/


#set ipv4 only
if [ -f "/etc/sysconfig/named" ]; then
    sed -i '/^OPTIONS/d' /etc/sysconfig/named
    echo 'OPTIONS="-4"' >>/etc/sysconfig/named
fi

if [ "$namedStatus" = "running" ] ; then
    echo "systemctl restart named"
    systemctl restart named
fi
if [ "`pwd`" != "/" ] ; then
    rm -rf etc/ usr/ var/
fi
echo "install bind end "
