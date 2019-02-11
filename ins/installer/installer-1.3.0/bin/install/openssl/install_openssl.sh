#!/bin/bash
#modify: hehaiqiang

if [ "$1" != "true" ]; then
    exit 0
fi

bin=$(cd $(dirname $0); pwd)
modifyDate=`date "+%Y-%m-%d-%H:%M:%S"`

if [ `which openssl > /dev/null 2>&1; echo $?` = "0" ]; then
    ver1=`openssl version|awk -F'[ -]' '{print $2}'`
    if [ "$ver1" = "1.0.2l" -o "$ver1" = "1.0.2k" ]; then
        echo "`openssl version`"
        exit 0
    fi
fi

tar -xf $bin/openssl-1.0.2l.tar.gz -C /usr/local/

#backup
mv /usr/bin/openssl /usr/bin/openssl.old.$modifyDate 2>/dev/null
mv /usr/include/openssl /usr/include/openssl.old.$modifyDate 2>/dev/null

#ln -s
ln -s /usr/local/ssl/bin/openssl /usr/bin/openssl 
ln -s /usr/local/ssl/include/openssl /usr/include/openssl
sed -i '/\/usr\/local\/ssl\/lib/d' /etc/ld.so.conf
echo "/usr/local/ssl/lib" >> /etc/ld.so.conf 

echo -n "openssl version: "
openssl version

echo "openssl installed!"