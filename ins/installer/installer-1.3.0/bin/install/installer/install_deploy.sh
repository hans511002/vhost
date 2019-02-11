#!/usr/bin/env bash
# 
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`

SUDO=""
if [ "$USER" != "root" ] ; then
SUDO="sudo"
fi
. /etc/profile.d/installer.sh

if [ -f ${INSTALLER_HOME}/conf/installer.cfg ] ; then
    UIPORT=`cat ${INSTALLER_HOME}/conf/installer.cfg |grep "ui.port="|sed -e "s|ui.port=||"`
    proxyPort=`cat ${INSTALLER_HOME}/conf/installer.cfg |grep "proxy.port="|sed -e "s|proxy.port=||"`
    if [ "$UIPORT" != "" ] ; then
        sed -i -e "s|ui.port=.*|ui.port=$UIPORT|" ${INSTALLER_HOME}/conf/installer.properties
     fi
    if [ "$proxyPort" != "" ] ; then
         sed -i -e "s|proxy.port=.*|proxy.port=$proxyPort|" ${INSTALLER_HOME}/conf/installer.properties
    fi
fi


if [ "$ZOOKEEPER_URL" != "" ] ; then
    sed -i -e "s|zk.connect=.*|zk.connect=$ZOOKEEPER_URL|" ${INSTALLER_HOME}/conf/installer.properties
fi

sed -i "s|installer.logs.dir=.*|installer.logs.dir=$LOGS_BASE/installer|g" ${INSTALLER_HOME}/conf/log4j.properties
sed -i "s|log.level=.*|log.level=INFO|g" ${INSTALLER_HOME}/conf/log4j.properties

#sed -i "s|log.level=.*|log.level=INFO|g" ${INSTALLER_HOME}/conf/installer.properties

mkdir -p ${INSTALLER_HOME}/sbin/
echo "#!/usr/bin/env bash
. /etc/bashrc
SUDO=\"\"
if [ \"\$USER\" != \"root\" ] ; then
SUDO=\"sudo\"
fi
\$SUDO service deploy start
" > ${INSTALLER_HOME}/sbin/start_deploy.sh

echo "#!/usr/bin/env bash
. /etc/bashrc
SUDO=\"\"
if [ \"\$USER\" != \"root\" ] ; then
SUDO=\"sudo\"
fi
\$SUDO service deploy stop" > ${INSTALLER_HOME}/sbin/stop_deploy.sh

chmod +x ${INSTALLER_HOME}/sbin/start_deploy.sh ${INSTALLER_HOME}/sbin/stop_deploy.sh
${INSTALLER_HOME}/sbin/start_deploy.sh
