#!/usr/bin/env bash
. /etc/bashrc
SUDO=""
if [ "$USER" != "root" ] ; then
SUDO="sudo"
fi
$SUDO service deploy stop
