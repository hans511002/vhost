#!/usr/bin/env bash
# 
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
cd $bin
chmod +x *
systemctl stop netpcap
systemctl stop netpcapdeamon
scp netpcap /bin/
scp netpcap.sh /etc/init.d/
# ExecStart=/bin/netpcap -s ${LOGS_BASE}/netpcap.log -z 1024000 -i 1
mkdir -p ${LOGS_BASE}/netpcap/
sed -i -e "s|ExecStart=.*|ExecStart=/bin/netpcap -s ${LOGS_BASE}/netpcap/netpcap.log -z 102400 -i 5 -n 10 |"  $bin/netpcap.service
cp -f $bin/netpcap.service /usr/lib/systemd/system/netpcap.service
cp -f $bin/netpcapdeamon.service /usr/lib/systemd/system/netpcapdeamon.service
systemctl enable netpcap
systemctl enable netpcapdeamon
systemctl start netpcap
systemctl start netpcapdeamon
