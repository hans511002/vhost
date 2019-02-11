#!/usr/bin/env bash
#
# Modelled after $INSTALLER_HOME/sbin/stop-installer.sh.

# Stop storm installer daemons.  Run this on master node.

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin"/installer-config.sh
. "$bin"/installer-common.sh

# variables needed for stop command
if [ "$INSTALLER_LOG_DIR" = "" ]; then
  export INSTALLER_LOG_DIR="$INSTALLER_HOME/logs"
fi
mkdir -p "$INSTALLER_LOG_DIR"

if [ "$INSTALLER_IDENT_STRING" = "" ]; then
  export INSTALLER_IDENT_STRING="$USER"
fi

export INSTALLER_LOG_PREFIX=installer-$INSTALLER_IDENT_STRING-master-$HOSTNAME
export INSTALLER_LOGFILE=$INSTALLER_LOG_PREFIX.log
logout=$INSTALLER_LOG_DIR/$INSTALLER_LOG_PREFIX.out
loglog="${INSTALLER_LOG_DIR}/${INSTALLER_LOGFILE}"
pid=${INSTALLER_PID_DIR:-/tmp}/installer-$INSTALLER_IDENT_STRING-master.pid

echo -n "stopping INSTALLER   "  
 
"$bin"/installer-daemons.sh --config "${INSTALLER_CONF_DIR}" --hosts "${INSTALLER_MASTERS}" stop master

 
