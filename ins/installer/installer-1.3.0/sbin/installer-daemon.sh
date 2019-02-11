#!/usr/bin/env bash

# Runs a installer command as a daemon.
#
# Environment Variables
#
#   INSTALLER_CONF_DIR   Alternate installer conf dir. Default is ${INSTALLER_HOME}/conf.
#   INSTALLER_LOG_DIR    Where log files are stored.  PWD by default.
#   INSTALLER_PID_DIR    The pid files are stored. /tmp by default.
#   INSTALLER_IDENT_STRING   A string representing this instance of hadoop. $USER by default
#   INSTALLER_NICENESS The scheduling priority for daemons. Defaults to 0.
#   INSTALLER_STOP_TIMEOUT  Time, in seconds, after which we kill -9 the server if it has not stopped.
#                        Default 1200 seconds.
#
# Modelled after $HADOOP_HOME/sbin/installer-daemon.sh

usage="Usage: installer-daemon.sh [--config <conf-dir>]\
 (start|stop|restart|autorestart) <installer-command> \
 <args...>"

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin"/installer-config.sh
. "$bin"/installer-common.sh

# get arguments
startStop=$1
shift

command=$1
shift

installer_rotate_log ()
{
    log=$1;
    num=5;
    if [ -n "$2" ]; then
    num=$2
    fi
    if [ -f "$log" ]; then # rotate logs
    while [ $num -gt 1 ]; do
        prev=`expr $num - 1`
        [ -f "$log.$prev" ] && mv -f "$log.$prev" "$log.$num"
        num=$prev
    done
    mv -f "$log" "$log.$num";
    fi
}

cleanZNode() {
  
        $bin/installer clean --cleanZk  > /dev/null 2>&1
    
}

check_before_start(){
    #ckeck if the process is not running
    mkdir -p "$INSTALLER_PID_DIR"
    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $command running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi
}

wait_until_done ()
{
    p=$1
    cnt=${INSTALLER_SLAVE_TIMEOUT:-300}
    origcnt=$cnt
    while kill -0 $p > /dev/null 2>&1; do
      if [ $cnt -gt 1 ]; then
        cnt=`expr $cnt - 1`
        sleep 1
      else
        echo "Process did not complete after $origcnt seconds, killing."
        kill -9 $p
        exit 1
      fi
    done
    return 0
}

# get log directory
if [ "$INSTALLER_LOG_DIR" = "" ]; then
  export INSTALLER_LOG_DIR="$INSTALLER_HOME/logs"
fi
mkdir -p "$INSTALLER_LOG_DIR"

if [ "$INSTALLER_PID_DIR" = "" ]; then
  INSTALLER_PID_DIR=$INSTALLER_LOG_DIR
fi

if [ "$INSTALLER_IDENT_STRING" = "" ]; then
  export INSTALLER_IDENT_STRING="$USER"
fi

# Some variables
# Work out java location so can print version into log.
if [ "$JAVA_HOME" != "" ]; then
  #echo "run java in $JAVA_HOME"
  JAVA_HOME=$JAVA_HOME
fi
if [ "$JAVA_HOME" = "" ]; then
  echo "Error: JAVA_HOME is not set."
  exit 1
fi

JAVA=$JAVA_HOME/bin/java
export INSTALLER_LOG_PREFIX=installer-$INSTALLER_IDENT_STRING-$command-$HOSTNAME
export INSTALLER_LOGFILE=$INSTALLER_LOG_PREFIX.log
export INSTALLER_ROOT_LOGGER=${INSTALLER_ROOT_LOGGER:-"INFO,RFA"}
export INSTALLER_SECURITY_LOGGER=${INSTALLER_SECURITY_LOGGER:-"INFO,RFAS"}
logout=$INSTALLER_LOG_DIR/$INSTALLER_LOG_PREFIX.out
loggc=$INSTALLER_LOG_DIR/$INSTALLER_LOG_PREFIX.gc
loglog="${INSTALLER_LOG_DIR}/${INSTALLER_LOGFILE}"
pid=$INSTALLER_PID_DIR/installer-$INSTALLER_IDENT_STRING-$command.pid
 export INSTALLER_START_FILE=$INSTALLER_PID_DIR/installer-$INSTALLER_IDENT_STRING-$command.autorestart

if [ -n "$SERVER_GC_OPTS" ]; then
  export SERVER_GC_OPTS=${SERVER_GC_OPTS/"-Xloggc:<FILE-PATH>"/"-Xloggc:${loggc}"}
fi

# Set default scheduling priority
if [ "$INSTALLER_NICENESS" = "" ]; then
    export INSTALLER_NICENESS=0
fi

thiscmd=$0
args=$@

case $startStop in

(start)
    check_before_start
    installer_rotate_log $logout
    installer_rotate_log $loggc
    echo starting $command, logging to $logout
    nohup $thiscmd --config "${INSTALLER_CONF_DIR}" internal_start $command $args < /dev/null > ${logout} 2>&1  &
    sleep 1; head "${logout}"
  ;;

(internal_start)
    # Add to the command log file vital stats on our environment.
    echo "`date` Starting $command on `hostname`" >> $loglog
    echo "`ulimit -a`" >> $loglog 2>&1
    nice -n $INSTALLER_NICENESS "$INSTALLER_HOME"/sbin/installer \
        --config "${INSTALLER_CONF_DIR}" \
        $command "$@" start >> "$logout" 2>&1 &
    echo $! > $pid
    wait
	echo `ps ax | grep -i 'installer' | grep java | grep -v grep | awk '{print $1}' ` > $pid
  ;;
 
(stop)
    rm -f "$INSTALLER_START_FILE"
    if [ -f $pid ]; then
      pidToKill=`cat $pid`
      # kill -0 == see if the PID exists
      if kill -0 $pidToKill > /dev/null 2>&1; then
        echo -n stopping $command
        echo "`date` Terminating $command" >> $loglog
        kill -2 $pidToKill > /dev/null 2>&1
        "$INSTALLER_HOME"/sbin/installer master stop
        rm -rf $pid
      else
        retval=$?
        echo no $command to stop because kill -0 of pid $pidToKill failed with status $retval
      fi
    else
      echo no $command to stop because no pid file $pid
    fi
  ;;

(restart)
    # stop the command
    $thiscmd --config "${INSTALLER_CONF_DIR}" stop $command $args &
    wait_until_done $!
    # wait a user-specified sleep period
    sp=${INSTALLER_RESTART_SLEEP:-3}
    if [ $sp -gt 0 ]; then
      sleep $sp
    fi
    # start the command
    $thiscmd --config "${INSTALLER_CONF_DIR}" start $command $args &
    wait_until_done $!
  ;;

(*)
  echo $usage
  exit 1
  ;;
esac
