#!/usr/bin/env bash
#

# Modelled after $INSTALLER_HOME/sbin/start-installer.sh.

# Start hadoop hbase daemons.
# Run this on master node.
usage="Usage: start-installer.sh"

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

. "$bin"/installer-config.sh

# start INSTALLER daemons
errCode=$?
if [ $errCode -ne 0 ]
then
  exit $errCode
fi


if [ "$1" = "autorestart" ]
then
  commandToRun="autorestart"
else
  commandToRun="start"
fi

"$bin"/installer-daemons.sh --config "${INSTALLER_CONF_DIR}" --hosts "${INSTALLER_MASTERS}" $commandToRun master

