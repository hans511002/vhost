#!/usr/bin/env bash
#

# Modelled after $INSTALLER_HOME/sbin/start-installer.sh.

# Start hadoop hbase daemons.
# Run this on master node.

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

$bin/installer master start
