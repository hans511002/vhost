#! /bin/bash 
. /etc/bashrc

BIN=`dirname "${BASH_SOURCE-$0}"`
BIN=`cd "$BIN">/dev/null; pwd`
. $APP_BASE/install/funs.sh
cd $BIN
if [ $# -lt 1 ] ; then 
  echo "usetag:$0 INSTALL_SRC [MASTER_HOST]"
  exit 1
fi
INSTALL_SRC=$1
MASTER_HOST=$2
HOSTNAME=`hostname`
if [ "$MASTER_HOST" = "" ] ; then
   MASTER_HOST=$HOSTNAME
fi 
if [ "$HOSTNAME" != "$MASTER_HOST" ] ; then
    ssh $MASTER_HOST $BIN/docker_config.sh
    exit $?
fi 

$DOCKER_HOME/sbin/start_docker_cluster.sh

CFG_FILE=${DOCKER_HOME}/docker.cfg
DOCKER_NETWORK_NAMES=$(grep "^[[:space:]]*DOCKER_NETWORK_NAMES=" "$CFG_FILE" | sed -e "s/DOCKER_NETWORK_NAMES=//" )
if [ "$DOCKER_NETWORK_NAMES" != "" ] ; then
   for netName in $DOCKER_NETWORK_NAMES ; do
        netParams=$(grep "^[[:space:]]*DOCKER_NETWORK_NAME.$netName.params=" "$CFG_FILE" | sed -e "s/DOCKER_NETWORK_NAME.$netName.params=//" )
        CMD="docker network create --driver overlay --attachable $netParams $netName "
    	echo "create user define network cmd:$CMD"
    	$CMD
    done
fi 

cd $INSTALL_SRC

if [ ! -d images ] ; then
    exit 0
fi 
cd images
docker pull centos
errorExit $? "docker pull centos failed "

imagesDir=`pwd`
if [ -d "$imagesDir/centos-ssh" ] ; then
    cd $imagesDir/centos-ssh
    sed -i -e "s|FROM .*|FROM centos|" Dockerfile
    docker build -t centos-ssh .  
fi
if [ -d "$imagesDir/centos-tools" ] ; then
    cd $imagesDir/centos-tools
    sed -i -e "s|FROM .*|FROM centos|" Dockerfile
    docker build -t centos-tools .  
fi
if [ -d "$imagesDir/centos-ssh-tools" ] ; then
    cd $imagesDir/centos-ssh-tools
    sed -i -e "s|FROM .*|FROM centos-ssh|" Dockerfile
    docker build -t centos-sshtool .  
fi

if [ -d "$imagesDir/centos-jdk" ] ; then
    jdkDir=`ls /usr/local/|grep jdk|sort -V | tail -n 1`
    jdkVer=`echo $jdkDir| sed -e "s|_.*||"`
    if [ ! -f "$imagesDir/centos-jdk/$jdkDir.tar.gz" ] ; then
        cd /usr/local
        tar zcf $imagesDir/centos-jdk/$jdkDir.tar.gz $jdkDir 
    fi 
    cd $imagesDir/centos-jdk
    sed -i -e "s|ADD jdk1.*.tar.gz|ADD $jdkDir.tar.gz|" Dockerfile
    docker build -t centos-jdk:$jdkVer . 
fi 
if [ -d "$imagesDir/centos-openjdk" ] ; then
    cd $imagesDir/centos-openjdk
    echo "FROM centos
RUN yum install -y java-1.8.0-openjdk && yum clean all " > Dockerfile
    docker build -t centos-openjdk:1.8.0 . 
    echo "FROM centos
RUN yum install -y java-11-openjdk && yum clean all " > Dockerfile
    docker build -t centos-openjdk:11 . 
fi 

if [ -d "$imagesDir/centos-jdk-tomcat" ] ; then
    jdkImg=`docker images |grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'|grep "centos-jdk:1"|sort -V |tail -n 1`
    cd $imagesDir/centos-jdk-tomcat
    sed -i -e "s|FROM .*|FROM $jdkImg|" Dockerfile
    docker build -t centos-jdk-tomcat .  
fi
if [ -d "$imagesDir/centos-openjdk-tomcat" ] ; then
    jdkImg=`docker images |grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'|grep "centos-openjdk:1"|sort -V |tail -n 1`
    cd $imagesDir/centos-openjdk-tomcat
    sed -i -e "s|FROM .*|FROM $jdkImg|" Dockerfile
    if [ ! -e "tomcat9.tar.gz" ] ; then
        scp $imagesDir/centos-jdk-tomcat/tomcat9.tar.gz ./
    fi
    docker build -t centos-openjdk-tomcat . 
fi
if [ -d "$imagesDir/haproxy" ] ; then
    cd $imagesDir/haproxy
    sed -i -e "s|FROM .*|FROM centos|" Dockerfile
    chmod +x haproxy*
    appVer=`./haproxy -v |grep version|sed -e "s|.*version ||" -e "s| .*||"`
    appVer=${appVer:=1.7.8}
    appName=haproxy
    docker build -t $appName:$appVer . 
    if [ -d "$INSTALL_SRC/$appName/" ] ; then
        cd $INSTALL_SRC/$appName/
        pkgDir=$appName-$haproxyVer
        if [ ! -e "$pkgDir" ] ; then
            pgkFile=`ls |grep $appName-|sort -V |tail -n 1`
            if [ "$pgkFile" != "${pgkFile//.tar.gz/}" ] ; then
                tar xf $pgkFile
            fi 
            pgkFile="${pgkFile//.tar.gz/}"
            scp -rp $pgkFile $pkgDir
        fi 
        cd $pkgDir
        ls $appName-*.tar* 2>/dev/null |xargs rm -rf 2>/dev/null
        docker save -o $appName-$appVer.tar $appName:$appVer
        gzip $appName-$appVer.tar
        cd $INSTALL_SRC/$appName/
        tar zcf mysql-$appVer.tar.gz mysql-$appVer && md5sum mysql-$appVer.tar.gz > mysql-$appVer.tar.gz.md5 
    fi
    appName=hadocker
    if [ -d "$INSTALL_SRC/$appName/" ] ; then
        docker tag haproxy:$appVer $appName:$appVer
        cd $INSTALL_SRC/$appName/
        pkgDir=$appName-$haproxyVer
        if [ ! -e "$pkgDir" ] ; then
            pgkFile=`ls |grep $appName-|sort -V |tail -n 1`
            if [ "$pgkFile" != "${pgkFile//.tar.gz/}" ] ; then
                tar xf $pgkFile
            fi 
            pgkFile="${pgkFile//.tar.gz/}"
            scp -rp $pgkFile $pkgDir
        fi 
        cd $pkgDir
        ls $appName-*.tar* 2>/dev/null |xargs rm -rf 2>/dev/null
        docker save -o $appName-$appVer.tar $appName:$appVer
        gzip $appName-$appVer.tar
        cd $INSTALL_SRC/$appName/
        tar zcf mysql-$appVer.tar.gz mysql-$appVer && md5sum mysql-$appVer.tar.gz > mysql-$appVer.tar.gz.md5 
    fi    
fi


if [ -d "$imagesDir/mysql" ] ; then
    cd $imagesDir/mysql
    sed -i -e "s|FROM .*|FROM centos|" Dockerfile
    mysqlVer=`curl http://releases.galeracluster.com/mysql-wsrep-5.6/centos/7/x86_64/ 2>/dev/null|grep mysql-wsrep-server|sed -e "s|.*mysql|mysql|" -e "s|.rpm.*||" -e "s|mysql-wsrep-server-5.6-||" -e "s|-.*||"`
    mysqlVer=${mysqlVer:=5.6.42}
    docker build -t mysql:$mysqlVer .  
    # update pkg
    if [ -d "$INSTALL_SRC/mysql/" ] ; then
        cd $INSTALL_SRC/mysql/
        pkgDir=mysql-$mysqlVer
        if [ ! -e "$pkgDir" ] ; then
            mysqlFile=`ls |grep mysql-|sort -V |tail -n 1`
            if [ "$mysqlFile" != "${mysqlFile//.tar.gz/}" ] ; then
                tar xf $mysqlFile
            fi 
            mysqlFile="${mysqlFile//.tar.gz/}"
            scp -rp $mysqlFile $pkgDir
        fi 
        cd $pkgDir
        ls mysql-5.6.*.tar* 2>/dev/null |xargs rm -rf 2>/dev/null
        docker save -o mysql-$mysqlVer.tar mysql:$mysqlVer
        gzip mysql-$mysqlVer.tar
        cd $INSTALL_SRC/mysql/
        tar zcf mysql-$mysqlVer.tar.gz mysql-$mysqlVer && md5sum mysql-$mysqlVer.tar.gz > mysql-$mysqlVer.tar.gz.md5 
       
    fi 
fi

jdkImg=`docker images |grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'|grep "centos-jdk:1"|sort -V |tail -n 1`
openJdkImg=`docker images |grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'|grep "centos-openjdk:1"|sort -V |tail -n 1`

cd $imagesDir
imagesDirs=" mysql centos-jdk centos-jdk-tomcat centos-openjdk centos-openjdk-tomcat centos-ssh centos-tools centos-ssh-tools haproxy "
allImaDirs=`ls -l |grep ^d|awk '{print $NF}' `
for dir in $allImaDirs ; do
    cd $imagesDir/$dir
    if [ ! -f "Dockerfile" ] ; then
        continue
    fi 
    if [ "$imagesDirs" != "${imagesDirs// $dir /}" ] ; then
        continue
    fi 
    fromImages=`cat Dockerfile|grep ^FROM `  
    if [ "$fromImages" != "${fromImages//-jdk:/}" ] ; then
        sed -i -e "s|FROM .*|FROM $jdkImg|" Dockerfile
    elif [ "$fromImages" != "${fromImages//-openjdk:/}" ] ; then
        sed -i -e "s|FROM .*|FROM $openJdkImg|" Dockerfile
    fi 
    docker build -t $dir .  
done
cd $imagesDir

allImg=`docker images |grep -v IMAGE|awk '{printf("%s:%s\n",$1,$2)}'`
for img in $allImg ; do
    for HOST in $CLUSTER_HOST_LIST ; do
        if [ "$HOST" = "$HOSTNAME" ] ; then
            continue
        fi 
        docker save $img | ssh $HOST docker load 
    done
done

exit $?
