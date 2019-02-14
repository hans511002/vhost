#!/bin/bash
. /etc/bashrc
#if [ $# -lt 1 ] ; then
#  echo "usetag:crt_config.sh  "
#  exit 1
#fi

FISRTHOST=`echo ${CLUSTER_HOST_LIST//,/ }|awk '{print $1}'`

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

CRT_DIR="${INSTALL_ROOT}/crt"

########################crt###########################
crtFile=`ls $CRT_DIR/$ROOT_DOMAIN.pem 2>/dev/null`
if [ "$crtFile" = "" ] ; then
    crtFile=`ssh $FISRTHOST ls $CRT_DIR/$ROOT_DOMAIN.pem 2>/dev/null`
    if [ "$crtFile" = "" ] ; then
        ssh $FISRTHOST mkdir -p $CRT_DIR
        ssh $FISRTHOST $APP_BASE/install/crt/crt_build.sh "$PRODUCT_DOMAIN" "$CRT_DIR" $ROOT_DOMAIN
    fi
	cat $FISRTHOST:$CRT_DIR/ca-bundle.crt >> /etc/pki/tls/certs/ca-bundle.crt
	if [ "$FISRTHOST" != "$HOSTNAME" ] ; then 
		mkdir -p $CRT_DIR/
		scp -rp $FISRTHOST:$CRT_DIR/* $CRT_DIR/
	fi
fi

###############################################



