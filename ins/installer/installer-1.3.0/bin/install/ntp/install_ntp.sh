#!/bin/bash
#author: hehaiqiang

. /etc/bashrc

bin=$(cd $(dirname $0); pwd)

if [ `which ntpq > /dev/null 2>&1; echo $?` = "0" ]; then

    ver1=`ntpq --version | awk -F '[ @]+' '{print $2}' | awk -F 'p' '{print $1}'`
    ver2=`ntpq --version | awk -F '[ @]+' '{print $2}' | awk -F 'p' '{print $2}'`
    if [ "$ver1" = "4.2.8" ]; then
        if [ "$ver2" = "10" ]; then
            echo "ntpq --version: `ntpq --version | awk -F '[ @]+' '{print $2}'`"
            exit 0
        fi
    fi
    echo "begin install ntp"
    systemctl stop ntpd || service ntpd stop
    yum remove -y ntp ntpdate
fi

#userdel ntp
ntpUser=`cat /etc/passwd | awk -F ':' '{ print $1}' | grep "^ntp$"`
if [ -n "$ntpUser" ]; then
    userdel ntp
fi

#groupdel ntp
ntpGroup=`cat /etc/group | awk -F ':' '{ print $1}' | grep "^ntp$"`
if [ -n "$ntpGroup" ]; then
    groupdel ntp
fi

if [ -d "/var/lib/ntp" ]; then
    rm -rf /var/lib/ntp
fi

if [ -f "/var/spool/mail/ntp" ]; then
    rm -rf /var/spool/mail/ntp
fi

cd $bin
tar -xf ntp.tar.gz
bin="$bin/ntp"
cd $bin
#begin install
groupadd -g 87 ntp &&
useradd -c "Network Time Protocol" -d /var/lib/ntp -u 87 -g ntp -s /bin/false ntp
install -v -o ntp -g ntp -d /var/lib/ntp

chmod 755 $bin/sbin/*
scp -rp $bin/sbin/* /usr/sbin

chmod 755 $bin/bin/*
scp -rp $bin/bin/* /usr/bin

chmod -R 644 $bin/etc/*
scp -rp $bin/etc/ntp.conf /etc/
scp -rp $bin/etc/sysconfig/ntpd /etc/sysconfig

chmod 644 $bin/system/ntpd.service
scp -rp $bin/system/ntpd.service /usr/lib/systemd/system/

chmod -R 755 $bin/share
scp -rp $bin/share/*  /usr/share/

chmod 644 $bin/var/drift
scp -rp $bin/var/drift /var/lib/ntp

systemctl enable ntpd
systemctl start ntpd

echo "ntp installed!"



