#! /bin/bash

. /etc/bashrc

#获取当前目录
HAPROXY_APP_HOME=`dirname "${BASH_SOURCE-$0}"`
HAPROXY_APP_HOME=`cd "$HAPROXY_APP_HOME">/dev/null; pwd`
cd $HAPROXY_APP_HOME

HAPROXY_APP_NAME="hadocker"

APPPARDIR=`dirname $HAPROXY_APP_HOME`
APP_VERSION="${HAPROXY_APP_HOME//$APPPARDIR\/$HAPROXY_APP_NAME-/}"
echo "APP_VERSION=$APP_VERSION"

#配置日志
mkdir -p ${LOGS_BASE}/${HAPROXY_APP_NAME}
rm -rf /etc/rsyslog.d/${HAPROXY_APP_NAME}_log.conf
echo "
\$ModLoad imudp
\$UDPServerRun 514
local0.* ${LOGS_BASE}/${HAPROXY_APP_NAME}/${HAPROXY_APP_NAME}.log
&~
" >/etc/rsyslog.d/${HAPROXY_APP_NAME}_log.conf 
sed  -i "s#SYSLOGD_OPTIONS=\"\"#SYSLOGD_OPTIONS=\"-c 2 -r -m 0\"#g" /etc/sysconfig/rsyslog

if [ ! -f /etc/sysconfig/haproxy ] ; then
    echo "" >/etc/sysconfig/haproxy
fi 

#logrotate
echo "$LOGS_BASE/${HAPROXY_APP_NAME}/${HAPROXY_APP_NAME}.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    dateext
    sharedscripts
    postrotate
        /bin/kill -HUP \`cat /var/run/syslogd.pid 2> /dev/null\` 2> /dev/null || true
        /bin/kill -HUP \`cat /var/run/rsyslogd.pid 2> /dev/null\` 2> /dev/null || true
    endscript
}" > /etc/logrotate.d/${HAPROXY_APP_NAME}

gunzip -c hadocker-${APP_VERSION}.tar.gz |docker load
mkdir -p  /etc/${HAPROXY_APP_NAME}
chmod 1777 /etc/${HAPROXY_APP_NAME}/

# 拷贝 haproxy 配置
for HOST in ${haproxy_hosts//,/ } ; do
    scp -r $HOST:/etc/haproxy/errorfiles $HAPROXY_APP_HOME
    if [ "$?" = "0" ] ; then
        break
    fi
done

exit $?

