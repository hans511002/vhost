#!/usr/bin/env bash
#
 

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. $bin/env.sh $@



if ! [ -d $gitHome -a  -d "$gitHome/.git" ]  ; then
    auto_git $gitUserName  $gitPassword  "git clone --progress  $gitBase $gitHome"
    res=$?
    if [[ $res -ne 0 ]] ; then 
       exit $res
    fi
fi
cd $gitHome

auto_git $gitUserName  $gitPassword  "git pull -v --progress \"origin\""
res=$?
echo "===========$res=="
if [[ $res -ne 1 ]] ; then 
   exit $res
fi
echo "get HiveInstaller from git done"

