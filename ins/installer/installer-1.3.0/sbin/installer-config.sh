#!/usr/bin/env bash
# Modelled after $INSTALLER_HOME/sbin/installer-env.sh.

# resolve links - "${BASH_SOURCE-$0}" may be a softlink

this="${BASH_SOURCE-$0}"
while [ -h "$this" ]; do
  ls=`ls -ld "$this"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '.*/.*' > /dev/null; then
    this="$link"
  else
    this=`dirname "$this"`/"$link"
  fi
done


# convert relative path to absolute path
bin=`dirname "$this"`
script=`basename "$this"`
bin=`cd "$bin">/dev/null; pwd`
this="$bin/$script"


# the root of the installer installation
export INSTALLER_HOME=`cd "$bin/../"; pwd`

#check to see if the conf dir or installer home are given as an optional arguments
while [ $# -gt 1 ]
do
  if [ "--config" = "$1" ]
  then
    shift
    confdir=$1
    shift
    INSTALLER_CONF_DIR=$confdir
  elif [ "--hosts" = "$1" ]
  then
    shift
    hosts=$1
    shift
    INSTALLER_MASTERS=$hosts
  else
    # Presume we are at end of options and break
    break
  fi
done

# Allow alternate installer conf dir location.
INSTALLER_CONF_DIR="${INSTALLER_CONF_DIR:-$INSTALLER_HOME/conf}"
# List of installer   masters.
INSTALLER_MASTERS="${INSTALLER_MASTERS:-$INSTALLER_CONF_DIR/servers}"


if [ -z "$INSTALLER_ENV_INIT" ] && [ -f "${INSTALLER_CONF_DIR}/installer-env.sh" ]; then
  . "${INSTALLER_CONF_DIR}/installer-env.sh"
  export INSTALLER_ENV_INIT="true"
fi

if [ -z "$INSTALLER_ENV_INIT" ] && [ -f "${bin}/installer-env.sh" ]; then
  . "${bin}/installer-env.sh"
  export INSTALLER_ENV_INIT="true"
fi
if [ -z "$JAVA_HOME" -o ! -d "$JAVA_HOME" ]; then
  for candidate in \
    $INSTALLER_HOME/bin/jdk/linux/jdk1.7* \
    $INSTALLER_HOME/bin/jdk/linux/jdk1.8* ; do
    if [ -e $candidate/bin/java ]; then
      export JAVA_HOME=$candidate
      break
    fi
   done
fi
if [ -z "$JAVA_HOME" -o ! -d "$JAVA_HOME" ] ; then
    jdkFiles=`ls $INSTALLER_HOME/bin/jdk/linux/ | tail -n 1`
    cd $INSTALLER_HOME/bin/jdk/linux;
    tar xf $jdkFiles
fi

if [ -z "$JAVA_HOME" -o ! -d "$JAVA_HOME" ]; then
  for candidate in \
    $INSTALLER_HOME/bin/jdk/linux/jdk1* \
    /usr/lib/jvm/java-6-sun \
    /usr/lib/jvm/java-1.6.0-sun-1.6.0.*/jre \
    /usr/lib/jvm/java-1.6.0-sun-1.6.0.* \
    /usr/lib/j2sdk1.6-sun \
    /usr/java/jdk1.6* \
    /usr/java/jre1.6* \
    /usr/java/jdk1.7* \
    /usr/java/jre1.7* \
    /usr/java/jdk1.8* \
    /usr/java/jre1.8* \
    /Library/Java/Home ; do
    if [ -e $candidate/bin/java ]; then
      export JAVA_HOME=$candidate
      break
    fi
  done
  # if we didn't set it
  if [ -z "$JAVA_HOME" -o ! -d "$JAVA_HOME" ]; then
    cat 1>&2 <<EOF
+======================================================================+
|      Error: JAVA_HOME is not set and Java could not be found         |
+----------------------------------------------------------------------+
| Please download the latest Sun JDK from the Sun Java web site        |
|       > http://java.sun.com/javase/downloads/ <                      |
|                                                                      |
| installer requires Java 1.7 or later.                                    |
| NOTE: This script will find Sun Java whether you install using the   |
|       binary or the RPM based installer.                             |
+======================================================================+
EOF
    exit 1
  fi
fi
