#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ $# -lt 3 ] ; then
	echo user type[0|1] dir ...
	exit 1
fi

APP_USER=$1
shift

id $APP_USER

if [ "$?" != "0" ] ; then
    echo "user not exists :$APP_USER "
    exit 1
fi

while [ "$#" -gt "0" ]  ;  do
    dir=$1
    shift
    type=$1
    shift
    if [ ! -e "$dir" ] ; then
        mkdir -p $dir
    fi
    if [ "$type" = "1" ] ; then
        echo "chown  ${APP_USER}:${APP_USER} -R $dir"
        chown  ${APP_USER}:${APP_USER} -R $dir
    elif [ "$type" = "2" ] ; then
        echo "chmod 1777  $dir"
        chmod 1777  $dir
    elif [ "$type" = "3" ] ; then
        echo "chmod 1777 -R $dir"
        chmod 1777 -R $dir
    fi
done

exit 0
