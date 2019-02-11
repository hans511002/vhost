#!/bin/bash
. /etc/bashrc
. /etc/profile.d/app_hosts.sh
. ${APP_BASE}/install/funs.sh

if [ "`check_app keepalived`" = "true" ]; then
    if [ "${keepalived_hosts//$HOSTNAME,/}" != "$keepalived_hosts" ] ; then
        ping $NEBULA_VIP -c 1 2>&1
        if [ "$?" != "0" ] ; then
            service keepalived restart
        fi
    fi
fi
