#! /bin/bash

. /etc/bashrc

#获取当前目录
HAPROXY_HOME=`dirname "${BASH_SOURCE-$0}"`
HAPROXY_HOME=`cd "$HAPROXY_HOME">/dev/null; pwd`
cd $HAPROXY_HOME
LOCAL_IP=$1
curVersion=$2
if [ $# -lt 2 ] ; then 
  echo "usetag:install_haproxy.sh localIP oldVersion"
  exit 1
fi

APPPARDIR=`dirname $HAPROXY_HOME`
APP_VERSION="${HAPROXY_HOME//$APPPARDIR\/haproxy-/}"
echo "APP_VERSION=$APP_VERSION"

if [ "$curVersion" = "$APP_VERSION" ] ; then
    echo "aready installed $APP_VERSION"
    exit 0
fi

SERVICE_ENABLE=$(cat $HAPROXY_HOME/conf/haproxy_install.conf | grep 'SERVICE_ENABLE' | awk -F '=' '{print $2}')
useLbService=$(cat $HAPROXY_HOME/conf/haproxy_install.conf | grep 'useLbService=' | awk -F '=' '{print $2}')

#Haproxy安装包名
yum localinstall -y haproxy*
userdel -r haproxy 2>/dev/null
useradd -s /sbin/nologin -d /var/lib/haproxy haproxy

DIR=`dirname "${BASH_SOURCE-$0}"`
DIR=`dirname "$DIR"`
mkdir -p /etc/haproxy
chmod +x $APP_BASE/install/haproxy/*.sh 
scp -r /etc/haproxy/errorfiles/ $HAPROXY_HOME

#设置自启动
if [ "$SERVICE_ENABLE" = "true" ] ; then
    chkconfig haproxy on
fi
#配置日志
mkdir -p ${LOGS_BASE}/haproxy
rm -rf /etc/rsyslog.d/haproxy_log.conf
cp $HAPROXY_HOME/config/haproxy_log.conf /etc/rsyslog.d
sed -i -e "s|\${LOGS_BASE}|${LOGS_BASE}|g" /etc/rsyslog.d/haproxy_log.conf
#开启远程日志
if [ ! -f /etc/sysconfig/haproxy ] ; then
    echo "" >/etc/sysconfig/haproxy
fi 
sed  -i "s#SYSLOGD_OPTIONS=\"\"#SYSLOGD_OPTIONS=\"-c 2 -r -m 0\"#g" /etc/sysconfig/rsyslog

#logrotate
echo "$LOGS_BASE/haproxy/haproxy.log {
    su root
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
}" > /etc/logrotate.d/haproxy

echo " config haproxy service "
#/usr/sbin/haproxy-systemd-wrapper -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid 

scp $HAPROXY_HOME/sbin/haproxy_server.sh /etc/haproxy/

echo "
[Unit]
Description=HAProxy Load Balancer
After=syslog.target network.target

[Service]
EnvironmentFile=/etc/sysconfig/haproxy
ExecStart=/etc/haproxy/haproxy_server.sh start \$OPTIONS
ExecReload=/etc/haproxy/haproxy_server.sh restart \$MAINPID
ExecStop=/etc/haproxy/haproxy_server.sh stop \$MAINPID

[Install]
WantedBy=multi-user.target

">/usr/lib/systemd/system/haproxy.service

echo "cat /usr/lib/systemd/system/haproxy.service"
cat /usr/lib/systemd/system/haproxy.service
systemctl daemon-reload

service rsyslog restart
sleep 2
service haproxy restart

gunzip -c haproxy-${APP_VERSION}.tar.gz |docker load
mkdir -p  /etc/haproxy
chmod 1777 /etc/haproxy/
USE_LBSFLAGFILE="/etc/haproxy/useLbService"
echo "useLbService=$useLbService" > $USE_LBSFLAGFILE
echo "inited=false" >> $USE_LBSFLAGFILE

RUN_CMD_FILE="${APP_BASE}/install/haproxy/haproxy-${APP_VERSION}-run.sh"
echo "#! /bin/bash
. /etc/bashrc
. \$APP_BASE/install/funs.sh
appName=\$1
if [ \"\$appName\" = \"\" ] ; then
    exit 1
fi
checkRunUser \$appName
docker run --name haproxy-\$appName -v /etc/haproxy/\$appName:/etc/haproxy $DOCKER_NETWORK_HOSTS --net host haproxy:$APP_VERSION
">$RUN_CMD_FILE
exit 0


