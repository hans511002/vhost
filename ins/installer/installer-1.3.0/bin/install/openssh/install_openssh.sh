#!/bin/bash
#author: hehaiqiang

. /etc/bashrc
bin=$(cd $(dirname $0); pwd)

version="7.7p1"
rpmDir=rpm-${version}

if [ `which ssh > /dev/null 2>&1; echo $?` = "0" ]; then
    ver1=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $1}'`
    ver2=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $2}'`
    ver3=`echo $version|awk -F 'p' '{print $1}'`
    if [ `echo "${ver1:0:3} >= $ver3"|bc` = 1 ]; then
        echo "ssh -V: `ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}'`"
        exit 0
    fi
fi

echo "begin install openssh"
yum install -y $bin/$rpmDir/* || (echo "exec failed: yum install -y $bin/$rpmDir/*" && exit 1) || exit 1
if [ "$version" = "7.5p1" ]; then
    if [ -f "/etc/ssh/sshd_config.bak" ]; then
        cp -rp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        sed -i '/^GSSAPICleanupCredentials/s/GSSAPICleanupCredentials/#GSSAPICleanupCredentials/' /etc/ssh/sshd_config
        sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication/#GSSAPIAuthentication/' /etc/ssh/sshd_config
        sed -i '/^GSSAPIAuthentication/s/GSSAPIAuthentication/#GSSAPIAuthentication/' /etc/ssh/sshd_config
        sed -i '/^UsePrivilegeSeparation/s/UsePrivilegeSeparation/#UsePrivilegeSeparation/' /etc/ssh/sshd_config
        sed -i '/^PermitRootLogin/s/PermitRootLogin/#PermitRootLogin/' /etc/ssh/sshd_config
        sed -i '$a PermitRootLogin yes' /etc/ssh/sshd_config
        sed -i '$a ClientAliveInterval 60' /etc/ssh/sshd_config
    fi
    if [ -f "/etc/pam.d/sshd.bak" ]; then
        cp -rp /etc/pam.d/sshd.bak /etc/pam.d/sshd
    fi
    if [ -f "/etc/rc.d/init.d/sshd" ]; then
        sed -i 's|/sbin/restorecon /etc/ssh/ssh_host_key.pub||' /etc/rc.d/init.d/sshd
        systemctl daemon-reload
    fi
    systemctl restart sshd || service sshd restart  
fi
echo "openssh install completed!"







