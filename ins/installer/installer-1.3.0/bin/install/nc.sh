#!/usr/bin/env bash
#
if [ $# -lt 2 ]; then
  echo "eage:nc.sh <host> <port>"
fi
HOST=$1
PORT=$2
Connecttimeout=$3
Connecttimeout=${Connecttimeout:=1}
idletimeout=$4
idletimeout=${idletimeout:=1}

nc -C -i 1 -w 1 $HOST $PORT <<EOF





EOF


