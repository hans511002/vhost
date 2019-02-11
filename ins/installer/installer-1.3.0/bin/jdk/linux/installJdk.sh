#!/bin/bash
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
cd $BIN
if [ "$USER" != "root" ] ; then
    echo "must run in root user : installJdk.sh"
    exit 1
fi

. ${APP_BASE}/install/funs.sh

srcPackage=`ls jdk1.*.tar.gz |sort -V |tail -n 1 `
srcVer=`echo "$srcPackage"|sed -e "s|.tar.gz||" -e "s|jdk||"`

echo "tar xf $srcPackage -C /usr/local/"
tar xf $srcPackage -C /usr/local/

if [ "$JAVA_HOME" != "" ] ; then
   cmd.sh rm -rf $JAVA_HOME
fi

if [ -f "/etc/profile.d/0jdk.sh" ] ; then
    sed -i -e "s|JAVA_HOME=.*|JAVA_HOME=/usr/local/jdk$srcVer|"  /etc/profile.d/0jdk.sh
else
echo "export JAVA_HOME=/usr/local/jdk$srcVer
export JRE_HOME=$JAVA_HOME/jre
export PATH=.:$PATH:/bin:/sbin:/usr/bin:$JAVA_HOME/bin:$JRE_HOME/bin
export CLASSPATH=.:$JAVA_HOME/lib:$JAVA_HOME/jre/lib:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
" > /etc/profile.d/0jdk.sh
fi
. /etc/profile.d/0jdk.sh

cp.sh scp -rp $HOSTNAME:/usr/local/jdk$srcVer /usr/local/
cp.sh scp -rp $HOSTNAME:/etc/profile.d/0jdk.sh /etc/profile.d/0jdk.sh

stSh=`which stop-zk.sh`
if [ "$stSh" != "" ] ; then
    echo "stop-zk.sh"
    stop-zk.sh
    echo "start-zk.sh"
    start-zk.sh
fi
service deploy status 2>/dev/null
if [ "$?" = "0" ] ; then
cmd.sh service deploy restart
fi
