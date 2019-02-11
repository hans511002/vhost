#! /usr/bin/env bash
#
if [ $# -lt 1 ] ; then
	echo APP_HOME
	exit 1
fi

APP_HOME=$1 

env 
 

${APP_HOME}/bin/zkServer.sh start 
 
 
