#!/bin/bash

if [ $# -lt 1 ]
then
    echo "use tag name jps/ps"
    exit
fi

. ~/.bash_profile

PROCESSNAME=$1
if [ $# -gt 1 ]
then
    LISTNAME=$2
else
LISTNAME="jps"
fi

if [ "$LISTNAME" == "ps" ]; then
LISTNAME="ps -e"
fi

echo " kill -9 $PROCESSNAME"
if [ "$LISTNAME" == "jps" ] ; then
$LISTNAME | grep  "$PROCESSNAME" | awk '{if($2=="'$PROCESSNAME'") { system(sprintf("kill -9 %s", $1)); } }'
else
echo $LISTNAME |grep  $PROCESSNAME | awk '{{ system(sprintf("kill -9 %s", $2)); } }'
fi
