#!/bin/bash

. /etc/bashrc
. $APP_BASE/install/funs.sh
. /etc/rc.d/init.d/functions

bin=$(cd $(dirname $0); pwd)
DATE=$(date +%Y%m%d)

#get app info
appName=(`ls $bin/*.tar.gz|awk -F/ '{print $NF}'|awk -F- '{print $1}'|uniq`)
appHosts=`getDnsHostList`
appHosts=${appHosts// /,}
appNewVer=`ls $bin/*.tar.gz|awk -F/ '{print $NF}'|awk -F- '{print $NF}'|awk -F '.tar.gz' '{print $1}'|sort|sed -n '$p'`
logFile="$bin/upgrade_${appName}_${DATE}.log"

function upgrade_app(){
    #check
    if [ "${#appName[@]}" != "1" -o "$appHosts" = "" -o "$appNewVer" = "" ]; then
        echo "[ERROR] please check \"\$appName \$appHosts \$appNewVer"
        exit 1
    fi

    #check md5
    res=$(cd $bin; md5sum -c ${appName}-${appNewVer}.tar.gz.md5 >/dev/null 2>&1; echo $?)
    if [ "$res" != "0" ]; then
        echo "check md5 failed: ${appName}-${appNewVer}.tar.gz.md5"
        exit 1
    fi

    #unzip
    tar -xf $bin/${appName}-${appNewVer}.tar.gz -C $bin
    chmod -R +x $bin/${appName}-${appNewVer}/*.sh

    #scp
    for host in ${appHosts//,/ }; do
        echo "scp -rp $bin/${appName}-${appNewVer}/ $host:/sobeyhive/app/"
        scp -rp $bin/${appName}-${appNewVer}/ $host:/sobeyhive/app/
        ssh $host systemctl stop hivedns 2>/dev/null
        ssh $host systemctl stop named 2>/dev/null
        ssh $host systemctl disable named 2>/dev/null
        echo "ssh $host /sobeyhive/app/${appName}-${appNewVer}/start_install_bind.sh ${appHosts%%,*} ${appHosts%%,*} $appNewVer"
        ssh $host /sobeyhive/app/${appName}-${appNewVer}/start_install_bind.sh ${appHosts%%,*} ${appHosts%%,*} $appNewVer
    done
}

echo "$(date)
begin..."|tee -a $logFile
upgrade_app 2>&1|tee -a $logFile
echo "$(date)
end..."|tee -a $logFile



