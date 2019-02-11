#!/usr/bin/env bash
# 
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd $bin;pwd`
istop=$1

dirName=`dirname "${bin}"`
cd $dirName

echo "`date "+%Y-%m-%d %H:%M"`" >$bin/bin/install/version

dName=${bin//$dirName/}
dName=${dName//\//}
echo "destName=$dName"
jdkFile=`ls $dName/bin/jdk/linux/jdk* |sort -V | tail -n 1 |sed -e "s|.*/||"`                                            
jdkDir=`echo $jdkFile |sed -e "s|\.tar\.gz||"`

if [ "$istop" != "" ] ; then
    echo "tar zcf $bin/app_src/installer/$dName.tar.gz  $dName  --exclude=app_src  --exclude=log --exclude=tmp  --exclude=$dName/bin/jdk/linux/$jdkDir --exclude=$dName/bin/jdk/win"
    tar zcf $bin/app_src/installer/$dName.tar.gz  $dName  --exclude=app_src  --exclude=log --exclude=tmp  --exclude=$dName/bin/jdk/linux/$jdkDir  --exclude=$dName/bin/jdk/win
    md5sum $bin/app_src/installer/$dName.tar.gz > $bin/app_src/installer/$dName.tar.gz.md5
    sed -i -e "s|$bin/app_src/installer/||" $bin/app_src/installer/$dName.tar.gz.md5
else
    
    echo "tar zcf $dirName/$dName.tar.gz  $dName  --exclude=app_src  --exclude=log --exclude=tmp  --exclude=$dName/bin/jdk/linux/$jdkDir  --exclude=$dName/bin/jdk/win"
    tar zcf $dirName/$dName.tar.gz  $dName  --exclude=app_src  --exclude=log --exclude=tmp  --exclude=$dName/bin/jdk/linux/$jdkDir  --exclude=$dName/bin/jdk/win
    md5sum $dirName/$dName.tar.gz > $dirName/$dName.tar.gz.md5
    sed -i -e "s|$dirName/||" $dirName/$dName.tar.gz.md5
fi

if [ -f "$bin/../../../git/git.sh" ] ; then 
$bin/../../../git/git.sh
fi

