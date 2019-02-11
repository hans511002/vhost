#!/bin/bash 
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
for i in /etc/profile.d/*.sh; do
    if [ -r "$i" ]; then
        if [ "$PS1" ]; then
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done 
#if [ -f /dev/appvg/applv ] ; then  
#    if [ `cat /etc/mtab |grep "/app" |wc -l` -eq 0 ] ; then
#        mount /dev/appvg/applv /app
#    fi
#fi 

. ${APP_BASE}/install/funs.sh
diskRoot=`df /  |grep -v 1K |sed  -e 's|%||'|awk '{printf("%s ",$5)}'`
insRoot=`df $INSTALL_ROOT  |grep -v 1K |sed  -e 's|%||'|awk '{printf("%s ",$5)}'`
appSize=`du -shm $APP_BASE |awk '{print($1)}'`

exit 0

count=0
while true ;  do
    ((count++))
    if [ "$count" -gt "60" ] ; then
        count=0
        sleep 1 
    fi
    sleep 10
done

