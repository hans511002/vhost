#!/bin/bash
. /etc/bashrc

BIN=$(cd $(dirname $0); pwd)

#if [ -f "${APP_ETC}/cluster.cfg" ] ; then
#  echo "# all app hosts ">/etc/profile.d/app_hosts.sh
#  allApps=${ALL_APP//,/ }
#   for appName in $allApps ; do
#      hosts=`cat ${APP_ETC}/cluster.cfg|grep "app.$appName.install.hosts=" |awk -F= '{print $2}'`
#      if [ "$hosts" != "" ] ; then
#           echo "export ${appName}_hosts=\"$hosts\" ">>/etc/profile.d/app_hosts.sh
#        else
#         hosts=`cat ${APP_ETC}/cluster.cfg|grep "cluster.$appName.install.hosts=" |awk -F= '{print $2}'`
#         if [ "$hosts" != "" ] ; then
#               echo "export ${appName}_hosts=\"$hosts\"">>/etc/profile.d/app_hosts.sh
#         fi
#     fi
#   done
#   cp.sh scp $HOSTNAME:/etc/profile.d/app_hosts.sh /etc/profile.d/
#fi

cmd.sh $BIN/vip_config.sh
cmd.sh rm -rf $LOGS_BASE/docker/docker_containers

for host in `cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'` ; do
    ssh $host rm -rf $LOGS_BASE/docker/docker_containers
done

#重启nginx
cmd.sh service nginx restart

#重新run一次所有应用容器，确保在安装期间丢失的容器重新运行起来"
allAppDirs=`ls -l $APP_BASE/install/|grep -E "^\d"|awk '{print $NF}'`

for app_docker in $allAppDirs; do
    echo " begin to recreate container $app_docker"
    app_name=${app_docker//-/_}
    appHome=`echo "$app_name" |awk -F_ '{printf("%s_HOME",toupper($1))}' `
    appName=`echo "$app_name" |awk -F_ '{printf("%s",tolower($1))}' `
    APP_HOME=`env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
    echo "appHome=$appHome appName=$appName"

    if [ "$APP_HOME" = ""  ] ; then
        appHome=`echo "$app_name" |awk -F_ '{printf("%s_DOCKER_HOME",toupper($1))}' `
        APP_HOME=`env|grep -E ^$appHome=  |sed -e "s/$appHome=//"`
        if [ "$APP_HOME" = ""  ] ; then
            echo " app $app_docker not install  "
            continue
         fi
    fi
    appVer=`echo "$APP_HOME" |awk -F- '{print $2}' `
    echo "$appHome=$APP_HOME"
    if [ -d "$BIN/$appName" ] ; then
        runShell=`ls $BIN/$appName/$appName-*$appVer-run.sh 2>/dev/null`
        for run in $runShell ; do
            [[ "$run" =~ "kibana" ]] && continue
            echo "exec: cmd.sh $run "
            cmd.sh "$run 2>/dev/null"
            if [ "$?" = "0" ] ; then
                echo "app $app_docker lost container has been re RUN"
            fi
        done
    fi
done


exit 0
