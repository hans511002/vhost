#! /bin/bash

echo "****************************"
echo "正在启动Keepalived........."
echo "****************************"
service keepalived stop
sleep 3
service keepalived start
exit $?
