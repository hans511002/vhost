#! /bin/bash
 
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`

yum install -y xinetd
if [ "$?" -ne "0" ] ; then
    echo "exec failed:yum install -y xinetd "
    exit 1
fi
mongoStatus=$(cat /etc/services |grep mongo_status)
if [ "$mongoStatus" = "" ] ; then
	echo "mongo_status			49995/tcp" >> /etc/services
else
    sed -i -e "s|mongo_status.*|mongo_status			49995/tcp|"   /etc/services
fi
zkStatus=$(cat /etc/services |grep zk_status)
if [ "$zkStatus" = "" ] ; then
	echo "zk_status			49997/tcp" >> /etc/services
else
    sed -i -e "s|zk_status.*|zk_status			49997/tcp|"   /etc/services
fi
mysqlStatus=$(cat /etc/services |grep mysql_status)
if [ "$mysqlStatus" = "" ] ; then
	echo "mysql_status			49999/tcp" >> /etc/services
else
    sed -i -e "s|mysql_status.*|mysql_status			49999/tcp|"   /etc/services
fi
#scp overwrite
scp $BIN/xinetd_check_port/etc.xinetd.d/* /etc/xinetd.d/
scp $BIN/xinetd_check_port/usr.local.bin/* /usr/local/bin
chmod +x /etc/xinetd.d/*_status
chmod +x /usr/local/bin/*_status
systemctl enable xinetd
service xinetd restart

exit 0
