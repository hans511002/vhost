#!/usr/bin/env bash
#
 

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

if [ $# -lt 1 ] ; then 
    echo "usetag:addFile"
    exit 1
fi 

. $bin/env.sh $@

guName=${gitUserName} 

echo "add $@"
git add $@
echo "commit ..."
git commit -m "update $updateAppName-$updateAppVer image by $guName " -a
echo "push to git"
auto_git $gitUserName  $gitPassword  "git push --all "
res=$?
if [[ $res -ne 0 ]] ; then 
   exit $res
fi
cd ..
rm -rf  $updateAppName

echo "update $updateAppName to git done"




