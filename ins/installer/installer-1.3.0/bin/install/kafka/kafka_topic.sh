#! /bin/bash
. /etc/bashrc
bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin">/dev/null; pwd`
cd $bin

if [ "$#" -lt "1" ] ; then
    echo "usetag:[create|delete|ls] topicname "
    exit 1
fi
topMod=$1

if [ "$topMod" != "create" -a "$topMod" != "delete"  -a "$topMod" != "ls" ] ; then
    echo "only support create or delete mothed "
    exit 1
fi
if [ "$#" -lt "2" -a "$topMod" != "ls"  ] ; then
    echo "usetag:[create|delete] topicname "
    exit 1
fi

topics=$2
if [ "$topics" = "" ] ; then
    topics="ls"
fi

kafkaHosts=(${kafka_hosts//,/ })
COUNT=${#kafkaHosts[@]}

for topic in ${topics//,/ } ; do
    echo "$topMod $topic"
    for HOST in ${kafka_hosts//,/ } ; do
        runned=`ssh $HOST docker ps |grep kafka-$HOST | wc -l `
        if [ "$runned" != "1" ] ; then
            continue
        fi
        if [ "$topMod" = "create" ] ; then
            echo "create kafka topic $topic: ssh $runHost docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL "
            outFile=`ssh $HOST docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --create --topic $topic --replication-factor $COUNT --partitions 1 --zookeeper $ZOOKEEPER_URL 2>&1 `
            res=$?
            echo "$outFile"
            if [ "${outFile//already exists/}" = "$outFile" ] ; then
                if [ "$res" != "0" ] ; then
                    continue
                fi
            fi
        elif [ "$topMod" = "delete" ] ; then
            echo "delete kafka topic $topic: ssh $runHost docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --delete --topic $topic --zookeeper $ZOOKEEPER_URL "
            outFile=`ssh $HOST docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --delete --topic $topic --zookeeper $ZOOKEEPER_URL`
            res=$?
            echo "$outFile"
            if [ "${outFile//does not exist on ZK/}" = "$outFile" ] ; then
                if [ "$res" != "0" ] ; then
                    continue
                fi
            fi
        elif [ "$topMod" = "ls" ] ; then
            echo "ssh $HOST docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --list --zookeeper $ZOOKEEPER_URL"
            ssh $HOST docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --list --zookeeper $ZOOKEEPER_URL
            exit $?
        fi
        break
    done
done


if [ "$res" = "0" ] ; then
    echo "kafka topic list:"
    ssh $HOST docker exec -i kafka-$HOST  /kafka/bin/kafka-topics.sh --list --zookeeper $ZOOKEEPER_URL
fi

if [ "$res" = "0" ] ; then
    echo "$topMod $topic success"
else
    echo "$topMod $topic failed"
    exit 1
fi


