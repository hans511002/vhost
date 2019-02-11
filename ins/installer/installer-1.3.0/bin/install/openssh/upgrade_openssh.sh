. /etc/bashrc

bin=$(cd $(dirname $0); pwd)

if [ `which ssh > /dev/null 2>&1; echo $?` = "0" -a "$1" != "true" ]; then
    ver1=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $1}'`
    ver2=`ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}' | awk -F 'p' '{print $2}'`
    if [ "$ver1" = "7.7" ]; then
        echo "ssh -V: `ssh -V 2>&1 | awk -F '[,_ ]' '{print $2}'`"
        exit 0
    fi
fi 

cd $bin

echo "begin install OpenSSH_7.7p1 "
echo "tar xf openssh-7.7p1-bin.tar.gz"
tar xf openssh-7.7p1-bin.tar.gz

echo "rpm -qa|grep openssl-|xargs rpm -e --nodeps
rpm -ivh --nodeps openssl-1.0.2k-8.el7.x86_64.rpm openssl-devel-1.0.2k-8.el7.x86_64.rpm openssl-libs-1.0.2k-8.el7.x86_64.rpm"
rpm -qa|grep openssl-|xargs rpm -e --nodeps 
rpm -ivh --nodeps openssl-1.0.2k-8.el7.x86_64.rpm openssl-devel-1.0.2k-8.el7.x86_64.rpm openssl-libs-1.0.2k-8.el7.x86_64.rpm


/bin/mkdir -p /usr/bin
/bin/mkdir -p /usr/sbin
/bin/mkdir -p /usr/share/man/man1
/bin/mkdir -p /usr/share/man/man5
/bin/mkdir -p /usr/share/man/man8
/bin/mkdir -p /usr/libexec
/bin/mkdir -p -m 0755 /var/lib/sshd
/bin/mkdir -p /etc/ssh

/bin/install -c -m 0755 -s usr/bin/ssh /usr/bin/ssh
/bin/install -c -m 0755 -s usr/bin/scp /usr/bin/scp
/bin/install -c -m 0755 -s usr/bin/ssh-add /usr/bin/ssh-add
/bin/install -c -m 0755 -s usr/bin/ssh-agent /usr/bin/ssh-agent
/bin/install -c -m 0755 -s usr/bin/ssh-keygen /usr/bin/ssh-keygen
/bin/install -c -m 0755 -s usr/bin/ssh-keyscan /usr/bin/ssh-keyscan
/bin/install -c -m 0755 -s usr/bin/sftp /usr/bin/sftp
/bin/install -c -m 0755 -s usr/sbin/sshd /usr/sbin/sshd
/bin/install -c -m 4711 -s usr/libexec/ssh-keysign /usr/libexec/ssh-keysign
/bin/install -c -m 0755 -s usr/libexec/ssh-pkcs11-helper /usr/libexec/ssh-pkcs11-helper
/bin/install -c -m 0755 -s usr/libexec/sftp-server /usr/libexec/sftp-server

scp -rp usr/share/man /usr/share/
scp -rp etc /
echo "/usr/sbin/sshd -t -f /etc/ssh/sshd_config"
/usr/sbin/sshd -t -f /etc/ssh/sshd_config

systemctl restart sshd || service sshd restart

rm -rf etc usr openssl-*

RES=$?
if [ "$RES" = "0" ] ; then
   echo "openssh installed!"
else
    echo "openssh install failed!"
fi
