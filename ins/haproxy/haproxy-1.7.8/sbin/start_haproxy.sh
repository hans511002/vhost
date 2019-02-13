#! /bin/bash

echo "****************************"
echo "正在启动Haproxy........."
echo "****************************"
service haproxy stop
sleep 1
service haproxy start

echo "****************************"
echo "Haproxy启动中，请稍等...."
echo "****************************"

exit 0

