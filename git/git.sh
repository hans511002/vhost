#!/usr/bin/env bash
#
 
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. $bin/env.sh $@

auto_git $gitUserName  $gitPassword  "git pull -v --progress \"origin\""
res=$?
if [[ $res -ne 1 ]] ; then 
   exit $res
fi
echo "get from git done"

echo "commit ..."
git commit -m "update by $guName " -a
echo "push to git"
auto_git $gitUserName  $gitPassword  "git push --all "
res=$?
if [[ $res -ne 1 ]] ; then 
   exit $res
fi
cd ..
rm -rf  $updateAppName

echo "update to git done" 
