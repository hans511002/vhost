#!/usr/bin/env bash
#
# Run a shell command on all master hosts.
#
# Environment Variables
#
#   INSTALLER_MASTERS File naming remote hosts.
#     Default is ${HBASE_CONF_DIR}/masters
#   INSTALLER_CONF_DIR  Alternate INSTALLER conf dir. Default is ${INSTALLER_HOME}/conf.
#   INSTALLER_SLAVE_SLEEP Seconds to sleep between spawning remote commands.
#   INSTALLER_SSH_OPTS Options passed to ssh when running remote commands.
#

usage="Usage: $0 [--config <installer-confdir>] command..."

# if no args specified, show usage
if [ $# -le 0 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin"/installer-config.sh

# If the master backup file is specified in the command line,
# then it takes precedence over the definition in
# kafka-env.sh. Save it here.
HOSTLIST=$INSTALLER_MASTERS

if [ "$HOSTLIST" = "" ]; then
  if [ "$INSTALLER_MASTERS" = "" ]; then
    export HOSTLIST="${INSTALLER_CONF_DIR}/servers"
  else
    export HOSTLIST="${INSTALLER_MASTERS}"
  fi
fi

args=${@// /\\ }
args=${args/master-backup/master}

if [ -f $HOSTLIST ]; then
  for emaster in `cat "$HOSTLIST"`; do
   ssh $INSTALLER_SSH_OPTS $emaster $"$args  " 2>&1 | sed "s/^/$emaster: /" &
   if [ "$INSTALLER_SLAVE_SLEEP" != "" ]; then
     sleep $INSTALLER_SLAVE_SLEEP
   fi
  done
fi

wait
