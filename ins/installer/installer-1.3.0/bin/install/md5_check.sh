#! /bin/bash

local_sh_dir=`dirname "${BASH_SOURCE-$0}"`
local_sh_dir=`cd $local_sh_dir;pwd`
cd ${local_sh_dir}

if [ $# -lt 1 ] ; then
   echo "usetag:md5_check.sh path"
   exit 1
fi

RDIR=$1

cd $RDIR
appDirs=`ls -l|grep -E "^d"|awk '{print $NF}'`

######################################
for md5 in `ls *.md5 2>/dev/null` ; do
   echo "md5 check $RDIR/$md5 begin....`cat $md5`"
   md5sum -c  $md5 2>&1
	if [ "$?" != "0" ] ; then
	   echo "文件校验失败: $md5"
	   exit 1
	fi
done

for app in $appDirs ; do
    echo "check md5 in $app"
    cd $app
    for md5 in `ls *.md5 2>/dev/null` ; do
		  echo "md5 check $RDIR/$app/$md5 begin....`cat $md5`"
		   md5sum -c  $md5 2>&1
			if [ "$?" != "0" ] ; then
			   echo "文件校验失败: $md5"
			   exit 1
			fi
		done
		cd ..
done
