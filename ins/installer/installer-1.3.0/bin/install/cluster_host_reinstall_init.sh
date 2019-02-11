#!/bin/bash
. /etc/bashrc

$APP_BASE/install/cluster_init.sh

# 
# # 配置本机为时间服务器
# yum install -y ntp
# 
# # 允许所有主机同步
# sed -i -e 's/restrict default .*/restrict default nomodify notrap /' /etc/ntp.conf
# sed -i -e 's/logfile .*//' /etc/ntp.conf
# ##指定NTP服务器日志文件
# echo "logfile /var/log/ntp" >>  /etc/ntp.conf
# #禁用 ntupdate
# sed -i -e "s|.*/usr/sbin/ntpdate.*||"  /var/spool/cron/root
# systemctl enable ntpd
# systemctl restart ntpd
# # 配置其它主机与此同步
# CLS_HOST_LIST=`cat /bin/cmd.sh |grep "for HOST"|sed -e 's/.*for HOST in//' -e 's/;.*//'`
# FISRTHOST=`echo $CLS_HOST_LIST|awk '{print $1}'`
# # 
# cmd.sh yum install -y ntpdate
# echo "0-59/10 * * * * /usr/sbin/ntpdate $HOSTNAME && hwclock -w  >> /root/ntpdate.log 2>&1 &" > /tmp/ntpcrontabfile
# echo "#!/bin/bash
# . /etc/bashrc
# scp $HOSTNAME:/tmp/ntpcrontabfile /tmp/ntpcrontabfile
# crontabFile=\"/var/spool/cron/root\"
# if [ -f \"\$crontabFile\" ] ; then
#     sed -i -e \"s|.*/usr/sbin/ntpdate.*||\"  \$crontabFile 
# fi
# cat /tmp/ntpcrontabfile >> \$crontabFile 
# 
# ">/tmp/_ntp.sh
# chmod +x /tmp/_ntp.sh
# for HOST in $CLS_HOST_LIST ; do
#     ssh $HOST systemctl enable crond
#     if [ "$HOST" = "$HOSTNAME" ] ; then
#         continue
#     fi
#     ssh $HOST systemctl disable ntpd
# 		ssh $HOST systemctl stop ntpd
#     scp /tmp/_ntp.sh $HOST:/tmp/ntp.sh
#     ssh $HOST chmod +x /tmp/ntp.sh
#     ssh $HOST /tmp/ntp.sh
#     ssh $HOST rm -rf /tmp/ntp.sh
#     ssh $HOST /usr/sbin/ntpdate $HOSTNAME 
#     ssh $HOST hwclock -w 
# done
# 
# exit 0

