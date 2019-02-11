#!/bin/bash

bin=`dirname "${BASH_SOURCE-$0}"`
cd "$bin"
bin=`cd "$bin">/dev/null; pwd`
cd $bin

if [ -f "mysql-check.tar.gz" ] ; then
#    echo "tar xf mysql-check.tar.gz "
#    tar xf mysql-check.tar.gz 
    echo "rm -rf mysql-check.tar.gz "
    rm -rf mysql-check.tar.gz 
fi
echo "scp ../funs.sh ./"
scp ../funs.sh ./
echo "scp ../../lib/tcping-1.3.5-1.el7.x86_64.rpm ./"
scp ../../lib/tcping-1.3.5-1.el7.x86_64.rpm ./

echo "tar zcf mysql-check.tar.gz conf funs.sh mysql_status sbin tcping-1.3.5-1.el7.x86_64.rpm"
tar zcf mysql-check.tar.gz conf funs.sh mysql_status sbin tcping-1.3.5-1.el7.x86_64.rpm
echo "rm -rf conf funs.sh mysql_status sbin tcping-1.3.5-1.el7.x86_64.rpm"
rm -rf conf funs.sh mysql_status sbin tcping-1.3.5-1.el7.x86_64.rpm
