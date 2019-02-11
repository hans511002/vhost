#!/bin/bash
. /etc/bashrc
#if [ $# -lt 1 ] ; then
#  echo "usetag:crt_config.sh  "
#  exit 1
#fi

FISRTHOST=`echo ${CLUSTER_HOST_LIST//,/ }|awk '{print $1}'`

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

CRT_DIR="${APP_BASE}/install/crt"
# openssl x509 -noout -text -in hive_crt.crt |grep DNS
# DNS:pf.hive.sobey.com, DNS:hive.sobey.com, IP Address:172.16.131.141

########################hive_crt###########################
crtFile=`ls $CRT_DIR/hive_crt.pem 2>/dev/null`
if [ "$crtFile" = "" ] ; then
    crtFile=`ssh $FISRTHOST ls $CRT_DIR/hive_crt.pem 2>/dev/null`
    if [ "$crtFile" = "" ] ; then
        ssh $FISRTHOST mkdir -p $CRT_DIR
        ssh $FISRTHOST $APP_BASE/install/crt_build.sh "$PRODUCT_DOMAIN" "$CRT_DIR" hive_crt
    fi
	scp $FISRTHOST:$CRT_DIR/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt
	if [ "$FISRTHOST" != "$HOSTNAME" ] ; then 
		mkdir -p $CRT_DIR/
		scp -rp $FISRTHOST:$CRT_DIR/* $CRT_DIR/
	fi
fi

###############################################



