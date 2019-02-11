#!/usr/bin/env bash
# 
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

testProcess(){
 kill -0 $1
 if [ "$?" = "0" ] ; then
    echo true
 else
   echo false
 fi
}
NETPCAP_PID=
 

while true ;  do
    /bin/systemctl status netpcap 
    if [ "$?" -ne "0" ] ; then
        systemctl start netpcap 
    fi
    sleep 2
    NETPCAP_PID=`systemctl status netpcap |grep "Main PID:"|awk '{print $3}'`
    echo "NETPCAP_PID=$NETPCAP_PID"
    if [ "$NETPCAP_PID" = "" ] ; then
        continue
    fi
    while [ `testProcess $NETPCAP_PID` = "true" ] ;  do
        sleep 2
        done
done
