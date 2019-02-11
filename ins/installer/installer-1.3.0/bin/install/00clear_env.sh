resKey=" XDG_SESSION_ID HOSTNAME TERM SHELL HISTSIZE SSH_CLIENT SSH_TTY USER MAIL PATH PWD HISTCONTROL SHLVL HOME LOGNAME SSH_CONNECTION XDG_RUNTIME_DIR  "
ENV_KEYS=`/bin/env|/bin/awk -F= '{print $1}'`
for ENVK in $ENV_KEYS ; do
    if [ "${resKey// $ENVK }" = "$resKey" ] ; then
        unset $ENVK
    fi
done
export PATH=.:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:/sbin
