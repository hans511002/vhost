#!/usr/bin/env bash
#
 

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`

GIT=`which git`

if [ "$GIT" = "" ] ; then
   yum install -y git
fi

EXPECT=`which expect`
if [ "$EXPECT" = "" ] ; then
   yum install -y expect
fi


DOCKER=`which docker 2>/dev/null`
if [ "$DOCKER" = "" ] ; then
#   yum install -y docker
#   service docker stop
   mkdir -p /app/data/docker
#   nohup  /usr/bin/docker daemon -H unix:///var/run/docker.sock > /dev/null 2>&1 &
fi

gitHome=`cd "$bin/../">/dev/null; pwd`
gitBase="https://github.com/hans511002/vhost"

if [  -f $bin/.gitconf ] ; then
. $bin/.gitconf
else
    if [ $# -lt 2 ] ; then 
        echo "usetag: gitUserName gitPassword"
        exit 1
    fi 
    export gitUserName=$1
    export gitPassword=$2
    shift
    shift
    
    echo "
    export gitUserName=$gitUserName
    export gitPassword=$gitPassword

    ">$bin/.gitconf
fi
guName=${gitUserName} 
git config --global user.email "$guName@sohu.com"
git config --global user.name "$guName"


auto_git () {
    expect -c "set timeout -1;
                spawn ${@:3};
                expect {
                    *Username* {send --  $1\r;
                                 expect {
                                     *Password* {send -- $2\r;
                                        expect {
                                            *fatal:* {exit 2;}
                                            eof
                                         }
                                      }
                                    *fatal:* {exit 2;}
                                    eof
                                 }
                    }
                    
                    eof {exit 1;}
                }
                "
    return $?
}
