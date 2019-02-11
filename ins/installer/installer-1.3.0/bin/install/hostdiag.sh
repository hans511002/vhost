#!/bin/bash

# ===================================
# hostdiag.sh: app Diagnostic Report
# ===================================
#

version="2.0.4"
revdate="2017-06-26"

PATH="$PATH${PATH+:}/usr/sbin:/sbin:/usr/bin:/bin"

_os="`uname -o`"
if test "$_os" != "GNU/Linux"; then
    echo "hostdiag.sh: ERROR: Unsupported Operating System: $_os"
    echo "hostdiag.sh: Supported Operating Systems are: Linux"
    exit 1
fi


##################################################################################
declare -A APP_PROCESS_MAP

export LANG=en_US.UTF-8

function _main {

    _set_defaults
    _parse_cmdline "$@"
    _print_header
    _check_for_ref
#    _check_for_new_version
    _check_valid_output_format
    echo "outputMongoFormat=$outputMongoFormat"
    _init_output_vars
    _reset_vars
    _print_user_run_advice
    _setup_fds
    _output_preamble

    shopt -s nullglob


    ####################

    # Generic/system/distro/boot info
    export section_group="Generic/system/distro/boot info"
    section fingerprint fingerprint
    section args runcommand printeach "$@"
    section date runcommand date
    section hostname runcommand hostname
    section hostname_fqdn runcommand hostname -f
    section whoami runcommand whoami
    section hostdiag_upgrade getenvvars inhibit_new_version_check inhibit_version_update updated_from relaunched_from newversion user_elected_no_update update_not_possible user_elected_not_to_run_newversion download_url download_target
    section environment getenvvars PATH LD_LIBRARY_PATH LD_PRELOAD PYTHONPATH PYTHONHOME
    section distro getfiles /etc/*release /etc/*version
    section uname runcommand uname -a
    section glibc runcommand lsfiles /lib*/libc.so* /lib/*/libc.so*
    section glibc2 runcommand eval "/lib*/libc.so* || /lib/*/libc.so*"
    section ld.so.conf getfiles /etc/ld.so.conf /etc/ld.so.conf.d/*
    section lsb runcommand lsb_release -a
    section rc.local getfiles /etc/rc.local
    section sysctl runcommand sysctl -a
    section sysctl.conf getfiles /etc/sysctl.conf /etc/sysctl.d/*
    section ulimit runcommand ulimit -a
    section limits.conf getfiles /etc/security/limits.conf /etc/security/limits.d/*
    section selinux runcommand sestatus
    section uptime runcommand uptime
    section boot runcommand who -b
    section runlevel runcommand who -r
    section clock_change runcommand who -t
    section timezone_config getfiles /etc/timezone /etc/sysconfig/clock
    section timedatectl runcommand timedatectl
    section localtime runcommand lsfiles /etc/localtime
    section localtime_matches runcommand find /usr/share/zoneinfo -type f -exec cmp -s \{\} /etc/localtime \; -print
    section clocksource getfiles /sys/devices/system/clocksource/clocksource*/{current,available}_clocksource

    section chkconfig_list runcommand chkconfig --list
    section initctl_list runcommand initctl list

    # Block device/filesystem info
    export section_group="device/filesystem info"
    section scsi getfiles /proc/scsi/scsi
    section blockdev runcommand blockdev --report
    section lsblk runcommand lsblk

    section udev_disks
        runcommands
            awk '{ $0 = $4 } /^[sh]d[a-z]+$/' /proc/partitions | xargs -n1 --no-run-if-empty udevadm info --query all --name
        endruncommands
    endsection

    section fstab getfiles /etc/fstab
    section mount runcommand mount
    section df-h runcommand df -h
    section df-k runcommand df -k

    section mdstat getfiles /proc/mdstat
    section mdadm_detail_scan runcommand mdadm --detail --scan
    section mdadm_detail
        runcommands
            sed -ne 's,^\(md[0-9]\+\) : .*$,/dev/\1,p' < /proc/mdstat | xargs -n1 --no-run-if-empty mdstat --detail
        endruncommands
    endsection

    section dmsetup runcommand dmsetup ls
    section device_mapper runcommand lsfiles -R /dev/mapper /dev/dm-*

    section lvm subsection pvs runcommand pvs -v
    section lvm subsection vgs runcommand vgs -v
    section lvm subsection lvs runcommand lvs -v
    section lvm subsection pvdisplay runcommand pvdisplay -m
    section lvm subsection vgdisplay runcommand vgdisplay -v
    section lvm subsection lvdisplay runcommand lvdisplay -am

    section nr_requests getfilesfromcommand find /sys -name nr_requests
    section read_ahead_kb getfilesfromcommand find /sys -name read_ahead_kb
    section scheduler getfilesfromcommand find /sys -name scheduler
    section rotational getfilesfromcommand find /sys -name rotational

    # Network info
    export section_group="network info"
    section ifconfig runcommand ifconfig -a
    section route runcommand route -n
    section iptables runcommand iptables -L -v -n
    section iptables_nat runcommand iptables -t nat -L -v -n
    section ip_link runcommand ip link
    section ip_addr runcommand ip addr
    section ip_route runcommand ip route
    section ip_rule runcommand ip rule
    section ip_neigh runcommand ip neigh
    section hosts getfiles /etc/hosts
    section host.conf getfiles /etc/host.conf
    section resolv getfiles /etc/resolv.conf
    section nsswitch getfiles /etc/nsswitch.conf
    section networks getfiles /etc/networks
    section rpcinfo runcommand rpcinfo -p
    section netstat runcommand netstat -anpoe
    section netstat subsection tcp_summary runcommand "netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'"
    section netstat subsection ip_summary runcommand "netstat -na|grep ESTABLISHED|awk '{print $5}'|awk -F: '{print $1}'|sort|uniq -c|sort -nr"

    # Network time info
    export section_group="network time info"
    section ntp getfiles /etc/ntp.conf
    section ntp subsection chkconfig runcommand systemctl status ntpd
    section ntp subsection status runcommand ntpstat
    section ntp subsection peers runcommand ntpq -p
    section ntp subsection peers_n runcommand ntpq -pn
    section chronyc subsection tracking runcommand chronyc tracking
    section chronyc subsection sources runcommand chronyc sources
    section chronyc subsection sourcestats runcommand chronyc sourcestats

    # Hardware info
    export section_group="hardware info"
    section dmesg runcommand dmesg
    section lspci runcommand lspci -vvv
    section dmidecode runcommand dmidecode --type memory
    section sensors runcommand sensors
    section mcelog getfiles /var/log/mcelog

    # Hardware info with a risk of hanging
    section smartctl
        runcommands
            smartctl --scan | sed -e "s/#.*$//" | while read i; do smartctl --all $i; done
        endruncommands
    endsection
    section scsidevices getfiles /sys/bus/scsi/devices/*/model

    # Numa settings
    export section_group="numa settings"
    section numactl subsection command runcommand which numactl
    section numactl subsection hardware runcommand numactl --hardware
    section numactl subsection show runcommand numactl --show

    # Process/kernel info
    export section_group="process/kernel info"
    section procinfo getfiles /proc/mounts /proc/self/mountinfo /proc/cpuinfo /proc/meminfo /proc/zoneinfo /proc/swaps /proc/modules /proc/vmstat /proc/loadavg /proc/uptime /proc/cgroups /proc/partitions
    section transparent_hugepage getfilesfromcommand find /sys/kernel/mm/{redhat_,}transparent_hugepage -type f
    section ps_thread runcommand ps -eLFww
    # only list ps
    section ps runcommand "ps -eLFww |awk '{print $1,$2,$3,$5,$6,$7,$13 }'|uniq"




    export section_group="app modules info"
echo "##########################app modules process info####################"
    appModules="$ALL_APP"
#    appModules="keepalived,haproxy,nump,docker,installer,zookeeper"
    section app subsection all_app runcommand "echo $appModules"
    section app getfiles ${APP_BASE}/ipconf.xml ${APP_BASE}/publicsetting.xml /etc/profile.d/1appenv.sh \
     /etc/sysconfig/docker /etc/init.d/dns_daemon.sh /etc/init.d/shostname.sh /etc/init.d/appservice.sh

    for app in ${appModules//,/ } ; do
        echo "##########################get $app process info####################"
        appModuleInfo $app
    done


echo "##########################end app modules####################"
    # Dynamic/monitoring info
    section iostat runcommand iostat -xtm 1 60
    section dstat  runcommand dstat  -taT 1 60
    section top subsection top_cpu runcommand "top -bc -d 1 -n 1 -o %CPU -w 1998 |head -27 |grep -v top|grep -v '0.0  0.0' | sed -e 's/ *$//g'"
    section top subsection top_mem runcommand "top -bc -d 1 -n 1 -o %MEM -w 1998 |head -27 |tail -n 20 | sed -e 's/ *$//g'"
    #section top_threads runcommand "top -b -d 1 -n 30 -c -H | sed -e 's/ *$//g' "

echo "##########################hping check####################"
    # ip_port="
    # 172.16.131.131:3306
    # 172.16.131.132:6377,6379,6390
    # "
    if [ -n "$ip_port" -a -e "`which hping 2>/dev/null`" ]; then
        export section_group="hping check"
        for cnt in $ip_port; do
            ips=`echo $cnt|awk -F: '{print $1}'`
            ports=`echo $cnt|awk -F: '{print $2}'|awk -F, '{$1=$1; print $0}'`

            section hping_$ips
                for port in $ports; do
                    echo "$ips:$port ===> please wait 60s"
                    subsection hping_$port runcommand "hping3 -c 60 -S -p $port $ips"
                done
            endsection
        done
    fi

echo "##########################high cpu process check####################"
    getDeployZkAttr


    export section_group="other top cpu process info"
    TOPCPUIDS=`top -bc -d 1 -n 1 -o %CPU -w 1998 |head -107|tail -n 100 |grep -v top|grep -v '0.0  0.0' | sed -e 's/ *$//g'|awk '{print $1}'`
    for pid in $TOPCPUIDS; do
        if [ -z "${APP_PROCESS_MAP[$pid]}" ]; then # not exists
            # echo "    high cpu pid:$pid not exists"
            section top_${pid}
                subsection lsfiles runcommand lsfiles /proc/$pid/cmdline
                subsection cmdline runcommand printeach0file /proc/$pid/cmdline
                printeach0file /proc/$pid/cmdline | awk '$0 == "-f" || $0 == "--config" { getline; print; }' | getstdinfiles
                getfiles /proc/$pid/limits /proc/$pid/mounts /proc/$pid/mountinfo /proc/$pid/status /proc/$pid/cgroup /proc/$pid/stat /proc/$pid/statm
                subsection fd_count runcommand "ls /proc/$pid/fd|wc -l"
                subsection socket_count runcommand "ls -l /proc/$pid/fd |grep socket:|wc -l"
            endsection
        fi
    done
 ###################################################################
    export section_group=""
    _teardown_fds
    _output_postamble
    _finish

    _print_end
}

. ${APP_BASE}/install/funs.sh


function getDeployZkAttr {
    if [ ! -d $INSTALLER_HOME ] ; then
        return
    fi
    export section_group="app deploy info"
    ZKBaseNode=`cat $INSTALLER_HOME/conf/installer.properties |grep "zk.base.node=" | sed  -e "s|zk.base.node=||"`
    clusterName=`cat $INSTALLER_HOME/conf/installer.properties |grep "cluster.name=" | sed  -e "s|cluster.name=||"`
    ZKBaseNode="/$ZKBaseNode/$clusterName"
    echo "$ZKBaseNode"
    section deploy_summary subsection zk_node runcommand " echo $ZKBaseNode"
    section deploy_summary subsection installer.properties runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode |jq "
    section deploy_summary subsection gobal runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/gobal |jq "
    section deploy_summary subsection status runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/status"
    section deploy_summary subsection master runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/master |jq"

    appLists=`$INSTALLER_HOME/sbin/installer zk ls $ZKBaseNode/app`
    appLists=${appLists//[/}
    appLists=${appLists//]/}
    for appName in ${appLists//,/ } ; do
        section deploy_summary subsection app_$appName runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/app/$appName |jq"
    done

    hostLists=`$INSTALLER_HOME/sbin/installer zk ls $ZKBaseNode/clusterNodes`
    hostLists=${hostLists//[/}
    hostLists=${hostLists//]/}
    for hostName in ${hostLists//,/ } ; do
        section deploy_summary subsection clusterNodes_$hostName runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/clusterNodes/$hostName |jq"
    done

    nodeLists=`$INSTALLER_HOME/sbin/installer zk ls $ZKBaseNode/swarmServices`
    nodeLists=${nodeLists//[/}
    nodeLists=${nodeLists//]/}
    for nodeName in ${nodeLists//,/ } ; do
        section deploy_summary subsection swarmServices_$nodeName runcommand "$INSTALLER_HOME/sbin/installer zk get $ZKBaseNode/swarmServices/$nodeName |jq"
    done

}

function getFileEncode {
    fileName=$1
    fileCode=`file $fileName |sed -e "s#$fileName: ##"`
#    echo "fileCode=$fileCode"
#/etc/sysctl.d/app_sysctl.conf: UTF-8 Unicode text, with very long lines
    if [ "${fileCode//,/}" = "$fileCode" ]; then
        if [ "${fileCode// text/}" != "$fileCode" ]; then
            trim ${fileCode// text/}
        elif [ "$fileCode" = "current ar archive" ]; then
            echo "staticlib"
        elif [ "${fileCode//symbolic link/}" != "$fileCode" ]; then
            echo "symbolic"
        elif [ "${fileCode//POSIX tar/}" != "$fileCode" ]; then
            echo "tar"
        elif [ "${fileCode//directory/}" != "$fileCode" ]; then
            echo "directory"
        elif [ "${fileCode//empty/}" != "$fileCode" ]; then
            echo "empty"
        fi
    elif [ "${fileCode// text,/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|text,.*||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode//XML /}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode// source/}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||"`
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode// shell script/}" != "$fileCode" -a  "${fileCode// text/}" != "$fileCode" ]; then
        fileCode=`echo $fileCode|sed -e "s|.*,||" -e "s|text.*|text|"   `
        fileCode=`trim ${fileCode//text/}`
        trim ${fileCode//Unicode/}
    elif [ "${fileCode//executable/}" != "$fileCode" ]; then
        echo "executable"
    elif [ "${fileCode//shared object/}" != "$fileCode" ]; then
        echo "sharedlib"
    elif [ "${fileCode//compressed data/}" != "$fileCode" ]; then
        trim `echo "$fileCode"|sed -e "s|compressed data.*||"`
    elif [ "${fileCode//LSB relocatable/}" != "$fileCode" ]; then
        echo "staticlib"
    fi
}

function _addProc {
    key=$1
    if [ -z "${APP_PROCESS_MAP[$key]}" ]; then
        APP_PROCESS_MAP[$key]=1
    else
        let APP_PROCESS_MAP[$key]++
    fi
#for key in $DOCKER_CONTAINERS; do
#done
}

function appModuleInfo {
    appName=$1
    hostApp=",keepalived,haproxy,nump,docker,installer,zookeeper,cayman,"
    APP_HOME=`getAppHome $appName`
    APP_HOSTS=`getAppHosts $appName`
    if [ "${APP_HOSTS//$HOSTNAME/}" = "$APP_HOSTS" -o "" = "$APP_HOME" ] ; then
        return
    fi
    section ${appName}_conf getfiles `find $APP_HOME/ -regextype posix-extended -regex "$APP_HOME/\w*\.(properties|xml|conf|cfg)" `
    section ${appName}_conf getfiles `find $APP_HOME/conf/ -regextype posix-extended -regex "$APP_HOME/conf/\w*\.(properties|xml|conf|cfg)" `
    section ${appName}_conf getfiles `find $APP_HOME/ -regextype posix-extended -regex "$APP_HOME/\w*/\w*\.(properties|xml|conf|cfg)" \
     |grep -v "/contrib/" |grep -v "/lib/" |grep -v "/recipes/" |grep -v "/application/"|grep -v "/workspace/"|grep -v "/webapps/"|grep -v "/build.xml" \
     |grep -v "/ivy" `
    section ${appName}_conf subsection env "cat /etc/profile.d/$appName.sh"

    hostServiceName="$appName"
    if [ "$appName" = "installer" ]; then
        hostServiceName="deploy"
    fi
    if [ -f "/etc/init.d/$hostServiceName.sh" ] ; then
        section ${appNaappName}_conf getfiles /etc/init.d/$hostServiceName.sh
    fi

    if [ "${hostApp//,$appName,/}" = "$hostApp" ] ; then
        #docker app
        appDockerCons=`docker ps -a|grep $appName|grep $HOSTNAME|awk '{print $NF}'`
        section ${appName}_summary runcommand "docker ps -a|grep $appName|grep $HOSTNAME"
       # runcommands
       # docker ps -a|grep $appName|grep $HOSTNAME
       # #endruncommands
        _fd_count=0
        _socket_count=0
        _pid_count=0

        for appDockerCon in $appDockerCons ; do
            section $appDockerCon runcommand docker top $appDockerCon
            section $appDockerCon subsection inspect runcommand docker inspect $appDockerCon
            section $appDockerCon subsection stats runcommand docker stats --no-stream $appDockerCon

            conTopIds=`docker top $appDockerCon|awk '{print $2}'|grep -v PID`
            for pid in $conTopIds ; do
                section ${appDockerCon//-$HOSTNAME/}_$pid
                    subsection lsfiles runcommand lsfiles /proc/$pid/cmdline
                    subsection cmdline runcommand printeach0file /proc/$pid/cmdline
                    printeach0file /proc/$pid/cmdline | awk '$0 == "-f" || $0 == "--config" { getline; print; }' | getstdinfiles
                    getfiles /proc/$pid/limits /proc/$pid/mounts /proc/$pid/mountinfo /proc/$pid/status /proc/$pid/cgroup /proc/$pid/stat /proc/$pid/statm
                    subsection fd_count runcommand "ls /proc/$pid/fd|wc -l"
                    subsection socket_count runcommand "ls -l /proc/$pid/fd |grep socket:|wc -l"
                endsection
                fd_count=`ls /proc/$pid/fd|wc -l`
                socket_count=`ls -l /proc/$pid/fd |grep -v total |grep socket:|wc -l`
                if [ "$fd_count" -gt "10000" ] ; then
                    echo "    [warn]${appName}:$pid fd_count=$fd_count  _fd_count=$_fd_count"
                fi
                if [ "$socket_count" -gt "5000" ] ; then
                    echo "    [warn]${appName}:$pid socket_count=$socket_count  _socket_count=$_socket_count"
                fi
                _fd_count=`expr $_fd_count + $fd_count`
                _socket_count=`expr $_socket_count + $socket_count`
                ((_pid_count++))
                _addProc $pid
            done
        done
        section ${appName}_summary subsection fd_count runcommand "echo $_fd_count"
        section ${appName}_summary subsection socket_count runcommand "echo $_socket_count"
        section ${appName}_summary subsection pid_count runcommand "echo $_pid_count"
    else

        appPids=""
        if [ "$appName" = "zookeeper" ]; then
            section ${appName}_summary runcommand "ps -ef|grep QuorumPeerMain"
            section ${appName}_summary subsection jps runcommand "jps -v |grep QuorumPeerMain"
            appPids="`jps|grep QuorumPeerMain|awk '{print $1}'`"
        else
            section ${appName}_summary runcommand "systemctl status $hostServiceName -l "
            appPids=`systemctl status $appName |grep "─"|sed -e "s|.*─||" -e "s| .*||"`
        fi
        _fd_count=0
        _socket_count=0
        _pid_count=0

        for pid in $appPids ; do
            section ${appName}_$pid
                subsection lsfiles runcommand lsfiles /proc/$pid/cmdline
                subsection cmdline runcommand printeach0file /proc/$pid/cmdline
                printeach0file /proc/$pid/cmdline | awk '$0 == "-f" || $0 == "--config" { getline; print; }' | getstdinfiles
                getfiles /proc/$pid/limits /proc/$pid/mounts /proc/$pid/mountinfo /proc/$pid/status /proc/$pid/cgroup /proc/$pid/stat /proc/$pid/statm
                subsection fd_count runcommand "ls /proc/$pid/fd|wc -l"
                subsection socket_count runcommand "ls -l /proc/$pid/fd |grep -v total |grep socket:|wc -l "
            endsection
            fd_count=`ls /proc/$pid/fd|wc -l`
            socket_count=`ls -l /proc/$pid/fd |grep -v total |grep socket:|wc -l`
            if [ "$fd_count" -gt "1000" ] ; then
                echo "    [warn]${appName}:$pid fd_count=$fd_count  _fd_count=$_fd_count"
            fi
            if [ "$socket_count" -gt "500" ] ; then
                echo "    [warn]${appName}:$pid socket_count=$socket_count  _socket_count=$_socket_count"
            fi
            _fd_count=`expr $_fd_count + $fd_count`
            _socket_count=`expr $_socket_count + $socket_count`
            ((_pid_count++))
            _addProc $pid
        done
        section ${appName}_summary subsection fd_count runcommand "echo $_fd_count"
        section ${appName}_summary subsection socket_count runcommand "echo $_socket_count"
        section ${appName}_summary subsection pid_count runcommand "echo $_pid_count"
    fi
    if [ "$_fd_count" -gt "5000" -o "$_socket_count" -gt "3000" ] ; then
        echo "      [warn]${appName} pid_count=$_pid_count  fd_count=$_fd_count _socket_count=$_socket_count "
    else
        echo "      [info]${appName} pid_count=$_pid_count  fd_count=$_fd_count _socket_count=$_socket_count "
    fi
}

###############################################################
# Internal API functions (used by the actual tests)
###############################################################

function section {
    if [ "${section:+set}" = set ]; then
        endsection
    fi
    section="$1"
    shift
    echo -n "Gathering $section info... " 1>&3
    if [ $# -gt 0 ]; then
        "$@"
        endsection
    fi
}

function endsection {
    echo "done" 1>&3
    unset section
}

function subsection {
    subsection="$1"
    shift
    if [ $# -gt 0 ]; then
        "$@"
        endsubsection
    fi
}

function endsubsection {
    unset subsection
}

function runcommands {
    _nextoutput
    _graboutput
    ts_started="$(_now)"
    if [ "$1" != "_notrace" ]; then
        set -x
    fi
}

function endruncommands {
    # Undo redirections
    rc=$?
    set +x
    _ungraboutput
    ts_ended="$(_now)"
    # FIXME: this should be able to be done quicker with sed
    grep -Ev '^\+ (_?end ?runcommands( runcommands)?|rc=-?[0-9]+|set \+x)$' "$errfile" > "$errfile.new" ; mv -f "$errfile.new" "$errfile"
    #_addfield file_lines_array output "$outfile"
    #_addfield file_lines_array error "$errfile"
    _emit
}

function runcommand {
    command="$@"
    ccmmdd="$@"
    runcommands _notrace
    if [ "${ccmmdd//|/}" = "$ccmmdd" ] ; then
        $ccmmdd
    else
        su -c "$ccmmdd"
    fi
    endruncommands
}

function printeach {
    local i
    for i; do
        echo "$i"
    done
}

function printeach0 {
    xargs -n1 -0
}

function printeach0file {
    local i
    for i; do
        printeach0 < "$i"
    done
}

function fingerprint {
    ts="$(_now)"
    _addfield string "script" "hostdiag.sh"
    _addfield string "revdate" "$revdate"
    _addfield string "os" "$_os"
    _addfield string "shell" "$SHELL"
    _addfield string "scriptversion" "$version"
    _emit
}

function getenvvars {
    local i
    for i; do
        ts="$(_now)"
        _addfield string "envvar" "$i"
        if [ "${!i+set}" = set ]; then
            _addfield boolean set true
            _addfield string "value" "${!i}"

            _nextoutput
            _graboutput
            declare -p "$i"
            _ungraboutput
            output_fieldname="declaration"
            #_addfield file_lines_array declaration "$outfile"
            #_addfield file_lines_array error "$errfile"
        else
            _addfield boolean set false
        fi
        subsection '$'"$i" _emit
    done
}

function getfiles {
    local f
    for f; do
        ts="$(_now)"
        _addfield string "filename" "$f"
        if [ -e "$f" ]; then
            _addfield boolean exists true
            _addfield string ls "$(ls -l "$f" 2>&1)"

            # FIXME: this doesn't need an associative array; remove it
            declare -lA _stat
            local format
            format+="_stat[mode_oct]='%a' "
            format+="_stat[mode_sym]='%A' "
            format+="_stat[num_blocks]='%b' "
            format+="_stat[block_size]='%B' "
            format+="_stat[context]='%C' "
            format+="_stat[device]='%d' "
            format+="_stat[type]='%F' "
            format+="_stat[gid]='%g' "
            format+="_stat[group]='%G' "
            format+="_stat[links]='%h' "
            format+="_stat[inode]='%i' "
            format+="_stat[mountpoint]='%m' "
            format+="_stat[iohint]='%o' "
            format+="_stat[size]='%s' "
            format+="_stat[major]='%t' "
            format+="_stat[minor]='%T' "
            format+="_stat[uid]='%u' "
            format+="_stat[user]='%U' "
            format+="_stat[time_birth]='%w' "
            format+="_stat[time_birth_epoch]='%W' "
            format+="_stat[time_access]='%x' "
            format+="_stat[time_access_epoch]='%X' "
            format+="_stat[time_mod]='%y' "
            format+="_stat[time_mod_epoch]='%Y' "
            format+="_stat[time_change]='%z' "
            format+="_stat[time_change_epoch]='%Z' "
            eval "$(stat --printf "$format" "$f" 2>/dev/null)"

            local i
            i="mode_oct"          ; _addfield string "$i" "${_stat[$i]}"
            i="mode_sym"          ; _addfield string "$i" "${_stat[$i]}"
            i="num_blocks"        ; _addfield number "$i" "${_stat[$i]}"
            i="block_size"        ; _addfield number "$i" "${_stat[$i]}"
            i="context"           ; _addfield string "$i" "${_stat[$i]}"
            i="device"            ; _addfield number "$i" "${_stat[$i]}"
            i="type"              ; _addfield string "$i" "${_stat[$i]}"
            i="gid"               ; _addfield number "$i" "${_stat[$i]}"
            i="group"             ; _addfield string "$i" "${_stat[$i]}"
            i="links"             ; _addfield number "$i" "${_stat[$i]}"
            i="inode"             ; _addfield number "$i" "${_stat[$i]}"
            i="mountpoint"        ; _addfield string "$i" "${_stat[$i]}"
            i="iohint"            ; _addfield number "$i" "${_stat[$i]}"
            i="size"              ; _addfield number "$i" "${_stat[$i]}"
            i="major"             ; _addfield number "$i" "${_stat[$i]}"
            i="minor"             ; _addfield number "$i" "${_stat[$i]}"
            i="uid"               ; _addfield number "$i" "${_stat[$i]}"
            i="user"              ; _addfield string "$i" "${_stat[$i]}"
            i="time_birth"        ; _addfield string "$i" "${_stat[$i]}"
            i="time_birth_epoch"  ; _addfield number "$i" "${_stat[$i]}"
            i="time_access"       ; _addfield string "$i" "${_stat[$i]}"
            i="time_access_epoch" ; _addfield number "$i" "${_stat[$i]}"
            i="time_mod"          ; _addfield string "$i" "${_stat[$i]}"
            i="time_mod_epoch"    ; _addfield number "$i" "${_stat[$i]}"
            i="time_change"       ; _addfield string "$i" "${_stat[$i]}"
            i="time_change_epoch" ; _addfield number "$i" "${_stat[$i]}"
            fileCode=`getFileEncode $f`
            i="encoding" ; _addfield number "$i" "$fileCode"

            tempFile=`mktemp /tmp/hostdiag-$HOSTNAME-XXXXX`
            if [ "$fileCode" != "empty" ] ; then
                scp "$f" $tempFile
            else
                rm -rf  $tempFile
                $tempFile="$f"
            fi
            if [ "$fileCode" = "ASCII" -o "${fileCode//ISO-/}" != "$fileCode" -o "${fileCode//GB/}" != "$fileCode" ] ; then
                if [ "$fileCode" != "UTF-8" ] ; then
                    #echo -n "iconv -t UTF-8 -f GBK $f -o $tempFile :"
                    iconv -t UTF-8 -f GBK $f -o $tempFile 2>/dev/null
                    RES=$?
                   # echo  "$RES"
                    if [ "$RES" != "0" ] ; then
                        iconv -t UTF-8 -f GBK -c $f -o $tempFile 2>/dev/null
                    fi
                fi
            fi
            _nextoutput
            _graboutput
            cat "$tempFile"
            _ungraboutput
            if [ "$tempFile" != "$f" ] ; then
                rm -rf  $tempFile
            fi
            output_fieldname="content"
            #_addfield file_lines_array content "$outfile"
            #_addfield file_lines_array error "$errfile"
        else
            _addfield boolean exists false
        fi
        subsection "$f" _emit
    done
}

function getstdinfiles {
    local i
    while read i; do
        getfiles "$i"
    done
}

function getfilesfromcommand {
    "$@" | getstdinfiles
}


function lsfiles {
    somefiles=
    restfiles=
    for f; do
        if [ "x$restfiles" = "x" ]; then
            case "$f" in
                --) restfiles=y ;;
                -*) ;;
                *)
                    somefiles=y
                    break
                    ;;
            esac
        else
            somefiles=y
            break
        fi
    done
    if [ "x$somefiles" != "x" ]; then
        ls -la "$@"
    fi
}



###############################################################
# Internal internal functions (not directly used by the tests)
###############################################################

_lf="$(echo -ne '\r')"

function _showversion {
    echo "hostdiag.sh: MongoDB System Diagnostic Information Gathering Tool"
    echo "version $version, copyright (c) 2014-2016, MongoDB, Inc."
}

function _showhelp {
    echo ""
    _showversion
    echo ""
    echo "Usage:"
    echo "    sudo bash hostdiag.sh [options] [reference]"
    echo ""
    echo "Parameters:"
    echo "    [reference]      Reference to ticket, e.g. CS-12435"
    echo "    --format <fmt>   Output in given format (txt or json or mjson)"
    echo "    --txt, --text    Output in legacy plain text format"
    echo "    --json           Output in JSON format"
    echo "    --mjson          Output in mongo JSON format"
    echo "    --answer [ynqd]  At prompts, answer \"yes\", \"no\", \"quit\" or the default"
    echo "    --help, -h       Show this help"
    echo "    --version, -v    Show the hostdiag.sh version"
    echo ""
}

function _user_error_fatal {
    echo ""
    echo "hostdiag.sh: ERROR: $*"
    echo "Run \"bash hostdiag.sh --help\" for help."
    echo ""
    exit 1
}

function _set_defaults {
    outputformat=mjson
    outputMongoFormat=true
    inhibit_new_version_check=n
    inhibit_version_update=n
    ref=""
    ticket_url=""

    host="$(hostname)"
    tag="$(_now)"

    # FIXME: put everything into a subdir (using mktemp)
    outputbase="${TMPDIR:-/tmp}/hostdiag-$host"
    rm -rf $outputbase*
}

function _parse_cmdline {
    while [ "${1%%-*}" = "" -a "x$1" != "x" ]; do
        case "$1" in
            --txt|--text|--json|--mjson)
                outputformat="${1#--}"
                ;;
            --format)
                shift
                outputformat="$1"
                ;;
            --answer)
                shift
                case "$1" in
                    [yYnNqQ])
                        auto_answer="$1"
                        ;;
                    [dD])
                        auto_answer=""  # simulates pressing Enter
                        ;;
                    *)
                        _user_error_fatal "unknown value for --answer: \"$1\""
                        ;;
                esac
                ;;
            --inhibit-new-version-check)
                inhibit_new_version_check=y
                ;;
            --inhibit-version-update)
                inhibit_version_update=y
                ;;
            --internal-updated-from)
                shift
                updated_from="$1"
                ;;
            --internal-relaunched-from)
                shift
                relaunched_from="$1"
                ;;
            --help|-h)
                _showhelp
                exit 0
                ;;
            --version|-v)
                _showversion
                exit 0
                ;;
            *)
                _user_error_fatal "unknown parameter \"$1\""
                ;;
        esac
        shift
    done

    ref="$1"

    case "$ref" in
        CS-*|SUPPORT-*|MMSSUPPORT-*)
            ticket_url=""#"https://jira.mongodb.org/browse/$ref"
            ;;
    esac
}


function _print_header {
    echo "========================="
    echo "MongoDB Diagnostic Report"
    echo "hostdiag.sh version $version"
    echo "========================="
    echo
}

function _check_for_ref {
    if [ "$ref" = "" ]; then
        echo "WARNING: No reference has been supplied.  If you have a ticket number or other"
        echo "reference, you should re-run hostdiag.sh and pass it on the command line."
        echo "Run \"bash hostdiag.sh --help\" for help."
        echo
    fi
}

function _print_user_run_advice {
    if [ "$ref" ]; then
        echo "Reference: $ref"
        if [ "$ticket_url" ]; then
            echo "Ticket URL: $ticket_url"
        fi
        echo
    fi
    echo "Please wait while diagnostic information is gathered"
    echo "into the $finaloutput file..."
    echo
    echo "If the display remains stuck for more than 5 minutes,"
    echo "please press Control-C."
    echo
}

function _print_end {
    cat <<EOF

==============================================================
MongoDB diagnostic information has been recorded in the file:

    $finaloutput

Please upload that file to the ticket${ticket_url:+ at:
    $ticket_url}
==============================================================

EOF
}

function _read_ynq {
    local msg="$1"
    local default="${2:-y}"
    local choices="("
    if [ "$default" = y ]; then choices+="Y"; else choices+="y"; fi
    choices+="/"
    if [ "$default" = n ]; then choices+="N"; else choices+="n"; fi
    choices+="/"
    if [ "$default" = q ]; then choices+="Q"; else choices+="q"; fi
    choices+=")"
    local prompt="$msg $choices? "
    if [ "${auto_answer+set}" = set ]; then
        REPLY="$auto_answer"
        echo "$prompt$auto_answer (auto-answer)"
    else
        while :; do
            read -r -p "$prompt"
            case "$REPLY" in
                ""|[YyNnQq])
                    break
                    ;;
                *)
                    echo 'Please enter "y"(es), "n"(o), "q"(uit), or Enter for default '"($default)."
                    ;;
            esac
        done
    fi
    case "$REPLY" in
        "")
            REPLY="$default"
            ;;
        [Qq])
            echo "hostdiag.sh: Aborting at user request"
            exit 0
            ;;
    esac
}

function _clean_download_target {
    rm -f "$download_target"
}

function _get_with {
    if ! type -p "$1" > /dev/null; then
        return 1
    fi

    _clean_download_target   # remove any old version
    "$@"
    local _rc=$?
    if [ $_rc -ne 0 ]; then
        _clean_download_target   # get rid of any partial download
    fi
    return $_rc
}

function _get_with_wget {
    _get_with wget --quiet --tries 1 --timeout 10 --output-document "$download_target" "$download_url"
}

function _get_with_curl {
    _get_with curl --silent --retry 0 --connect-timeout 10 --max-time 120 --output "$download_target" "$download_url"
}

#function _check_for_new_version {
#    if [ "$inhibit_new_version_check" != y -a "$updated_from" = "" -a "$relaunched_from" = "" ]; then
#        download_url='https://raw.githubusercontent.com/mongodb/support-tools/master/mdiag/mdiag.sh'
#        # FIXME: put this (and everything) into an $outputbase-based subdir
#        download_target="$outputbase-$$-mdiag.sh"
#        trap _clean_download_target EXIT   # don't leak downloaded script on shell exit
#        echo "Checking for a newer version of mdiag.sh..."
#        # first try wget, then try curl, then give up
#        if ! _get_with_wget; then
#            if ! _get_with_curl; then
#                echo "Warning: Unable to check for a newer version."
#            fi
#        fi
#        if [ -s "$download_target" ]; then
#            if cmp -s "$0" "$download_target"; then
#                echo "No new version available."
#            else
#                newversion="$(sed -e '/^version="/{s/"$//;s/^.*"//;q}' -e 'd' "$download_target")"
#                if [ "$newversion" = "" ]; then
#                    newversion="(unknown)"
#                fi
#                echo "NEW VERSION FOUND: $newversion"
#                echo
#                if [ "$inhibit_version_update" = y ]; then
#                    echo "Warning: Auto version update $0 not possible (user-inhibited)"
#                    update_not_possible=y
#                elif [ ! -w "$0" ]; then
#                    echo "Warning: Auto version update $0 not possible (no write permission)"
#                    update_not_possible=y
#                else
#                    _read_ynq "Update $0 to this version"
#                    case "$REPLY" in
#                        [Yy]|"")
#                            echo "Updating $0 to version $newversion..."
#                            # Using cat like this will preserve ownership, permissions, etc.
#                            # Important since we might (should) be running as root.
#                            if cat "$download_target" > "$0"; then
#                                echo "Launching updated version of $0..."
#                                echo
#                                _clean_download_target   # trap EXIT doesn't fire on exec
#                                exec bash "$0" --internal-updated-from "$version" "$@"
#                            else
#                                echo "mdiag.sh: ERROR: failed to update $0 to new version..."
#                                exit 1
#                            fi
#                            ;;
#                        [Nn])
#                            echo "Not updating to $0"
#                            user_elected_no_update=y
#                            ;;
#                    esac
#                fi
#                # If we get here, either user said not to replace $0, or no write permission.
#                # Offer to run the new version anyway.
#                _read_ynq "Use new version of mdiag.sh without updating"
#                case "$REPLY" in
#                    [Yy]|"")
#                        echo "Running new version without updating $0..."
#                        echo
#                        bash "$download_target" --internal-relaunched-from "$version" "$@"
#                        local _rc=$?
#                        _clean_download_target
#                        exit $_rc
#                        ;;
#                    [Nn])
#                        echo "Not using new version $newversion, continuing with existing version $version..."
#                        user_elected_not_to_run_newversion=y
#                        ;;
#                esac
#            fi
#        fi
#        echo
#    fi
#}

function _check_valid_output_format {
    case "$outputformat" in
        txt|json)
            # valid
            outputMongoFormat=false
            ;;
        text)
            # valid alias
            outputformat="txt"
            outputMongoFormat=false
            ;;
        mjson)
            # valid alias
            outputformat="json"
            outputMongoFormat=true
            ;;
        *)
            # invalid
            _user_error_fatal "unsupported output format \"$outputformat\""
            ;;
    esac
}

function _init_output_vars {
    numoutputs=0

    # FIXME: use mktemp if possible
    mainoutput="$outputbase-$$.$outputformat"
    finaloutput="$outputbase.$outputformat"
    touch $mainoutput
    iconv -t UTF-8  $mainoutput -o $mainoutput
}

function _nextoutput {
    numoutputs=$(($numoutputs + 1))
    outputnum=$numoutputs

    # So I know that using $$ is not as good as mktemp, but it needs to stay in here,
    # even if/when we move to mktemp, so that subshells which output don't use the same
    # output files.
    outfile="$outputbase-$$.$outputnum.out"
    errfile="$outputbase-$$.$outputnum.err"
}

function _now {
    date -Ins | sed -e 's/,\([0-9]\{3\}\)[0-9]\{6\}/.\1/'
}

function _graboutput {
    exec >> "$outfile" 2>> "$errfile"
}

function _ungraboutput {
    exec 1>&3 2>&4
}

function _json_strings_arrayify {
    local a=("$@")
    a=("${a[@]//\\/\\\\}") # this fixes vim syntax highlighting -> "
    a=("${a[@]//\"/\\\"}")
    a=("${a[@]//    /\\t}")
    a=("${a[@]//$_lf/\\r}")
    a=("${a[@]/#/\"}")
    a=("${a[@]/%/\",}")
    if [ ${#a[@]} -gt 0 ]; then
        a[$(( ${#a[@]} - 1 ))]="${a[$(( ${#a[@]} - 1 ))]%,}"
    fi
    echo -n "[ ${a[@]} ]"
}

function _json_stringify {
    local s="$*"
    s="${s//\\/\\\\}" # this fixes vim syntax highlighting -> "
    s="${s//\"/\\\"}"
    s="${s//    /\\t}"
    s="${s//$_lf/\\r}"
    echo -n "\"$s\""
}

function _json_dateify {
    echo -n "{ \"\$date\" : $(_json_stringify "$1") }"
}

function _do_json_lines_arrayify {
    echo "["
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/^/    "/' -e 's/$/"/' -e '$s/$/ ]/'
}

function _json_lines_arrayify {
    if [ $# -eq 0 ]; then
        # Can't use `local input="$(cat)"` because that strips trailing newline.
        local input
        IFS= read -rd '' input
        if [ "$input" ]; then
            # Can't use `_do_json_lines_arrayify <<<"$input"` because that adds a trailing newline
            # (since it's modelled on `<<EOF`, which by design always has a trailing newline).
            echo -n "$input" | _do_json_lines_arrayify
        else
            echo -n "null"
        fi
    else
        if [ -s "$1" ]; then
            _do_json_lines_arrayify < "$1"
        else
            echo -n "null"
        fi
        if [ -f "$1" ]; then
            # feels risky to have this here...
            rm -f "$1"
        fi
    fi
}

function _jsonify {
    local t="$1"
    shift
    local val
    case "$t" in
        string)
            val="$(_json_stringify "$*")"
            ;;
        date)
            val="$(_json_dateify "$*")"
            ;;
        null)
            val="null"
            ;;
        number)
            case "$1" in
                *[^0-9.+-]*)
                    # FIXME: check properly
                    val="$(_json_stringify "$1")"
                    ;;
                "")
                    val="null"
                    ;;
                *)
                    val="$1"
                    ;;
            esac
            ;;
        boolean)
            # FIXME: check it's valid
            val="$1"
            ;;
        strings_array)
            val="$(_json_strings_arrayify "$@")"
            ;;
        file_lines_array)
            val="$(_json_lines_arrayify "$1")"
            ;;
        *)
            val="$*"
            ;;
    esac
    echo -n "$val"
}

function _reset_vars {
    unset ts_started ts_ended ts command rc types fields values outputnum output_fieldname
    types=()
    fields=()
    values=()
}

function _emit_txt {
    echo ""
    echo ""
    echo "=========== start section $section ==========="

    if [ "$subsection" ]; then
        echo "--> start subsection $subsection <--"
    fi
    if [ "$section_group" ]; then
        echo "section_group:$section_group"
    fi
    if [ "$ts" ]; then
        echo "Date: $ts"
    fi
    if [ "$ts_started" ]; then
        echo "Started: $ts_started"
    fi
    if [ "$ts_ended" ]; then
        echo "Ended: $ts_ended"
    fi
    if [ "${#command[@]}" -gt 0 ]; then
        echo "Command: $(_jsonify strings_array "${command[@]}")"
    fi
    if [ "$rc" ]; then
        echo "RC: $rc"
    fi
    if [ "${#fields[@]}" -gt 0 ]; then
        local i val
        echo "Extra info:"
        for i in "${!fields[@]}"; do
            echo "    ${fields[$i]}: ${values[$i]}"
        done
    fi
    if [ -e "$errfile" ]; then
        echo "Stderr output:"
        cat "$errfile"
        rm -f "$errfile"
    fi
    if [ -e "$outfile" ]; then
        echo "Output:"
        grep -Ev '^\+ (_?end ?runcommands( runcommands)?|rc=-?[0-9]+|set \+x)$' "$outfile"
        rm -f "$outfile"
    fi
    if [ "$subsection" ]; then
        echo "--> end subsection $subsection <--"
    fi
    echo "============ end section $section ============"
}

function _output_preamble_txt {
    {
        echo "========================="
        echo "MongoDB Diagnostic Report"
        echo "hostdiag.sh version $version"
        echo "========================="
    } >> "$1"
}

function _output_postamble_txt {
    :
}

JSON_OUTPUT_NUM=0

function _emit_json {
#tmpFile=`mktemp /tmp/hostdiag-XXXXXXXXXXXXXXXXXXXXXXXXXXX`
#rm -rf $tmpFile
#_id=${tmpFile//\/tmp\/hostdiag-/}
((JSON_OUTPUT_NUM++))
_id=$JSON_OUTPUT_NUM

    echo "{"
    {
    echo "\"_id\" : $_id"
    echo "\"section_group\" : $(_jsonify string "$section_group")"
    echo "\"section\" : $(_jsonify string "$section")"
    if [ "$subsection" ]; then
        echo "\"subsection\" : $(_jsonify string "$subsection")"
    fi
    echo "\"host\" : $host_json"
    echo "\"ref\" : $ref_json"
    echo "\"tag\" : $tag_json"
    echo "\"version\" : $version_json"
    if [ "$ts_started" -o "$ts_ended" ]; then
        echo "\"ts\" : {"
        if [ "$ts_started" ]; then
            echo -n "    \"start\" : $(_jsonify date "$ts_started")"
        fi
        if [ "$ts_started" -a "$ts_ended" ]; then
            echo ""
        fi
        if [ "$ts_ended" ]; then
            echo -n "      \"end\" : $(_jsonify date "$ts_ended")"
        fi
        echo " }"
    elif [ "$ts" ]; then
        echo "\"ts\" : $(_jsonify date "$ts")"
    fi
    if [ "${#command[@]}" -gt 1 ]; then
        echo "\"command\" : $(_jsonify strings_array "${command[@]}")"
    elif [ -n "$command" ] ; then
        echo "\"command\" : $(_jsonify string "${command}")"
    fi

    if [ "$rc" ]; then
        echo "\"rc\" : $(_jsonify number "$rc")"
    fi
    if [ "${#fields[@]}" -gt 0 ]; then
        local i val
        for i in "${!fields[@]}"; do
            echo "$(_jsonify string "${fields[$i]}") : $(_jsonify "${types[$i]}" "${values[$i]}")"
        done
    fi
    echo "\"${output_fieldname:-output}\" : $(_jsonify file_lines_array "$outfile")"
    echo "\"error\" : $(_jsonify file_lines_array "$errfile")"
    } | sed -e 's/^/    /' -e 's/\([^:{[]\)$/\1,/' -e '$s/,$//'
    echo "},"
}

function _output_preamble_json {
    # Static strings that don't change
    ref_json="$(_jsonify string "$ref")"
    host_json="$(_jsonify string "$host")"
    tag_json="$(_jsonify date "$tag")"
    version_json="$(_jsonify string "$version")"

    if [ "$outputMongoFormat" != "true" ] ; then
        echo '[' >> "$1"
    fi
}

function _output_postamble_json {
    # Change the final comma to "]", to close the array
    if [ "$outputMongoFormat" != "true" ] ; then
        sed -e '$s/^},$/}]/' "$1" > "$1.new" && mv -f "$1.new" "$1"
    else
        sed -e '$s/^},$/}/' "$1" > "$1.new" && mv -f "$1.new" "$1"
    fi
}


function _emit {
    _emit_"$outputformat" >> "$mainoutput"
    # unset all the variables that have been output, except section/subsection/ref/etc
    _reset_vars
}

function _setup_fds {
    exec 3>&1

    # Grab any stray stderr
    _nextoutput
    stray_stderr_outfile="$errfile"
    exec 4>> "$stray_stderr_outfile"
    exec 2>&4
}

function _teardown_fds {
    exec 2>&1   # stderr back to console
    exec 4>&-   # close the file so it gets flushed
}

function _output_preamble {
    _output_preamble_"$outputformat" "$mainoutput"
}

function _output_postamble {
    section stray_stderr
    errfile="$stray_stderr_outfile"
    _emit
    endsection

    _output_postamble_"$outputformat" "$mainoutput"
}


function _addfield {
    types+=("$1")
    fields+=("$2")
    values+=("$3")
}

function _finish {
    [ -e "$finaloutput" ] && mv -f "$finaloutput" "$finaloutput.out"
    mv -f "$mainoutput" "$finaloutput"
}



if [ "${__MDIAG_UNIT_TEST:-unset}" = "unset" ]; then
    _main "$@"
fi