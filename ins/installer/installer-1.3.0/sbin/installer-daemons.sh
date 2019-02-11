#!/usr/bin/env bash
#
#
# Run a installer command on all master hosts.
# Modelled after $INSTALLER_HOME/bin/installer-daemons.sh

usage="Usage: installer-daemons.sh [--config <installer-confdir>] \
 [--hosts serversfile] [start|stop] command args..."

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. $bin/installer-config.sh

remote_cmd="cd ${INSTALLER_HOME}; $bin/installer-daemon.sh --config ${INSTALLER_CONF_DIR} $@"
args="--hosts ${INSTALLER_MASTERS} --config ${INSTALLER_CONF_DIR} $remote_cmd"

command=$2
case $command in
  (master|server)
    exec "$bin/servers.sh" $args
    ;;
  (*)
   # exec "$bin/servers.sh" $args
    ;;
esac

