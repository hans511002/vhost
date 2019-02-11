#!/bin/bash

if [ $# -lt 1 ]
then
    echo "usetage: cmd.sh cmd"
    exit
fi


auto_smart_ssh () {
    expect -c "set timeout -1;
                spawn ssh -o StrictHostKeyChecking=no $2 ${@:3};
                expect {
                    *assword:* {send -- $1\r;
                                 expect {
                                    *denied* {exit 2;}
                                    eof
                                 }
                    }
                    eof    
                };
     catch wait result; exit [lindex \$result 3]
                "
    return $?
}


for HOST in ${CLUSTER_OTHER_HOST_LIST} ;do
    echo " $HOST  $@"
    PARAMS="$@"
auto_smart_ssh hdp $HOST "$PARAMS"
#ssh $HOST  $@ 2>&1 | sed "s/^//" &
#     sleep 0.1
done
