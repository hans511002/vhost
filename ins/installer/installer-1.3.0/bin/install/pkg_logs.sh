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
    echo "LASTDAYS $LASTDAYS is must small than 10 days"
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

TODAY=` date +%Y%m%d`
APP_HOST_LIST="`getAppHosts $appName`"
delDay=`get_before_dates $TODAY $LASTDAYS`
echo "`date` beging to del logs file ..............."
echo "LOGSDIR=$LOGSDIR LASTDAYS=$LASTDAYS  $TODAY $LASTDAYS APP_HOST_LIST=$APP_HOST_LIST"
echo "delDay=$delDay"
dirLevel=0

for HOST in ${APP_HOST_LIST//,/ } ; do
    echo "ssh $HOST $bin/cp_logs.sh \"$appName\" \"$LASTDAYS\" \"$FILETYPE\""
    ssh $HOST $bin/cp_logs.sh "$appName" "$LASTDAYS" "$FILETYPE"
done
echo "cd $DEST_DIR"
cd $DEST_DIR

if [ "`du -shm $appName |awk '{print $1}'`" = "0" ] ; then
    echo "log is null "
    exit 0
fi

echo "tar zcf $appName.tar.gz $appName && rm -rf $appName"
tar zcf $appName.tar.gz $appName && rm -rf $appName
echo "ls -l $DEST_DIR"
ls -l $DEST_DIR
echo "the $appName log file:$DEST_DIR/$appName.tar.gz"
exit 0
