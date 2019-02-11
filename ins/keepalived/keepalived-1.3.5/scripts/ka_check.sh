#!/bin/bash
. /etc/bashrc

if [ "$haproxy_hosts" = "${haproxy_hosts//$HOSTNAME/}" ] ; then
    exit 0
else
    if [ -n "`ps -ef | grep '/usr/sbin/haproxy' | grep -v grep`" ]; then
        exit 0
    else
        exit 1
    fi
fi
