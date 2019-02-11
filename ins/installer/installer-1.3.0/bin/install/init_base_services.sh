#!/bin/bash
. /etc/bashrc
. /etc/profile.d/1appenv.sh

BIN=$(cd $(dirname $0); pwd)
cd $BIN

#if [ "`ls /dev/sobey/hive >/dev/null`" != "" ] ; then
#    mv -f $APP_BASE/install/appDisk.mount /usr/lib/systemd/system/appDisk.mount
#    systemctl enable appDisk.mount
#    systemctl daemon-reload
#fi

if [ -e "$APP_BASE/install/shostname.service"  ] ; then
    mv -f $APP_BASE/install/shostname.service /usr/lib/systemd/system/shostname.service
    systemctl enable shostname.service
    systemctl daemon-reload
fi
if [ -e "$APP_BASE/install/appservice.service"  ] ; then
    sed -e "s|sobeyhive.sh|appservice.sh|g" /usr/lib/systemd/system/appservice.service
    mv -f $APP_BASE/install/appservice.service /usr/lib/systemd/system/appservice.service
    systemctl daemon-reload
    systemctl disable appservice.service
fi
if [ -e "$APP_BASE/install/deploy.service"  ] ; then
    mv -f $APP_BASE/install/deploy.service /usr/lib/systemd/system/deploy.service
    systemctl daemon-reload
    systemctl disable deploy.service
fi
if [ -e "$APP_BASE/install/deploy.sh"  ] ; then
    mv -f $APP_BASE/install/deploy.sh /etc/init.d/deploy.sh
    chmod +x /etc/init.d/deploy.sh
fi

if [ -f "$APP_BASE/install/netpcap/netpcap_install.sh" ] ; then
    $APP_BASE/install/netpcap/netpcap_install.sh
    systemctl stop netpcap
    systemctl stop netpcapdeamon
    systemctl disable netpcap
    systemctl disable netpcapdeamon
fi

systemctl daemon-reload
