#!/bin/bash

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN

if [ "$#" -lt "4" -o "$1" = "-h" ] ; then
   echo "usetag:appName hostName lbCmd lbVal
    lbCmd:health lbVal:[down,up,stopping]
    lbCmd:state lbVal:[ready,drain,maint]
   "
   exit 1
fi

appName=$1
servHostName=$2
lbCmd=$3
lbVal=$4
useSocat=$5

. ${APP_BASE}/install/funs.sh
curlLbVal="$lbVal"
if [ "$lbCmd" = "state" ] ; then
    if [ "$lbVal" != "ready" -a "$lbVal" != "drain" -a "$lbVal" != "maint" ] ; then
        echo "set state value must be [ready,drain,maint]"
        exit 1
    fi
elif [ "$lbCmd" = "health" ] ; then
    if [ "$lbVal" != "down" -a "$lbVal" != "up" -a "$lbVal" != "stopping" ] ; then
        echo "set health value must be [down,up,stopping]"
        exit 1
    fi
    if [ "$curlLbVal" = "up" ] ; then
        curlLbVal="hrunn"
    elif [ "$curlLbVal" = "down" ] ; then
        curlLbVal="hdown"
    elif [ "$curlLbVal" = "stopping" ] ; then
        curlLbVal="hnolb"
    fi
else
    echo "lbCmd must be [health,state]"
    exit 1
fi

zkRootNode=`getDeployZkNode`
lbsRootNode="${zkRootNode}/loadbalance/services"
lbsList=`${APP_BASE}/install/zkutil.sh ls $lbsRootNode`
lbsList="${lbsList// /}"
lbsList="${lbsList//[/}"
lbsList="${lbsList//]/}"

echo "lbsList=$lbsList"
for lbName in ${lbsList//,/ } ; do
    lbZkNode="${lbsRootNode}/$lbName"
    lbConfig=`${APP_BASE}/install/zkutil.sh get $lbZkNode 2>/dev/null `
    enable=`echo "$lbConfig" |jq '.enable' |sed -e "s|\"||g" `
    if [ "$enable" = "false" ] ; then
       continue
    fi
    bindHaName=`echo "$lbConfig" |jq '.bindHaName' |sed -e "s|\"||g"`
    bindHaName=${bindHaName:=haproxy}

    ##get ha install host
    #bindHaConfig=`${APP_BASE}/install/zkutil.sh get $zkRootNode/app/$bindHaName 2>/dev/null `
    #bindHaHost=`echo "$bindHaConfig"|jq '.installHost'|sed -e "s|\n||" -e "s|\[||" -e "s|\]||" -e "s|\"||g" -e "s| ||g"`
    #bindHaHost=`echo $bindHaHost`
    bindHaHost=`env|grep ${bindHaName}_hosts| sed -e "s|${bindHaName}_hosts=||" `
    if [ "$bindHaHost" = "" ] ; then
       continue
    fi

    statusPort=`echo "$lbConfig" |jq '.statusPort' |sed -e "s|\"||g" `
    listenConf=`echo "$lbConfig" |jq '.listenConf'   `

    username=`echo "$lbConfig" |jq '.username' |sed -e "s|\"||g" `
    password=`echo "$lbConfig" |jq '.password' |sed -e "s|\"||g" `
    username=${username:=admin}
    password=${password:=admin}

    lbsLength=`echo $listenConf|jq 'length'`

    echo "lbName=$lbName  bindHaName=$bindHaName statusPort=$statusPort policyLength=$lbsLength"

    firstHaHost="${bindHaHost//,*/}"
    useCurl=false
    if [ "$useSocat" != "true" ] ; then
        if [ "$statusPort" != "" ] ; then
            if [ "$statusPort" -gt "0" ] ; then
                for haHost in ${bindHaHost//,/ } ; do
                    ssh $haHost cat /etc/haproxy/$lbName/haproxy.cfg | grep "stats admin if TRUE" | grep -v -E "#"
                    if [ "$?" = "0" ] ; then
                       useCurl=true
                    fi
                    break
                done
            fi
        fi
        if [ "$useCurl" = "true" ] ; then
            for haHost in ${bindHaHost//,/ } ; do
                echo "curl -u $username:$password  \"http://$haHost:$statusPort/;csv;norefresh\" 2>/dev/null"
                lbStatusStr=`curl -u $username:$password  "http://$haHost:$statusPort/;csv;norefresh" 2>/dev/null`
                if [ "$lbStatusStr" != "" ] ; then
                    break
                fi
            done
        fi
    fi

    lbIdx=0
    while [ "$lbIdx" -lt "$lbsLength" ] ; do
        policyConfig=`echo $listenConf|jq ".[$lbIdx]"`
        ((lbIdx++))
        lbAppName=`echo "$policyConfig" |jq '.appName' |sed -e "s|\"||g"`
        if [ "$lbAppName" != "$appName" ] ; then
            continue
        fi
        policyName=`echo "$policyConfig" |jq '.policyName' |sed -e "s|\"||g"`
        listenPort=`echo "$policyConfig" |jq '.listenPort' |sed -e "s|\"||g" -e "s|null||g"`
        listenType=`echo "$policyConfig" |jq '.listenType' |sed -e "s|\"||g"`

        labelName="$policyName"
        if [ "$listenType" = "3" -o "$listenType" = "1" ] ; then
            labelName="$policyName:$listenPort"
        fi
        serverName="${lbAppName}_${servHostName}"

        if [ "$useCurl" = "true" ] ; then # curl set  "http://172.16.128.221:48800/;csv;norefresh"
            OLDIFS="$IFS"
            IFS='
'
            for line in ${lbStatusStr} ; do
                if [ "${line:0:1}" = "#" ] ; then
                    continue
                fi
                line=`echo "${line//,,/,-,}"| sed -e "s|,,|,-,|g" -e "s|,,|,-,|g"`
                fileds=(${line//,/
})
                lbPolicyLabel="${fileds[0]}"
                lbPolicyServer="${fileds[1]}"

                if [ "$lbPolicyLabel" != "$labelName" -o "$lbPolicyServer" != "$serverName" ] ; then
                    continue
                fi
                iid="${fileds[27]}"
                for  haHost in ${bindHaHost//,/ } ; do
                    echo "curl -u $username:$password -d \"s=$serverName&action=$curlLbVal&b=#$iid\" \"http://$haHost:$statusPort/;st=DONE\" "
                    curl -u $username:$password -d "s=$serverName&action=$curlLbVal&b=#$iid" "http://$haHost:$statusPort/;st=DONE"
                done
                #echo fileds ${#fileds[*]} ${fileds[*]}
            done
            IFS=$OLDIFS
        else #socat set
            for  haHost in ${bindHaHost//,/ } ; do
                echo -n "echo \"set server $labelName/$serverName $lbCmd $lbVal\" | ssh $haHost docker exec -i dynamic-ha-haproxy-$lbName socat stdio unix-connect:/tmp/haproxy"
                echo "set server $labelName/$serverName $lbCmd $lbVal"| ssh $haHost docker exec -i dynamic-ha-haproxy-$lbName socat stdio unix-connect:/tmp/haproxy
            done
        fi
    done
done

#echo "set server  zookeeper:2182/zookeeper_paas1 health down " |socat stdio unix-connect:/tmp/haproxy
#echo " disable server zookeeper:2182/zookeeper_paas1 " |socat stdio unix-connect:/tmp/haproxy
#echo " enable server zookeeper:2182/zookeeper_paas1 " |socat stdio unix-connect:/tmp/haproxy
