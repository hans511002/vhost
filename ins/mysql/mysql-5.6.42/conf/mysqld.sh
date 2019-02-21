#!/bin/bash

MYSQL_CONF_DIR="/etc/mysql"
MYSQL_CONF_FILE="$MYSQL_CONF_DIR/my.cnf"
CLUSTER_FILE="servers"
SERVER_LIST="$MYSQL_CONF_DIR/$CLUSTER_FILE"

HIVE_USER='mysqldba'
HIVE_PASSWORD='34954344@qq.com'

function testHostPort()
{
   tcping "$@" 2>&1 |sed -e 's|.*open.|open|' -e 's|.*closed.|closed|'
}

insConfFile=`ls ${MYSQL_CONF_DIR}/*-install.conf`

defaultPort=3306
appName="mysql"
galeraPort="4567"
galeraISTPort="4568"
galeraSSTPort="4444"
if [ -f "$insConfFile" ] ; then
    appName=`echo ${insConfFile//*\//}|sed -e "s|-.*||"`
    defaultPort=`cat $insConfFile|grep -E "^defaultPort" |awk -F= '{print $2}'`
    if [ "$defaultPort" = "" ] ; then
        defaultPort=3306
    fi
    galeraPort=`cat $insConfFile|grep -E "^galeraPort" |awk -F= '{print $2}'`
    if [ "$galeraPort" = "" ] ; then
        galeraPort=4567
    fi
    galeraISTPort=`cat $insConfFile|grep -E "^galeraISTPort" |awk -F= '{print $2}'`
    if [ "$galeraISTPort" = "" ] ; then
        galeraISTPort=4568
    fi
    galeraSSTPort=`cat $insConfFile|grep -E "^galeraSSTPort" |awk -F= '{print $2}'`
    if [ "$galeraSSTPort" = "" ] ; then
        galeraSSTPort=4444
    fi
    hiveUser=`cat $insConfFile|grep -E "^HIVE_USER" |awk -F= '{print $2}'`
    if [ "$hiveUser" != "" ] ; then
        HIVE_USER=$hiveUser
    fi    
    hivePaas=`cat $insConfFile|grep -E "^HIVE_PASSWORD" |awk -F= '{print $2}'`
    if [ "$hivePaas" != "" ] ; then
        HIVE_PASSWORD=$hivePaas
    fi     
fi
port=`cat $MYSQL_CONF_FILE|grep port |awk -F= '{print $2}'`
if [ "$port" = "" ] ; then
    sed -i -e "/\[mysqld\]/aport=$defaultPort" $MYSQL_CONF_FILE
elif [ "$port" != "$defaultPort" ] ; then
    sed -i -e "s|port=.*|port=$defaultPort|" $MYSQL_CONF_FILE
fi
port="$defaultPort"

mkdir -p /var/log/mysql
if [ -d "/var/log/mysql" ] ;then
   chown -R mysql:mysql "/var/log/mysql"
fi
if [ -d "/var/run/mysqld" ] ;then
	chown -R mysql:mysql "/var/run/mysqld"
fi
if [ -d "/var/logs" ] ;then
	chown -R mysql:mysql "/var/logs"
fi

if [ $# -eq 0  -o   "${1:0:1}" = '-'  ]; then
  set -- mysqld "$@"
fi

#--defaults-file=/etc/mysql/my.cnf
if [ $(expr "$2" : "--defaults-file=") -eq 16 ]; then
  MYSQL_CONF_FILE="${2:16}"
  MYSQL_CONF_DIR=`dirname $MYSQL_CONF_FILE`
  SERVER_LIST="$MYSQL_CONF_DIR/$CLUSTER_FILE"
else
  set -- "$@" --defaults-file="$MYSQL_CONF_FILE"
fi

SERVER_LISTS=$(cat "$SERVER_LIST" | sed  's/#.*$//;/^$/d')
HOST_SIZE=0
for NODE_SERVICE_HOST in $SERVER_LISTS; do  
  ((HOST_SIZE++))
done
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$HIVE_PASSWORD}
GALERA_CLUSTER=${GALERA_CLUSTER:-"MyCluster"}
WSREP_SST_PASSWORD=${WSREP_SST_PASSWORD:-"mysqlsst"}
if [ -z "$VHOSTNAME" ] ; then 
  if [ -n "$HOSTNAME" ] ; then
      VHOSTNAME=$HOSTNAME
   else
      VHOSTNAME=`hostname`
   fi
fi

echo "all par = $@"

isInitStarted=false
tempSqlFile='/tmp/mysql-first-time.sql'

# if the command passed is 'mysqld' via CMD, then begin processing. 
if [ "$1" = 'mysqld' ]; then
    # read DATADIR from the MySQL config
    sed -i -e "s|^wsrep_cluster_address=.*|wsrep_cluster_address=gcomm://|" $MYSQL_CONF_DIR/conf.d/cluster.cnf
    
    #DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
    DATADIR=`cat $MYSQL_CONF_FILE|grep -e "^datadir="|awk -F= '{print $2}' | tail -n 1`
    if [ "$DATADIR" = "" ] ; then 
        DATADIR="/var/lib/mysql"
    else
        DATADIR=${DATADIR// /}
    fi 
    echo "mysql DATADIR=$DATADIR"
    
    # only check if system tables not created from mysql_install_db and permissions 
    # set with initial SQL script before proceding to build SQL script
    if [ ! -d "$DATADIR/mysql" ]; then
         # fail if user didn't supply a root password  
        if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
              echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
              echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
              exit 1
        fi

        # mysql_install_db installs system tables
        mkdir -p $DATADIR
        chown -R mysql:mysql "$DATADIR"
        echo 'Running mysql_install_db ...'
        mysql_install_db --datadir="$DATADIR"
        echo 'Finished mysql_install_db'
    
    # this script will be run once when MySQL first starts to set up
    # prior to creating system tables and will ensure proper user permissions 
    #grant all privileges on  *.* to 'root'@'%' with grant option; 
    #update mysql.user set password=password('$MYSQL_ROOT_PASSWORD') where User="root" and host="%"  ;
    #flush privileges;

        cat > "$tempSqlFile" <<-EOSQL
DELETE FROM mysql.user ;
CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
CREATE USER '$HIVE_USER'@'%' IDENTIFIED BY '$HIVE_PASSWORD' ;
GRANT ALL ON *.* TO '$HIVE_USER'@'%' WITH GRANT OPTION ;
EOSQL
        #create database and user 
        if [ "$MYSQL_DATABASE" ]; then
          echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
        fi
    
        if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
              echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
              
              if [ "$MYSQL_DATABASE" ]; then
                echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "$tempSqlFile"
              fi
        fi

    # Add SST (Single State Transfer) user if Clustering is turned on
        if [ -n "$GALERA_CLUSTER" ]; then
        # this is the Single State Transfer user (SST, initial dump or xtrabackup user)
              WSREP_SST_USER=${WSREP_SST_USER:-"sst"}
              if [ -z "$WSREP_SST_PASSWORD" ]; then
                echo >&2 'error: Galera cluster is enabled and WSREP_SST_PASSWORD is not set'
                echo >&2 '  Did you forget to add -e WSREP_SST_PASSWORD=... ?'
                exit 1
              fi
          # add single state transfer (SST) user privileges
              echo "CREATE USER '${WSREP_SST_USER}'@'localhost' IDENTIFIED BY '${WSREP_SST_PASSWORD}';" >> "$tempSqlFile"
              echo "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${WSREP_SST_USER}'@'localhost';" >> "$tempSqlFile"
        fi

         echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
    
        # Add the SQL file to mysqld's command line args
        isInitStarted=true
        set -- "$@" --init-file="$tempSqlFile"
    else
	  chown -R mysql:mysql $DATADIR
    fi
    rm -rf $DATADIR/$VHOSTNAME.pid
fi

HOST_INDEX=${HOST_INDEX:-"0"}
# if cluster is turned on, then procede to build cluster setting strings
# that will be interpolated into the config files
echo "isInitStarted=$isInitStarted GALERA_CLUSTER=$GALERA_CLUSTER"
if [ -n "$GALERA_CLUSTER" -a "$isInitStarted" = "false" ]; then
    # this is the Single State Transfer user (SST, initial dump or xtrabackup user)
    WSREP_SST_USER=${WSREP_SST_USER:-"sst"}
    if [ -z "$WSREP_SST_PASSWORD" ]; then
        echo >&2 'error: database is uninitialized and WSREP_SST_PASSWORD not set'
        echo >&2 '  Did you forget to add -e WSREP_SST_PASSWORD=xxx ?'
        exit 1
    fi
    sed -i -e "s|^wsrep_cluster_name.*=.*|wsrep_cluster_name=${GALERA_CLUSTER}|" $MYSQL_CONF_DIR/conf.d/cluster.cnf
    
    # user/password for SST user
    sed -i -e "s|^wsrep_sst_auth.*=.*|wsrep_sst_auth=${WSREP_SST_USER}:${WSREP_SST_PASSWORD}|" $MYSQL_CONF_DIR/conf.d/cluster.cnf
  
    WSREP_NODE_ADDRESS=$VHOSTNAME
    if [ -n "$WSREP_NODE_ADDRESS" ]; then
        sed -i -e "s|^wsrep_node_address=.*$|wsrep_node_address=${WSREP_NODE_ADDRESS}|" $MYSQL_CONF_DIR/conf.d/cluster.cnf
        sed -i -e "s|^wsrep_node_name=.*$|wsrep_node_name=${VHOSTNAME}|" $MYSQL_CONF_DIR/conf.d/cluster.cnf
    fi
    
    rm -rf $DATADIR/GRA_*
    rm -rf $DATADIR/wsrep_recovery.*
    
    #WSREP_CLUSTER_ADDRESS="gcomm://"
    #INDEX=1
    #for NODE_SERVICE_HOST in $SERVER_LISTS; do  
    #    if [ "$VHOSTNAME" = "$NODE_SERVICE_HOST" ] ; then
    #        HOST_INDEX=$INDEX
    #        echo "VHOSTNAME=$VHOSTNAME   $NODE_SERVICE_HOST"
    #        continue
    #    fi
    #    ((INDEX++))
    #    if [ $WSREP_CLUSTER_ADDRESS != "gcomm://" ]; then
	#        WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS},"
	#    fi
    #    WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS}"${NODE_SERVICE_HOST}
    #done
    
    # if the string is not defined or it only is 'gcomm://', this means bootstrap
    if [ -z "$WSREP_CLUSTER_ADDRESS" -o "$WSREP_CLUSTER_ADDRESS" == "gcomm://" ]; then
        # if empty, set to 'gcomm://'
        # NOTE: this list does not imply membership. 
        # It only means "obtain SST and join from one of these..."
        if [ -z "$WSREP_CLUSTER_ADDRESS" ]; then
          WSREP_CLUSTER_ADDRESS="gcomm://"
        fi
    
    # loop through number of nodes
    INDEX=1
    for NODE_SERVICE_HOST in $SERVER_LISTS; do  
      # if set
        # if not its own IP, then add it
        if [ $(expr "$VHOSTNAME" : "$NODE_SERVICE_HOST") -eq 0 ]; then
            #判断是否存活  3306 4444 $galeraPort 4568
            echo "check $NODE_SERVICE_HOST port $port $galeraPort   "
            echo "testHostPort $NODE_SERVICE_HOST $port  "
            MYSQL_STATUS=$(testHostPort $NODE_SERVICE_HOST $port )
            
            MYSQL_CLS_STATUS="closed"
            if [ "$MYSQL_STATUS" = "open" -o "$MYSQL_STATUS" = "filtered" ] ; then
                echo "testHostPort $NODE_SERVICE_HOST  $galeraPort "
                MYSQL_CLS_STATUS=$(testHostPort $NODE_SERVICE_HOST $galeraPort )
            fi 
            if [ "$MYSQL_CLS_STATUS" = "open"  -o "$MYSQL_CLS_STATUS" = "filtered" ] ; then

                #QA测试环境初次安装遇到SELECT_TEST检测失败，retry
                for i in {1..5}; do
                    # if not the first bootstrap node add comma
                    SELECT_TEST=$(mysql -h $NODE_SERVICE_HOST  -P $port -u root -p$MYSQL_ROOT_PASSWORD -N -e  "select 1")
                    SELECT_TEST_STATUS=$(mysql -h $NODE_SERVICE_HOST -P $port -u root -p$MYSQL_ROOT_PASSWORD -N -e  "SHOW STATUS LIKE 'wsrep_ready'"|awk '{print $2}')
                    if [ -n "$SELECT_TEST" -a -n "$SELECT_TEST_STATUS" ]; then
                        break
                    fi
                    sleep 1
	  			done
                
	  			if [ "$SELECT_TEST" = "1" -a "$SELECT_TEST_STATUS" = "ON" ] ; then
                    if [ $WSREP_CLUSTER_ADDRESS != "gcomm://" ]; then
                        WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS},"
			        fi
    	            # append
    	            WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS}${NODE_SERVICE_HOST}:$galeraPort"
                fi
            fi
        else
            HOST_INDEX=$INDEX
        fi
         ((INDEX++))
    done
    fi
    echo  HOST_INDEX=$HOST_INDEX  WSREP_CLUSTER_ADDRESS=$WSREP_CLUSTER_ADDRESS

  # WSREP_CLUSTER_ADDRESS is now complete and will be interpolated into the 
  # cluster address string (wsrep_cluster_address) in the cluster
  # configuration file, cluster.cnf
    
    shift
    set -- /usr/bin/mysqld_safe "$@"
    if [ "$WSREP_CLUSTER_ADDRESS" = "gcomm://" ] ; then
        sed -i -e "s|safe_to_bootstrap:.*|safe_to_bootstrap: 1|" $DATADIR/grastate.dat 
    else
        WSREP_CLUSTER_ADDRESS="${WSREP_CLUSTER_ADDRESS}"  # ?gmcast.listen_addr=${VHOSTNAME}:$galeraPort
    fi
    sed -i -e "s|^wsrep_cluster_address=gcomm://.*|wsrep_cluster_address=${WSREP_CLUSTER_ADDRESS}|" $MYSQL_CONF_DIR/conf.d/cluster.cnf    
    
fi

if [ -n "$GALERA_CLUSTER" ]; then
    sstAddress=`cat $MYSQL_CONF_DIR/conf.d/cluster.cnf|grep wsrep_sst_receive_address ` # | awk -F= '{print $2}'
    if [ "$sstAddress" = "" ] ; then
        echo "wsrep_sst_receive_address=${VHOSTNAME}:$galeraSSTPort" >> $MYSQL_CONF_DIR/conf.d/cluster.cnf 
    else
        sed -i -e "s|#wsrep_sst_receive_address|wsrep_sst_receive_address|" $MYSQL_CONF_DIR/conf.d/cluster.cnf 
        sed -i -e "s|wsrep_sst_receive_address.*|wsrep_sst_receive_address=${VHOSTNAME}:$galeraSSTPort|" $MYSQL_CONF_DIR/conf.d/cluster.cnf 
    fi
    wsrep_provider_options=`cat $MYSQL_CONF_DIR/conf.d/cluster.cnf|grep -E "^wsrep_provider_options="` 
    if [ "$wsrep_provider_options" = "" ] ; then
        echo "wsrep_provider_options=\"\"" >> $MYSQL_CONF_DIR/conf.d/cluster.cnf 
        wsrep_provider_options="base_port=$galeraPort;ist.recv_addr=${VHOSTNAME}:$galeraISTPort;"
        sed -i -e "s|wsrep_provider_options.*|wsrep_provider_options=\"${wsrep_provider_options}\"|" $MYSQL_CONF_DIR/conf.d/cluster.cnf 
    else
        #sed -i -e "s|#wsrep_provider_options|wsrep_provider_options|" $MYSQL_CONF_DIR/conf.d/cluster.cnf 
        wsrep_provider_options=`cat $MYSQL_CONF_DIR/conf.d/cluster.cnf|grep -E "^wsrep_provider_options=" |tail -n 1` 
        wsrep_provider_options=${wsrep_provider_options//\"/}
        wsrep_provider_options=${wsrep_provider_options// /}
        wsrep_provider_options=${wsrep_provider_options//;/ }
        wsrep_provider_options=${wsrep_provider_options//wsrep_provider_options=/ }

        _wsrep_provider_options=""
        echo "wsrep_provider_options=$wsrep_provider_options"
        for item in ${wsrep_provider_options} ; do
            if [ "${item}" != "${item//base_port=/}" ]; then
                continue
            elif [ "${item}" != "${item//ist.recv_addr=/}" ]; then
                continue                
            fi
            _wsrep_provider_options="$_wsrep_provider_options$item;"
        done
        wsrep_provider_options="base_port=$galeraPort;ist.recv_addr=${VHOSTNAME}:$galeraISTPort;$_wsrep_provider_options"
        echo "wsrep_provider_options=$wsrep_provider_options"
        ## base_port = 4567; ist.recv_addr=172.16.131.37:4568; 
        # wsrep_provider_options=`echo "$wsrep_provider_options" |sed -e "s|base_port=[0-9]\{3,5\};||"  -e "s|ist.recv_addr=[0-9]\{3,5\};||"   `
        sed -i -e "s|wsrep_provider_options=.*|wsrep_provider_options=\"${wsrep_provider_options}\"|" $MYSQL_CONF_DIR/conf.d/cluster.cnf 
    fi
fi

# random server ID needed
if [  $HOST_INDEX -eq  0 ] ; then
sed -i -e "s/^server\-id=.*$/server-id=${RANDOM}/" $MYSQL_CONF_FILE
else
sed -i -e "s/^server\-id=.*$/server-id=${HOST_INDEX}/" $MYSQL_CONF_FILE
fi



function stopMysql(){
date
echo "== 收到停止命令,开始停止 mysql 数据库 == "
echo "Receive a stop command, start to stop the mysql database "
/etc/init.d/mysql stop
echo "
stop end"
date
rm -rf $DATADIR/mysql.sock $DATADIR/mysql.sock.lock 2>/dev/null
}
trap "stopMysql"  1 2 3 9 15

# finally, start mysql
echo  "$@"
"$@" &
wait $!



