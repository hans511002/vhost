#!/bin/bash
 
bin=`dirname "${BASH_SOURCE-$0}"`
cd "$bin"
bin=`cd "$bin">/dev/null; pwd`
cd $bin

. /sobeyhive/app/install/funs.sh 

export APP_HOME="$bin"
export _APP_VERSION=`echo ${APP_HOME//*\//}|sed -e "s|.*-||"`
export appName=`echo ${APP_HOME//*\//}|sed -e "s|-$_APP_VERSION||"`
# export APPNAME=`toupper "${appName}" `
export APPNAME=`echo $appName | awk '{print toupper($0)}'`
THIS_APP_HOME=`echo "${APPNAME}_HOME"`
THIS_APP_HOME=`env|grep $THIS_APP_HOME|sed -e "s|$THIS_APP_HOME=||"`


INS_THISAPP_VER=`getAppVer ${appName}`

if [ -d "$APP_BASE/${appName}-$INS_THISAPP_VER" -a "$THIS_APP_HOME" = "$APP_BASE/${appName}-$INS_THISAPP_VER" ] ; then
    echo "cur install ver is $INS_THISAPP_VER"
else
    echo "$INS_THISAPP_VER is not installed"
    exit 1
fi

APPPARDIR=`dirname $bin`
CUR_THISAPP_VER="${bin//$APPPARDIR\/${appName}-/}"

if [ "$INS_THISAPP_VER" = "$CUR_THISAPP_VER" ] ; then
    echo "$CUR_THISAPP_VER is aready installed"
    exit 0
fi

scp $THIS_APP_HOME/conf/servers ./conf/
if [ -f "$THIS_APP_HOME/conf/$appName-install.conf" ] ; then
    scp $THIS_APP_HOME/conf/$appName-install.conf ./conf/
else
    echo "defaultPort=3306
galeraPort=4567
galeraISTPort=4568
galeraSSTPort=4444
" > ./conf/$appName-install.conf
fi

sed -i -e "s|$INS_THISAPP_VER|$CUR_THISAPP_VER|" /etc/profile.d/${appName}.sh
sed -i -e "s|${appName}_user=.*|${appName}_user=root|" /etc/profile.d/${appName}.sh
rm -rf sbin/start_${appName}.sh
rm -rf sbin/stop_${appName}.sh

THISAPP_HOSTS=`cat $THIS_APP_HOME/conf/servers`
for appHost in $THISAPP_HOSTS ; do
    if [ "$appHost" = "$LOCAL_HOST" -a -d "$APP_BASE/${appName}-$CUR_THISAPP_VER" ] ; then
        continue
    fi
    echo "copy install dir to $appHost:scp -r $bin $APP_BASE "
    scp -r $bin $appHost:$APP_BASE 
    scp /etc/profile.d/${appName}.sh $appHost:/etc/profile.d/${appName}.sh
done

. /etc/profile.d/${appName}.sh
THIS_APP_HOME=`echo "${APPNAME}_HOME"`
export THIS_APP_HOME=`env|grep $THIS_APP_HOME|sed -e "s|$THIS_APP_HOME=||"`

function regTozk() {
if [ "$INSTALLER_HOME" != "" ] ; then
    cmd.sh start-zk.sh 2>/dev/null
    echo "sleep 10" && sleep 10
    echo "$INSTALLER_HOME/sbin/installer zkctl -c upappver -p mysql -v $CUR_THISAPP_VER"
    $INSTALLER_HOME/sbin/installer zkctl -c upappver -p mysql -v $CUR_THISAPP_VER
fi
}

echo "new THISAPP_HOME=$THIS_APP_HOME"
echo "$APP_BASE/${appName}-$CUR_THISAPP_VER/upgrade_${appName}_cluster.sh $LCOAL_IP $LOCAL_IP $CUR_THISAPP_VER $INS_THISAPP_VER"
$APP_BASE/${appName}-$CUR_THISAPP_VER/upgrade_${appName}_cluster.sh $LOCAL_IP $LOCAL_HOST $CUR_THISAPP_VER $INS_THISAPP_VER

if [ "$?" = "0" ]; then
    echo "regTozk"
    regTozk
else
    sed -i -e "s|$CUR_THISAPP_VER|$INS_THISAPP_VER|" /etc/profile.d/${appName}.sh
    for appHost in $THISAPP_HOSTS ; do
        scp /etc/profile.d/${appName}.sh $appHost:/etc/profile.d/${appName}.sh
    done
fi




