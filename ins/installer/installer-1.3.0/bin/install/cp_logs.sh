#!/usr/bin/env bash
# 

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

if [ $# -lt 2 ] ; then 
  echo "usetag:clean_logs.sh appName lastDays FileExtension"
  exit 1
fi

echo "$bin/funs.sh"
. $bin/funs.sh

DEST_DIR="/sharedfs/applogs"

appName=$1
LASTDAYS=$2
FILETYPE=$3
if [ "`checkApp $appName`" != "true" ] ; then
    echo "$appName not installed"
    exit 1
fi
if [ "$LASTDAYS" -gt "10" ] ; then
    echo "LASTDAYS is large"
    exit 1
fi
if [ "$FILETYPE" != "" ] ; then
    if [ "${FILETYPE:0:1}" = "*" ] ; then
        FILETYPE=${FILETYPE:1}
    fi
    if [ "${FILETYPE:0:1}" = "." ] ; then
        FILETYPE=${FILETYPE:1}
    fi
    if [ "${FILETYPE:0:1}" = "*" ] ; then
        FILETYPE=${FILETYPE:1}
    fi
fi

LOGSDIR="$LOGS_BASE/$appName"
if [ ! -d "$LOGSDIR" ] ; then
    exit 1
fi
TODAY=` date +%Y%m%d`
APP_HOST_LIST="`getAppHosts $appName`"
delDay=`get_before_dates $TODAY $LASTDAYS`
DEST_DIR="$DEST_DIR/$appName/`hostname`"

echo "`date` beging to del logs file ..............."
echo "LOGSDIR=$LOGSDIR LASTDAYS=$LASTDAYS $delDay to $TODAY $LASTDAYS APP_HOST_LIST=$APP_HOST_LIST"
echo "DEST_DIR=$DEST_DIR"
dirLevel=0

mkdir -p $DEST_DIR


scanSubDirFile(){
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
        echo "scan log in dir `pwd`"
        for subDir in $thisDir/* ;  do
             # echo "goin $subDir"
             if [ -d $subDir ] ; then
                echo "scan $subDir"
                scanSubDirFile  "$subDir" 
             else
                fileDay=`ls --full-time $subDir | cut -d" " -f6-7 | cut -c1,2,3,4,6,7,9,10`
               # echo "fileDay=$fileDay  "
                if [ "$fileDay" = "" ] ; then
                    continue
                fi
                if [ "$fileDay" -gt "$delDay" ] ; then
                    if [ "$FILETYPE" != "" ] ; then
                        echo "$subDir"|grep -E "$FILETYPE$" 2>/dev/null
                        if [ "$?" != "0" ] ; then
                            continue
                        fi
                    fi
                    #echo "fileDay=$fileDay  "
                   # echo "thisDir=$thisDir LOGSDIR=$LOGSDIR subDir=$subDir"
                    destFile="$DEST_DIR/${subDir//${LOGSDIR//\//\\/}/}"
                   # echo "destFile=$destFile"
                    ddir=`dirname $destFile`
                    if [ ! -d "$ddir" ] ; then
                        echo "mkdir -p $ddir"
                        mkdir -p $ddir
                    fi
                    echo "scp -rp $subDir $destFile"
                    scp -rp $subDir $destFile 
                fi
            fi
        done
        cd ..
        ((dirLevel--))
    fi
}
scanSubDirFile $LOGSDIR
echo "`date` end to del logs file ..............."
