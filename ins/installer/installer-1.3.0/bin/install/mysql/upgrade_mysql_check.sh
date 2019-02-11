#!/bin/bash
 
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

mysqlHosts=`cat $MYSQL_HOME/conf/servers`

if [ ! -f "mysql-check.tar.gz" ] ; then
    echo "mysql-check.tar.gz package not exists"
    exit 1
fi

echo "tar xf mysql-check.tar.gz "
tar xf mysql-check.tar.gz 

echo "defaultPort=3306
galeraPort=4567
galeraISTPort=4568
galeraSSTPort=4444
">conf/mysql-install.conf

dayno=`date +%Y%m%d%H%M%S`
for msyqlHost in $mysqlHosts ; do
    echo "scp tcping-1.3.5-1.el7.x86_64.rpm $msyqlHost:/tmp/"
    scp tcping-1.3.5-1.el7.x86_64.rpm $msyqlHost:/tmp/
    echo "ssh $msyqlHost rpm -ivh /tmp/tcping-1.3.5-1.el7.x86_64.rpm"
    ssh $msyqlHost rpm -ivh /tmp/tcping-1.3.5-1.el7.x86_64.rpm
    ssh $msyqlHost rm -rf /tmp/tcping-1.3.5-1.el7.x86_64.rpm
    
    echo "ssh $msyqlHost scp -r \$MYSQL_HOME/conf/ \$MYSQL_HOME/conf-$dayno"
    ssh $msyqlHost scp -r \$MYSQL_HOME/conf/ \$MYSQL_HOME/conf-$dayno
    echo "ssh $msyqlHost scp -r /usr/local/bin/mysql_status /usr/local/bin/mysql_status-$dayno"
    ssh $msyqlHost scp -r /usr/local/bin/mysql_status /usr/local/bin/mysql_status-$dayno
    
    echo "scp -r funs.sh $msyqlHost:${APP_BASE}/install/"
    scp -r funs.sh $msyqlHost:${APP_BASE}/install/
    echo "scp -r mysql_status $msyqlHost:/usr/local/bin/"
    scp -r mysql_status $msyqlHost:/usr/local/bin/
    echo "scp -r conf sbin $msyqlHost:\$MYSQL_HOME/"
    scp -r conf sbin $msyqlHost:\$MYSQL_HOME/
    echo "ssh $msyqlHost chmod +x \\\$MYSQL_HOME/sbin/ \\\$MYSQL_HOME/conf/mysqld.sh"
    ssh $msyqlHost chmod +x \$MYSQL_HOME/sbin/ \$MYSQL_HOME/conf/mysqld.sh
    
    myhostContainer=`ssh $msyqlHost docker ps -a|grep mysql-|awk '{print $NF}'`
    if [ "$myhostContainer" = "" ] ; then
        echo "update $msyqlHost shell failed"
        exit 1
    fi
    echo "mysql docker container name:$myhostContainer"
    ssh $msyqlHost docker restart $myhostContainer
    
    MYSQL=`ssh $msyqlHost which mysql`
    if [ "$MYSQL" = "" ] ; then
        echo "ssh $msyqlHost yum install mariadb -y"
        ssh $msyqlHost yum install mariadb -y
    fi
    
    int=0
    while (( $int<=10 )) ;  do
        ssh $msyqlHost \$MYSQL_HOME/sbin/check_mysql.sh
        if [ "$?" = "0" ] ; then
            echo "update $msyqlHost shell success"
            break
        fi
        let "int++"
        sleep 5
    done 
    if [ "$int" -gt "10" ] ; then
        echo "update $msyqlHost shell failed"
        exit 1
    fi
done

rm -rf conf funs.sh mysql_status sbin 
