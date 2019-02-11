#!/usr/bin/env bash
# 

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

if [ $# -lt 2 ] ; then 
  echo "usetag:clean_logs.sh logsDir lastDays"
  exit 1
fi

echo "$bin/funs.sh"
. $bin/funs.sh

LOGSDIR=$1
LASTDAYS=$2

TODAY=` date +%Y%m%d`

delDay=`get_before_dates $TODAY $LASTDAYS`
echo "`date` beging to del logs file ..............."
echo "LOGSDIR=$LOGSDIR LASTDAYS=$LASTDAYS  $TODAY $LASTDAYS"
echo "delDay=$delDay"
dirLevel=0

delSubDirFile(){
    thisDir=$1
    if [ "$thisDir" = "" ] ; then
        return
    fi
    echo "thisDir=$thisDir"
    if [ "`ls $thisDir/ 2>/dev/null`" = "" ] ; then
        return
    fi
    if [ -d "$thisDir" ] ; then
        ((dirLevel++))
        cd $thisDir
        echo "del log in dir `pwd`"
        for subDir in $thisDir/* ;  do
             # echo "goin $subDir"
             if [ -d $subDir ] ; then
                echo "scan $subDir"
                delSubDirFile  "$subDir"
                if [ "$dirLevel" -gt "3" ] ; then
                    subFiles=`ls $subDir`
                    if [ "$subFiles" = "" ] ; then
                        fileDay=`ls --full-time $thisDir |grep -E "subDir$" | grep -E "redis$"|awk '{print $6}'|sed -e "s|-||g"`
                        if [ "$fileDay" = "" ] ; then
                            continue
                        fi
                        if [ "$fileDay" -lt "$delDay" ] ; then
                            echo "rm -rf $subDir"
                            rm -rf $subDir
                        fi
                    fi
                fi
             else
                fileDay=`ls --full-time $subDir | cut -d" " -f6-7 | cut -c1,2,3,4,6,7,9,10`
                # echo "fileDay=$fileDay  "
                if [ "$fileDay" = "" ] ; then
                    continue
                fi
                if [ "$fileDay" -lt "$delDay" ] ; then
                    echo "rm -rf $subDir"
                    rm -rf $subDir
                else
                    if [ `du -shm $subDir | awk '{print $1}'` -gt '512' ] ; then
                        tail -n 5000 $subDir >  $subDir.bak
                        cat $subDir.bak > $subDir
                        rm -rf $subDir.bak
                    fi
                fi
            fi
        done
        cd ..
        ((dirLevel--))
    elif [ `du -shm $thisDir | awk '{print $1}'` -gt '512' ] ; then
        echo "truncate log file: $thisDir"
        tail -n 5000 $thisDir >  $thisDir.bak
        cat $thisDir.bak > $thisDir
        rm -rf $thisDir.bak
    fi
}
delSubDirFile $LOGSDIR
echo "`date` end to del logs file ..............."
