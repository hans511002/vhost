#!/bin/bash

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

if [ "$#" -lt "2" ] ; then
    echo "not in installer exec"
fi

LOCAL_IP=$1
LOCAL_HOST=$2

if [ "${PRODUCT_DOMAIN}" = "" ] ; then
    PRODUCT_DOMAIN="pf.ery.com"
else
    PRODUCT_DOMAIN="${PRODUCT_DOMAIN}"
fi


echo "
export APP_ETC=/etc/app
export INSTALL_ROOT=${app_install_path_base}
export APP_BASE=${app_install_path_app_dir}
export DATA_BASE=${app_install_path_data_dir}
export LOGS_BASE=${app_install_path_logs_dir}
export VIP=${NEBULA_VIP}
export NEBULA_VIP=${NEBULA_VIP}
export PRODUCT_DOMAIN=${PRODUCT_DOMAIN:=pf.hive.sobey.com}
export STORAGE_DOMAIN=${STORAGE_DOMAIN}
#export DOCKER_NETWORK_NAME=--net=${DOCKER_NETWORK_NAME}
export DOCKER_NETWORK_HOSTS=\"${DOCKER_NETWORK_HOSTS}\"
export DOCKER_OTHER_PARAMS=\" -v ${APP_BASE}/ipconf.xml:/ipconf.xml:ro -v ${APP_BASE}/publicsetting.xml:/publicsetting.xml:ro -v /etc/localtime:/etc/localtime:ro \"
export ALL_APP=\"${app_install_roles}\"

export CLUSTER_APP=\"${cluster_install_roles}\"
for app in \${CLUSTER_APP//,/ } ; do
    if [ \"\$ALL_APP\" = \"\${ALL_APP//\$app}\" ] ; then
        ALL_APP=\"\$ALL_APP,\$app\"
    fi
done
export ALL_APP
export LOCAL_IP=$LOCAL_IP
export LOCAL_HOST=$LOCAL_HOST
export CLUSTER_HOST_LIST=\"${CLUSTER_HOST_LIST}\" 
export CLUSTER_IP_LIST=\"${CLUSTER_IP_LIST}\" 

INSTALL_LVS=\"${INSTALL_LVS}\"
export INSTALL_LVS=\"${INSTALL_LVS:=false}\"
if [ \"\$NEBULA_VIP\" = \"\" -o \"\$NEBULA_VIP\" = \"127.0.0.1\" ] ; then
    export NEBULA_VIP=\"$PRODUCT_DOMAIN\"
fi


export INSTALL_DNS=\"${INSTALL_DNS}\"
export INSTALL_FIREWALLD=\"${INSTALL_FIREWALLD}\"

export MYSQL_HA_USE_MYCAT=\"true\" 
export USE_LBSERVICE_FOR_HAPROXY=\"false\" 

if [ -f \"\$APP_BASE/install/docker_res.sh\" ] ; then
    . \$APP_BASE/install/docker_res.sh
fi

" > /etc/profile.d/1appenv.sh

#sed  -i  -e ':label; /if.*docker_res.sh/,/fi/ { /fi/! { $! { N; b label }; }; s/if.*docker_res.sh.*fi//; }' /etc/bashrc #需要多行替换

. /etc/bashrc
. /etc/profile.d/1appenv.sh

if [ "$?" != "0" ] ; then
    echo "load env error: /etc/profile.d/1appenv.sh"
    exit 1
fi
