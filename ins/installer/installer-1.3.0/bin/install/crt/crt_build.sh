#!/bin/bash
. /etc/bashrc
if [ $# -lt 3 ] ; then
  echo "usetag:crt_build.sh domain workdir crtname [CAPAASWD]"
  exit 1
fi
#
#$APP_BASE/install/crt_build.sh "$PRODUCT_DOMAIN" "`pwd`" hive_crt  
#
BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

. ${APP_BASE}/install/funs.sh

DOMAIN=$1
WORK_DIR=$2
CRTNAME=$3
CAPAASWD=$4

if [ "$CAPAASWD" = "" ] ; then
   CAPAASWD="hans11"
fi 

cd $WORK_DIR

if [ ! -f "$WORK_DIR/rebuildCrt.sh" ] ; then
echo "#!/bin/bash
. /etc/bashrc
$BIN/crt_build.sh "$DOMAIN" "$WORK_DIR" $CRTNAME
" > $WORK_DIR/rebuildCrt.sh
chmod +x $WORK_DIR/rebuildCrt.sh
fi

echo "#################config cnf ext file############"
rootFile=$WORK_DIR/root.cnf
cnfFile=$WORK_DIR/v3.cnf
extFile=$WORK_DIR/v3.ext

if [ ! -e "$rootFile" ] ; then
    if [ -e "$BIN/root.cnf" ] ; then
       scp $BIN/root.cnf $rootFile
    fi 
fi 

if [ ! -e "$cnfFile" ] ; then
    if [ -e "$BIN/v3.cnf" ] ; then
       scp $BIN/v3.cnf $cnfFile
    fi 
fi 

if [ ! -e "$extFile" ] ; then
    if [ -e "$BIN/v3.ext" ] ; then
       scp $BIN/v3.ext $extFile
    fi 
fi 

if [ ! -e "$rootFile" ] ; then
   rootFile=$cnfFile
fi 

PRODUCT_DOMAIN=$DOMAIN
proDomain=$(echo "$PRODUCT_DOMAIN" | awk -F. '{print $1}')
rootDomain=${PRODUCT_DOMAIN/$proDomain./}

sed -i -e "s|CN=.*|CN=$DOMAIN|" $cnfFile
sed -i -e "s|DNS.1=.*|DNS.1=$DOMAIN|" $extFile
sed -i -e "s|\${PRODUCT_DOMAIN}|$DOMAIN|g" -e "s|\${ROOT_DOMAIN}|$rootDomain|g"  $extFile


DNSIPS=`getDnsIpList`
ipIndex=(${DNSIPS//,/ })
ipIndex=${#ipIndex[@]}
if [ "`check_app keepalived`" = "true" ]; then
    ((ipIndex++))
fi
for DNSHOSTIP in ${DNSIPS//,/ } ; do
    thip=`cat $extFile | grep IP.$ipIndex=`
    if [ "$thip" = "" ] ; then
        sed -i -e "/IP.1=.*/aIP.$ipIndex=$DNSHOSTIP"  $extFile
    else
        sed -i -e "s|IP.$ipIndex=.*|IP.$ipIndex=$DNSHOSTIP|"  $extFile
    fi
    ((ipIndex--))
done

if [ "`check_app keepalived`" = "true" ]; then
    thip=`cat $extFile | grep IP.$ipIndex=`
    if [ "$thip" = "" ] ; then
        sed -i -e "/DNS.1=.*/aIP.$ipIndex=$NEBULA_VIP"  $extFile
    else
        sed -i -e "s|IP.$ipIndex=.*|IP.$ipIndex=$NEBULA_VIP|"  $extFile
    fi
fi



echo "################# cat $cnfFile############"
cat $cnfFile
echo "################# cat $extFile############"
cat $extFile

echo "#################end config file############"

keyFIle=`ls $WORK_DIR/rootCA.key 2>/dev/null `
pemFIle=`ls $WORK_DIR/rootCA.crt 2>/dev/null `
buildRootCAFlag=true
tryTime=0
while [ "$keyFIle" != "$WORK_DIR/rootCA.key" -o "$pemFIle" != "$WORK_DIR/rootCA.crt" ] ;  do
    ((tryTime++))
    if [ "$tryTime" -gt "10" ] ; then
        buildRootCAFlag=false
        echo "build rootCA error "
        break
    fi
    rm -rf $BIN/rootCA.*
    echo "build root CA ......................"
    echo "$BIN/createRootCA.sh $CAPAASWD $WORK_DIR $rootFile"
    $BIN/createRootCA.sh $CAPAASWD $WORK_DIR $rootFile
    keyFIle=`ls $WORK_DIR/rootCA.key 2>/dev/null `
    pemFIle=`ls $WORK_DIR/rootCA.crt 2>/dev/null `
done

if [ "$buildRootCAFlag" = "true" ] ; then
    pemFIle=""
    tryTime=0
    while [ "$pemFIle" != "$WORK_DIR/$CRTNAME.crt" ] ;  do
        ((tryTime++))
        if [ "$tryTime" -gt "10" ] ; then
            buildRootCAFlag=false
            echo "build rootCA error "
            break
        fi
        rm -rf $BIN/$CRTNAME.*
        echo "build $CRTNAME crt ................."
        echo "$BIN/createselfsignedcertificate.sh $CAPAASWD $WORK_DIR $CRTNAME $WORK_DIR $cnfFile $extFile "
        $BIN/createselfsignedcertificate.sh $CAPAASWD $WORK_DIR $CRTNAME $WORK_DIR $cnfFile $extFile
        pemFIle=`ls $WORK_DIR/$CRTNAME.crt 2>/dev/null `
        pemFileSize=`du $pemFIle |awk '{print $1}'`
        if [ "$pemFileSize" = "" -o "$pemFileSize" = "0" ] ; then
            pemFIle=""
           rm -rf $BIN/$CRTNAME.*
        fi
    done
    if [ "$buildRootCAFlag" != "true" ] ; then
        echo "build crt and key error"
        exit 1
    fi
    cat $WORK_DIR/$CRTNAME.crt $WORK_DIR/$CRTNAME.key > $WORK_DIR/$CRTNAME.pem #
    cat $WORK_DIR/rootCA.crt > $WORK_DIR/ca-bundle.crt
    cat $WORK_DIR/$CRTNAME.crt >> $WORK_DIR/ca-bundle.crt
else
    openssl req -x509 -days 36500 -subj "/CN=$DOMAIN/" -nodes -newkey rsa:2048 -keyout $CRTNAME.key -out $CRTNAME.crt
    if [ "$?" != "0" ] ; then
        echo "build crt and key error"
        exit 1
    fi
    cat $WORK_DIR/$CRTNAME.crt $WORK_DIR/$CRTNAME.key > $WORK_DIR/$CRTNAME.pem
    cat $WORK_DIR/$CRTNAME.crt >>  $WORK_DIR/ca-bundle.crt
    
    #标准 pkcs12
    echo "openssl pkcs12 -export -clcerts -out $WORK_DIR/$CRTNAME.pfx -inkey $WORK_DIR/$CRTNAME.key -in $WORK_DIR/$CRTNAME.crt -password pass:$CAPAASWD"
    openssl pkcs12 -export -clcerts -out $WORK_DIR/$CRTNAME.pfx -inkey $WORK_DIR/$CRTNAME.key -in $WORK_DIR/$CRTNAME.crt -password pass:$CAPAASWD
fi

echo "keytool -importkeystore -v -srckeystore  openssl.p12 -srcstoretype pkcs12 -srcstorepass $CAPAASWD -destkeystore $CRTNAME.keystore -deststoretype jks -deststorepass $CAPAASWD"
keytool -importkeystore -v -srckeystore  openssl.p12 -srcstoretype pkcs12 -srcstorepass $CAPAASWD -destkeystore $CRTNAME.keystore -deststoretype jks -deststorepass $CAPAASWD

