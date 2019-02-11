#! /bin/bash

if [ $# -lt 2 ] ; then
  echo "usetag:haproxy_config.sh vip cls_host_list"
  exit 1
fi
. /etc/bashrc

. $APP_BASE/install/funs.sh

VIP="*" #$1 $2
#if [ "$INSTALL_LVS" = "true" ] ; then # ins lvs need Specify IP and VIP used LVS ,
#    VIP="$LOCAL_IP"
#fi
VIP="*" # 减少iptables 设置

# 可能存在应用不是在所有机器上都安装的情况
CLS_HOST_LIST=`cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;do.*//'`
FISRTHOST=`echo $CLS_HOST_LIST|awk '{print $1}'`
OLD_IFS=$IFS
#IFS=,
mkdir -p /etc/haproxy/errorfiles
echo "Http Client Error detected by HAproxy, Error Code is: 403 Forbidden.

The backend server is refusing to respond to the client\'s request.

">/etc/haproxy/errorfiles/403.http
echo "Http Server Error Detected by HAproxy, Error Code is: 500 Internal Server Error.

The backend server seem to have an unexpected error.
">/etc/haproxy/errorfiles/500.http
echo "Http Server Error Detected by HAproxy, Error Code is: 502 Bad Gateway.

The backend server was acting as a gateway or proxy and received an invalid response from the upstream server.
">/etc/haproxy/errorfiles/502.http
echo "Http Server Error Detected by HAproxy, Error Code is:503 Service Unavailable.

The backend server is currently unavailable (because it is overloaded or down for maintenance).
">/etc/haproxy/errorfiles/503.http
echo "Http Server Error Detected by HAproxy, Error Code is:504 Gateway Timeout.

The backend server was acting as a gateway or proxy and did not receive a timely response from the upstream server.
">/etc/haproxy/errorfiles/504.http

isMapp80=false

HTTP_FRONT_DEFAULTS="    #http 通用设置
    mode    http
    option    httplog
    option  http-keep-alive
    #option    httpclose
    option forwardfor header ORIG_CLIENT_IP
#    option forwardfor header Client-IP
    timeout http-request    10s
    timeout client          30s
    timeout http-keep-alive 10s
    errorfile 403 /etc/haproxy/errorfiles/403.http
    errorfile 500 /etc/haproxy/errorfiles/500.http
    errorfile 502 /etc/haproxy/errorfiles/502.http
    errorfile 503 /etc/haproxy/errorfiles/503.http
    errorfile 504 /etc/haproxy/errorfiles/504.http
    "

HTTP_BACK_DEFAULTS="    #http 通用设置
    option    httplog
    option   http-server-close
    option  http-keep-alive
    #option   httpclose
    balance    source
    option    redispatch
    retries    2
    timeout http-request    10s
    timeout queue           1m
    timeout connect         5s
    timeout server          30s
    timeout http-keep-alive 10s
    timeout check           5s
    cookie SERVERID insert indirect nocache
    "

HTTP_ALL_DEFAULTS="    #http 通用设置
    mode    http
    option    httplog
    option  http-keep-alive
    #option    httpclose
    balance    source
    option forwardfor header ORIG_CLIENT_IP
#    option forwardfor header Client-IP
    option    redispatch
    retries    2
    timeout http-request    10s
    timeout queue           1m
    timeout connect         5s
    timeout server          30s
    timeout client          30s
    timeout http-keep-alive 10s
    timeout check           5s
    cookie SERVERID insert indirect nocache
    errorfile 403 /etc/haproxy/errorfiles/403.http
    errorfile 500 /etc/haproxy/errorfiles/500.http
    errorfile 502 /etc/haproxy/errorfiles/502.http
    errorfile 503 /etc/haproxy/errorfiles/503.http
    errorfile 504 /etc/haproxy/errorfiles/504.http
    "

HTTP_ACL_CONTROL="    # 性能测试时需要关闭
    acl too_fast fe_sess_rate ge 50 # 速率大于50 延时 50ms
    tcp-request inspect-delay 50ms
    tcp-request content accept if ! too_fast
    tcp-request content accept if WAIT_END
    # 性能测试时需要关闭 end
"
HTTP_ACL_CONTROL="" #压力测试

TCP_DEFAULTS="    #tcp 通用设置
    mode tcp
    timeout connect 20s # default 10 second time out if a backend is not found
    timeout client 3650d #只是解决警告
    timeout server 3650d #只是解决警告
    timeout check 15s
    option tcplog
    #option    tcpka
    #tcp 通用设置 end
"

nbproc=1

echo "#cd /etc/haproxy/"
echo "#touch haproxy.cfg"
echo "#vi /etc/haproxy/haproxy.cfg"

#global配置
echo ""
echo "global"
echo "    stats socket  /tmp/haproxy level admin #echo \"show info\" | sudo socat stdio unix-connect:/tmp/haproxy "
echo "    log 127.0.0.1   local0 notice ##记日志的功能"
echo "    maxconn 64000"  #设定每个haproxy进程所接受的最大并发连接数
echo "    tune.ssl.default-dh-param 2048 "
echo "    tune.maxaccept 512 " # 设定haproxy进程内核调度运行时一次性可以接受的连接的个数，较大的值可以带来较大的吞吐率
echo "    tune.maxpollevents 512 " #设定一次系统调用可以处理的事件最大数，默认值取决于OS；其值小于200时可节约带宽，但会略微增大网络延迟，而大于200时会降低延迟，但会稍稍增加网络带宽的占用量
echo "    tune.maxrewrite 1024 " #设定为首部重写或追加而预留的缓冲空间，建议使用1024左右的大小；在需要使用更大的空间时，haproxy会自动增加其值
echo "    chroot    /var/lib/haproxy"
echo "    user        haproxy "
echo "    group        haproxy"
echo "    daemon "
echo "    nbproc    $nbproc   "               #进程数量
echo "    pidfile    /var/run/haproxy.pid "
echo "    log-send-hostname
    spread-checks 50
    node `hostname`"

#defaults配置
echo " "
echo "defaults "
echo "    log        global "
echo "    mode http"
echo "    option   httplog "
echo "    option    dontlognull"
echo "    retries    3"
echo "    option    redispatch " #当serverId对应的服务器挂掉后，强制定向到其他健康的服务器
echo "    retries    3"
echo "    balance  source"
echo "    maxconn    64000 "
echo "    timeout connect 10s"    #连接超时，网络状态不好时，可能引起应用连接被中断

echo "#   下面两个超时不要配置到默认参数中，超时过短可能导致mysql的tcp链接断开，不配置则默认无超时 "
echo "#    timeout client 120s    #客户端超时 "
echo "#    timeout server 120s    #服务器超时 "
echo "#tcp-request content accept if { src -f /usr/local/haproxy/white_ip_list }
#   tcp-request content reject
#resolvers mydns
#    nameserver dns1 192.168.80.1:53
#    nameserver dns2 192.168.80.1:53
#    resolve_retries       3
#    timeout retry         1s
#    hold other           30s
#    hold refused         30s
#    hold nx              30s
#    hold timeout         30s
#    hold valid           10s
"

#admin_status配置
echo " "
echo "listen  Admin_status:48800 "
echo "    bind ${VIP}:48800 ##VIP "
echo "    stats uri /admin-status        ##统计页面"
echo "    stats auth  admin:admin"
echo "    mode    http "
echo "    option  httplog"
echo "    stats hide-version              #隐藏统计页面上HAProxy的版本信息 "
echo "    option    httpclose"
echo "    stats refresh 30s               #统计页面自动刷新时间"
echo "#      stats    admin if TRUE"
echo "    timeout connect    10s "
echo "    timeout server    10s "
echo "    timeout client    10s  "

for host in $CLS_HOST_LIST ; do
    echo "    server ${host} ${host}:22 check inter 30s rise 2 fall 2 weight 1"
done

#HAProxy的日志记录内容设置
echo ""
echo "#################HAProxy的日志记录内容设置###################
    capture request header Host len 40
    capture request header Content-Length len 10
    capture request header Referer len 200
    capture response header Server len 40
    capture response header Content-Length len 10
    capture response header Cache-Control len 8 "
echo "
    errorfile 403 /etc/haproxy/errorfiles/403.http
    errorfile 500 /etc/haproxy/errorfiles/500.http
    errorfile 502 /etc/haproxy/errorfiles/502.http
    errorfile 503 /etc/haproxy/errorfiles/503.http
    errorfile 504 /etc/haproxy/errorfiles/504.http"

#zookeeper
appName="zookeeper"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:2182 ${VIP}:2182"
    echo "listen ${appName}:2182"
    echo "    bind ${VIP}:2182"
    echo "$TCP_DEFAULTS"
    echo "    option httpchk OPTIONS * HTTP/1.1\r\nHost:\ www"
    echo "    balance static-rr" #roundrobin
    appHosts=`getAppHosts zookeeper`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:2181 check port 49997 inter 15s rise 2 fall 2 weight 1"
    done
fi

#mysql
appName="mysql"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:3307 ${VIP}:3307"
    echo "listen ${appName}:3307"
    echo "    bind ${VIP}:3307"
    echo "$TCP_DEFAULTS"
    echo "    balance static-rr"
    if [ "`check_app mycat`" = "true" -a "$MYSQL_HA_USE_MYCAT" = "true" ] ; then
        mysqlPort="8066 check"
        appHosts=`getAppHosts mycat`
        for host in $appHosts ; do
            echo "    server ${host} ${host}:$mysqlPort inter 10s rise 2 fall 2 weight 1"
        done
    else
        echo "    option httpchk OPTIONS * HTTP/1.1\r\nHost:\ www"
        mysqlPort="3306 check backup port 49999"
        appHosts=`getAppHosts mysql `
        for host in $appHosts ; do
            echo "    server ${host} ${host}:$mysqlPort inter 10s rise 2 fall 2 weight 1"
        done
    fi
fi

#mongo
appName="mongo"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:27019 ${VIP}:27019"
    echo "listen ${appName}:27019"
    echo "    bind ${VIP}:27019"
    echo "$TCP_DEFAULTS"
    echo "    option httpchk OPTIONS * HTTP/1.1\r\nHost:\ www"
    echo "    balance static-rr"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:27017 check port 49995 inter 30s rise 2 fall 2 weight 1"
    done
fi

#codis
appName="codis"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:6307 ${VIP}:6307"
    echo "listen ${appName}:6307"
    echo "    bind ${VIP}:6307"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:6377 check inter 30s rise 2 fall 2 weight 1"
    done
fi

#redis
appName="redis"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:6391 ${VIP}:6391 "
    echo "listen ${appName}:6391"
    echo "    bind ${VIP}:6391"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:6390 check inter 30s rise 2 fall 2 weight 1"
    done
fi

#eagles
appName="eagles"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9121 ${VIP}:9121"
    echo "listen ${appName}:9121"
    echo "    bind ${VIP}:9121"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /_cluster/health"
    appHosts=`getAppHosts eagles`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:17100 check inter 10s rise 2 fall 2"
    done

    if [ "`check_app eagleslog`" != "true" -o "`check_app otcserver`" != "true" ] ; then
        echo
        echo "#${appName}"
        # echo "listen eagleslog:19121 ${VIP}:19121"
        echo "listen eagleslog:19121"
        echo "    bind ${VIP}:19121"
        echo "$HTTP_ALL_DEFAULTS"
        echo "    option httpchk GET /_cluster/health"
        appHosts=`getAppHosts ${appName}`
        for host in $appHosts ; do
            echo "    server ${host} ${host}:18100 check inter 10s rise 2 fall 2"
        done
    fi
fi

#eagleslog
appName="eagleslog"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:19121 ${VIP}:19121"
    echo "listen ${appName}:19121"
    echo "    bind ${VIP}:19121"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /_cluster/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:18100 check inter 10s rise 2 fall 2"
    done
fi

#elasticsearch
appName="elasticsearch"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9201 ${VIP}:9201"
    echo "listen ${appName}:9201"
    echo "    bind ${VIP}:9201"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /_cluster/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9200 check inter 10s rise 2 fall 2"
    done
fi

#nump
appName="nump"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:10056 ${VIP}:10056"
    echo "listen ${appName}:10056"
    echo "    bind ${VIP}:10056"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /nump/"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:10057 check inter 15s rise 2 fall 2"
    done
fi

#cayman
appName="cayman"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9131 ${VIP}:9131"
    echo "listen ${appName}:9131"
    echo "    bind ${VIP}:9131"
    echo "$HTTP_ALL_DEFAULTS" | sed 's/source/leastconn/'
    echo "    option httpchk GET  /api/cayman/store/stat/global/get?debug=true"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:80 check inter 10s rise 1 fall 2"
    done
fi

echo " "
echo "frontend Public1:88"
echo "    bind  ${VIP}:88 "
echo "    mode  http "
echo "    log        global "
echo "    option        httplog"
echo "    option          dontlognull"
echo "    option    forwardfor except 127.0.0.1"
echo "    monitor-uri    /monitoruri"
echo "$HTTP_FRONT_DEFAULTS"
echo "$HTTP_ACL_CONTROL"
echo "    # Host: will use a specific keyword soon "
echo "    #use_backend    ^Host:\ img        static "
echo " "
echo "    #    The URI will use a specific keyword soon "
echo "    #    use_backend    ^[^\ ]*\ /(img|css)/    static "

if [ "`check_app hivecore`" = "true" ] ; then
    echo "
    acl fp url_reg -i ^(/sobeyhive-fp)
    use_backend hivecore_fp:88 if fp
    acl bp url_reg -i ^(/sobeyhive-bp)
    use_backend hivecore_bp:88 if bp"
fi

if [ "`check_app hivepmp`" = "true" ] ; then
    echo "
    acl pmp url_reg -i ^(/sobeyhive-pmp)
    use_backend hivepmp:88 if pmp"
fi

if [ "`check_app ftengine2`" = "true" ] ; then
    echo "
    acl ftengine url_reg -i ^(/ftengine)
    use_backend ftengine2:88 if ftengine"
fi

# if [ "`check_app galaxy`" = "true" ] ; then
    # echo "
    # acl galaxy url_reg -i ^(/galaxy)
    # use_backend galaxy:88 if galaxy"
# fi

# if [ "`check_app paasman`" = "true" ] ; then
    # echo "
    # acl paasman url_reg -i ^(/cluster)
    # use_backend paasman:88 if paasman"
# fi

# if [ "`check_app sobeyficus_zuul`" = "true" ] ; then
    # echo "
    # acl sobeyficus_zuul url_reg -i ^(/sobey-ficus)
    # use_backend sobeyficus_zuul:88 if sobeyficus_zuul"
    # if [ "`check_app nebula`" != "true" ]; then
        # echo "    default_backend    sobeyficus_zuul:88"
    # fi
# fi

if [ "`check_app nebula`" = "true" -a "`check_app solar`" != "true" ] ; then
    echo "
    acl nebula url_reg -i ^(/nebula)
    acl api url_reg -i ^(/api)
    use_backend nebula:88 if nebula || api
    default_backend    nebula:88"
elif [ "`check_app nebula`" = "true" -a "`check_app solar`" = "true" ] ; then
    echo "
    acl nebula url_reg -i ^(/nebula)
    acl nextgen url_reg -i ^(/nextgen)
    acl nump-api url_reg -i ^(/nump-api)
    acl nextgen-api url_reg -i ^(/nextgen-api)
    acl nebula-api url_reg -i ^(/nebula-api)
    acl nebula-web url_reg -i ^(/nebula-web)
    use_backend nebula:88 if nebula || nextgen || nump-api || nextgen-api || nebula-api || nebula-web"
fi

# if [ "`check_app pronebula`" = "true" ] ; then
    # echo "    acl pronebula url_reg -i ^(/pronebula)
    # use_backend pronebula:88 if pronebula
    # acl nextgen url_reg -i ^(/nextgen)
    # use_backend pronebula:88 if nextgen"
# fi

if [ "`check_app solar`" = "true" ] ; then
    echo "
    acl solar url_reg -i ^(/solar)
    use_backend solar:88 if solar
    default_backend    solar:88"
fi

#hivecore
appName="hivecore"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend hivecore_fp:88"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /sobeyhive-fp"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8060 cookie hivecore_fp_${host} check inter 10s rise 1 fall 2 weight 1"
    done

    echo
    echo "#${appName}"
    echo "backend hivecore_bp:88"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /sobeyhive-bp"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8060 cookie hivecore_bp_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#hivepmp
appName="hivepmp"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /sobeyhive-pmp"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8050 check inter 10s rise 1 fall 2 weight 1"
    done
fi

#ftengine2
appName="ftengine2"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /ftengine"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8090 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#nebula
appName="nebula"
if [ "`check_app ${appName}`" = "true" -a "`check_app solar`" != "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /nebula  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9090 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
elif [ "`check_app ${appName}`" = "true" -a "`check_app solar`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /nebula  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9096 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#pronebula
appName="pronebula"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /pronebula  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9096 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#solar
appName="solar"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /solar  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9090 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#tiaoweb
appName="tiaoweb"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}:88"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    #option httpchk GET /"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9088 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1 "
    done
fi

#pronebula
# appName="pronebula"
# if [ "`check_app ${appName}`" = "true" ] ; then
    # echo
    # echo "#${appName}"
    # echo "listen ${appName}:9097"
    # echo "    bind ${VIP}:9097"
    # echo "$HTTP_ALL_DEFAULTS"
    # echo "    option httpchk GET /api/version  HTTP/1.1\r\nHost:\ www"
    # appHosts=`getAppHosts ${appName}`
    # for host in $appHosts ; do
        # echo "    server ${host} ${host}:9096 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    # done
# fi

#archive
appName="archive"
if [ "`check_app nebula`" = "true" -a "`check_app otcserver`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9092 ${VIP}:9092"
    echo "listen ${appName}:9092"
    echo "    bind ${VIP}:9092"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    #斜杠转义空格用"
    echo "    http-response set-header Access-Control-Allow-Headers Origin,\ Content-Type,\ X-Requested-With,\ Accept,\ sobeyhive-http-system,\ #sobeyhive-http-site,\ sobeyhive-http-token,\ sobeyhive-http-tool"
    echo "    option httpchk HEAD /  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9089 cookie ${appName}_${host} check inter 10s rise 2 fall 2 weight 1"
    done
fi

#galaxy
appName="galaxy"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:4201 ${VIP}:4201"
    echo "listen ${appName}:4201"
    echo "    bind ${VIP}:4201"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:4200 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#paasman
appName="paasman"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:98 ${VIP}:98"
    echo "listen ${appName}:98"
    echo "    bind ${VIP}:98"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /cluster  HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:64000 cookie ${appName}_${host} check inter 10s rise 1 fall 2 weight 1"
    done
fi

#sobeyficus_eureka
appName="sobeyficus_eureka"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    # option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8765 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_config_server
appName="sobeyficus_config_server"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8777 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus
appName="sobeyficus"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:8041 ${VIP}:8041"
    echo "listen ${appName}:8041"
    echo "    bind ${VIP}:8041"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8040 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_admin_ui
appName="sobeyficus_admin_ui"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8799 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_zuul
appName="sobeyficus_zuul"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8030 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_web
appName="sobeyficus_web"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8100 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_python_driver
appName="sobeyficus_python_driver"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8039 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_script_java_executor
appName="sobeyficus_script_java_executor"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8049 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#sobeyficus_script_python_executor
appName="sobeyficus_script_python_executor"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /actuator/health"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8048 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#pandabi
appName="pandabi"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "listen ${appName}:8200"
    echo "    bind ${VIP}:8201"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8200 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#spider
appName="spider"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "listen ${appName}:8202"
    echo "    bind ${VIP}:8203"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:8202 check inter 15s rise 2 fall 3 weight 1"
    done
fi

#cmserver
appName="cmserver"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9023 ${VIP}:9023"
    echo "listen ${appName}:9023"
    echo "    bind ${VIP}:9023"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none} " | sed 's/source/static-rr/'
    echo "    #斜杠转义空格用"
    echo "    http-response set-header Access-Control-Allow-Headers Origin,\ Access-Control-Allow-Origin,\ Content-Type,\ X-Requested-With,\ Accept,\ sobeyhive-http-system,\ sobeyhive-http-site,\ sobeyhive-http-token,\ sobeyhive-http-tool"
    echo "    rspadd Access-Control-Allow-Headers:sobeyhive-http-system,sobeyhive-http-site,sobeyhive-http-token"
    echo "    option httpchk GET /CMApi/api/basic/account/testconnect"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9022 check inter 10s rise 1 fall 2"
    done
fi

#cmweb
appName="cmweb"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9021 ${VIP}:9021"
    echo "listen ${appName}:9021"
    echo "    bind ${VIP}:9021"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none} "
    echo "    #斜杠转义空格用"
    echo "    http-response set-header Access-Control-Allow-Headers Origin,\ Content-Type,\ X-Requested-With,\ Accept,\ sobeyhive-http-system,\ #sobeyhive-http-site,\ sobeyhive-http-token,\ sobeyhive-http-tool"
    echo "    option httpchk GET /index.aspx"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9020 check inter 15s rise 2 fall 2"
    done
fi

#cmnotify
appName="cmnotify"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9601 ${VIP}:9601"
    echo "listen ${appName}:9601"
    echo "    bind ${VIP}:9601"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9600 cookie ${appName}_${host} check inter 15s rise 3 fall 3 weight 1"
    done
fi

echo " "
echo "frontend Public2:86"
echo "    bind  ${VIP}:86 "
echo "    mode  http "
echo "    log        global "
echo "    option        httplog"
echo "    option          dontlognull"
echo "    option    forwardfor except 127.0.0.1"
echo "    monitor-uri    /monitoruri"
echo "$HTTP_FRONT_DEFAULTS"
echo "$HTTP_ACL_CONTROL"
if [ "`check_app docker`" = "true" ] ; then
    echo "    acl streams url_reg -i ^(/bucket.*)
    use_backend streams:86 if streams
    default_backend streams:86"
fi

# if [ "`check_app ntag`" = "true" ] ; then
    # echo "    acl ntag url_reg -i /.*
    # use_backend Ntag:86 if ntag
    # default_backend Ntag:86"
# else
    # echo "    default_backend Streams_Bucket:86"
# fi

#streams
appName="docker"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#streams"
    echo "backend streams:86"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS" | sed 's/source/leastconn/'
    echo "    option httpchk GET /hacheck/index.html"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9010 cookie ${appName}_${host} check inter 15s rise 1 fall 2 weight 1"
    done
fi

#ntag
appName="ntag"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "  option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /user/#/login"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9060 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#search
appName="search"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "  option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /#!/login"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9060 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#mamcore
appName="mamcore"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /ha-check HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9080 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#megateway
appName="megateway"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /megateway"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9070 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#archivemanager
appName="archivemanager"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /archivemanager/index"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9071 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#lifecyclemanager
appName="lifecyclemanager"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    echo "backend ${appName}"
    echo "    option http-server-close"
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk HEAD /lifecyclemanager"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9072 cookie ${appName}_${host} check inter 15s rise 2 fall 2 weight 1"
    done
fi

#infoshare
appName="infoshare"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9082 ${VIP}:9082"
    echo "listen ${appName}:9082"
    echo "    bind ${VIP}:9082"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /news"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9081 check inter 10s rise 2 fall 2"
    done
fi

#ingestdbsvr
appName="ingestdbsvr"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9025 ${VIP}:9025"
    echo "listen ${appName}:9025"
    echo "    bind ${VIP}:9025"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none} " | sed 's/source/static-rr/'
    echo "    #斜杠转义空格用"
    echo "    http-response set-header Access-Control-Allow-Headers Origin,\ Content-Type,\ X-Requested-With,\ Accept,\ sobeyhive-http-system,\ #sobeyhive-http-site,\ sobeyhive-http-token,\ sobeyhive-http-tool"
    echo "    option httpchk GET /api/device/GetAllCaptureChannels"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9024 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#mosgateway
appName="mosgateway"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:10540 ${VIP}:10540"
    echo "listen ${appName}:10540"
    echo "    bind ${VIP}:10540"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:10550 check inter 15s rise 1 fall 1 weight 1"
    done

    echo
    echo "#${appName}"
    # echo "listen ${appName}:10541 ${VIP}:10541"
    echo "listen ${appName}:10541"
    echo "    bind ${VIP}:10541"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:10551 check inter 15s rise 1 fall 1 weight 1"
    done

    echo
    echo "#${appName}"
    # echo "listen ${appName}:10542 ${VIP}:10542"
    echo "listen ${appName}:10542"
    echo "    bind ${VIP}:10542"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:10552 check inter 15s rise 1 fall 1 weight 1"
    done

    echo
    echo "#${appName}"
    # echo "listen ${appName}:10555 ${VIP}:10555"
    echo "listen ${appName}:10555"
    echo "    bind ${VIP}:10555"
    echo "    option http-server-close "
    echo "$HTTP_BACK_DEFAULTS"
    echo "    option httpchk GET /index.htm "
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:10556 check inter 15s rise 1 fall 1 weight 1"
    done
fi

#jove
appName="jove"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9027 ${VIP}:9027"
    echo "listen ${appName}:9027"
    echo "    bind ${VIP}:9027"
    # echo "$HTTP_ALL_DEFAULTS"
    # echo "    option httpchk GET /Cm/Login?usertoken="
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9026 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#jovelite
appName="jovelite"
if [ "`check_app ${appName}`" = "true" ] ; then
    appHosts=`getAppHosts ${appName}`
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9029 ${VIP}:9029"
    echo "listen ${appName}:9029"
    echo "    bind ${VIP}:9029"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /"
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9028 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#otcserver
appName="otcserver"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9045 ${VIP}:9045"
    echo "listen ${appName}:9045"
    echo "    bind ${VIP}:9045"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none} " | sed 's/source/static-rr/'
    echo "    option httpchk GET /getotc HTTP/1.1\r\nHost:\ www"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9044 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#floatinglicenseserver
appName="floatinglicenseserver"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9033 ${VIP}:9033"
    echo "listen ${appName}:9033"
    echo "    bind ${VIP}:9033"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none} " | sed 's/source/static-rr/'
    echo "    option httpchk GET /testalive"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9032 check inter 15s rise 2 fall 2 weight 1"
    done

    echo
    echo "#${appName}"
    # echo "listen ${appName}:9031 ${VIP}:9031"
    echo "listen ${appName}:9031"
    echo "    bind ${VIP}:9031"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9030 check inter 15s rise 1 fall 2 weight 1"
    done
fi

#sangha
appName="sangha"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#sangha"
    # echo "listen sangha:4505 ${VIP}:4505"
    echo "listen sangha:4505"
    echo "    bind ${VIP}:4505"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:4504 check inter 30s rise 2 fall 2 weight 1"
    done

    #sanghaserver
    echo
    echo "#sanghaserver"
    # echo "listen sanghaserver:9047 ${VIP}:9047"
    echo "listen sanghaserver:9047"
    echo "    bind ${VIP}:9047"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none}"
    echo "    option httpchk GET /sobey/plat/cmd"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9046 check inter 15s rise 2 fall 2 weight 1"
    done

    #sanghaweb
    echo
    echo "#sanghaweb"
    # echo "listen sanghaweb:9049 ${VIP}:9049"
    echo "listen sanghaweb:9049"
    echo "    bind ${VIP}:9049"
    echo "${HTTP_ALL_DEFAULTS//option forwardfor header ORIG_CLIENT_IP/option forwardfor header ORIG_CLIENT_IP if-none}"
    echo "    option httpchk GET /Plat.Web/NormalServicePage.html"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9048 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#pns
appName="pns"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:11112 ${VIP}:11112"
    echo "listen ${appName}:11112"
    echo "    bind ${VIP}:11112"
    echo "$TCP_DEFAULTS"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:11111 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#actorfactory
appName="actorfactory"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9057 ${VIP}:9057"
    echo "listen ${appName}:9057"
    echo "    bind ${VIP}:9057"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /Actor/api/check"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9056 check inter 15s rise 3 fall 3 weight 1"
    done
fi

#cmproxy
appName="cmproxy"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9603 ${VIP}:9603"
    echo "listen ${appName}:9603"
    echo "    bind ${VIP}:9603"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk GET /test"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9602 check inter 15s rise 3 fall 3 weight 1"
    done
fi

#articleeditor
appName="articleeditor"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9209 ${VIP}:9209"
    echo "listen ${appName}:9209"
    echo "    bind ${VIP}:9209"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /mchEditor"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9208 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#h5
appName="h5"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9213 ${VIP}:9213"
    echo "listen ${appName}:9213"
    echo "    bind ${VIP}:9213"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /h5"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9212 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#infosharecloud
# appName="infosharecloud"
# if [ "`check_app ${appName}`" = "true" ] ; then
    # echo
    # echo "#${appName}"
    # echo "listen ${appName}:9082"
    # echo "bind ${VIP}:9082"
    # echo "$HTTP_ALL_DEFAULTS"
    # echo "    option httpchk HEAD /news"
    # appHosts=`getAppHosts ${appName}`
    # for host in $appHosts ; do
        # echo "    server ${host} ${host}:9081 check inter 15s rise 2 fall 2 weight 1"
    # done
# fi

#omniocp
appName="omniocp"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9201 ${VIP}:9201"
    echo "listen ${appName}:9201"
    echo "    bind ${VIP}:9201"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /tpp"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9200 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#omniportal
appName="omniportal"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9207 ${VIP}:9207"
    echo "listen ${appName}:9207"
    echo "    bind ${VIP}:9207"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /portal"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9206 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#omnizhihui
appName="omnizhihui"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9205 ${VIP}:9205"
    echo "listen ${appName}:9205"
    echo "    bind ${VIP}:9205"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD //adapter-app"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9204 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#wxeditor
appName="wxeditor"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9211 ${VIP}:9211"
    echo "listen ${appName}:9211"
    echo "    bind ${VIP}:9211"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /wxfb"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9210 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#taskmonitoring
appName="taskmonitoring"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9215 ${VIP}:9215"
    echo "listen ${appName}:9215"
    echo "    bind ${VIP}:9215"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /Sc-TaskMonitoring"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9214 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#planning
appName="planning"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9217 ${VIP}:9217"
    echo "listen ${appName}:9217"
    echo "    bind ${VIP}:9217"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /Sc-Planning"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9216 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#interview
appName="interview"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9219 ${VIP}:9219"
    echo "listen ${appName}:9219"
    echo "    bind ${VIP}:9219"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /Sc-Interview"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9218 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#bridge
appName="bridge"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9223 ${VIP}:9223"
    echo "listen ${appName}:9223"
    echo "    bind ${VIP}:9223"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /bridge"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9222 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#messagecenter
appName="messagecenter"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9221 ${VIP}:9221"
    echo "listen ${appName}:9221"
    echo "    bind ${VIP}:9221"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /messagecenter"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9220 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#mhqapp
appName="mhqapp"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9203 ${VIP}:9203"
    echo "listen ${appName}:9203"
    echo "    bind ${VIP}:9203"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /mhq-pgc-mserver"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9202 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#saas
appName="saas"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9231 ${VIP}:9231"
    echo "listen ${appName}:9231"
    echo "    bind ${VIP}:9231"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /mhq-pgc-mserver"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9230 check inter 15s rise 2 fall 2 weight 1"
    done
fi

#mugeda
appName="mugeda"
if [ "`check_app ${appName}`" = "true" ] ; then
    echo
    echo "#${appName}"
    # echo "listen ${appName}:9302 ${VIP}:9302"
    echo "listen ${appName}:9302"
    echo "    bind ${VIP}:9302"
    echo "$HTTP_ALL_DEFAULTS"
    echo "    option httpchk HEAD /mugedaapp/?"
    appHosts=`getAppHosts ${appName}`
    for host in $appHosts ; do
        echo "    server ${host} ${host}:9301 check inter 15s rise 2 fall 2 weight 1"
    done
fi

echo " "
IFS=$OLD_IFS

# bgeing build https listen
echo "# begin config https proxy"
haHosts=`getAppHosts haproxy`
echo "###$haHosts"

${APP_BASE}/install/crt_config.sh
CRT_DIR="${APP_BASE}/install/crt"

haCfgFile="${HAPROXY_HOME}/conf/haproxy_install.conf"
if [ -f "$haCfgFile" ] ; then
    HTTPS_PORTS_MAP=`cat $haCfgFile |grep "^HTTPS_PORTS_MAP="|grep -v "#" |sed -e 's|HTTPS_PORTS_MAP=||'`
    if [ "`check_app mosgateway`" = "true" ] ; then
        HTTPS_PORTS_MAP=`echo "$HTTPS_PORTS_MAP"|grep 10500:10555`
    else
        HTTPS_PORTS_MAP=`echo "$HTTPS_PORTS_MAP"|grep -v 10500:10555`
    fi
    scp -rp $CRT_DIR /etc/haproxy/
    if [ "$HTTPS_PORTS_MAP" != "" ] ; then
        for pmap in $HTTPS_PORTS_MAP ; do
            httpsp="${pmap//:*/}"
            httpp="${pmap//*:/}"
            if [ "$httpsp" != "" -a "$httpp" != "" ] ; then
                echo "
listen   HTTPS_${httpsp}_${httpp}
    bind *:$httpsp ssl crt /etc/haproxy/crt/hive_crt.pem
    mode    http
    option  httplog
    option  http-keep-alive
    balance    source
    option forwardfor header ORIG_CLIENT_IP
    option    redispatch
    timeout http-request    10s
    timeout queue           1m
    timeout connect         5s
    timeout server          30s
    timeout client          30s
    timeout http-keep-alive 10s
    timeout check           5s "
        for HA_HOST in $haHosts ; do
            echo "    server    $HA_HOST $HA_HOST:$httpp check inter 5s rise 2 fall 2 "
        done
            fi
        done
    fi
fi




